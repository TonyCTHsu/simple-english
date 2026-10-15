/**
 * se_lint - lint Markdown prose and code comments with simple_english.
 *
 * Three layers. The se_lint tool lints on demand. Enforcement runs the
 * same lint after every edit or write and appends the findings to the
 * tool result, so the agent sees them in the turn that made them. It
 * never blocks the edit. The /se command gates both layers per session:
 * off hides the tool from the model and skips enforcement. The contract
 * mirrors the claude-code hook in integrations/claude-code/hooks/lint.sh:
 * a clean file stays silent, a failed lint says so instead of reading as
 * clean, and a missing binary names the install step.
 */

import { execFile } from "node:child_process";
import { Type } from "typebox";
import type {
	AgentToolResult,
	ExtensionAPI,
	ExtensionContext,
	ToolResultEvent,
	ToolResultEventResult,
} from "@earendil-works/pi-coding-agent";

const OUTPUT_LIMIT = 4000;
// ponytail: 120s allows a cold daemon boot (LanguageTool + JVM). If that
// ever proves slow in practice, cut to 30s and pre-warm via `se serve`.
const TIMEOUT_MS = 120_000;

const STATE_ENTRY_TYPE = "se-lint-state";
const STATUS_KEY = "se";

interface SeResult {
	stdout: string;
	code: number;
}

interface SeDetails {
	path: string;
	exitCode: number;
	findings: number;
	full?: string;
}

type SeLintState = { enabled: boolean };

function seLint(path: string, signal?: AbortSignal): Promise<SeResult> {
	return new Promise((resolve, reject) => {
		execFile(
			"se",
			["lint", path],
			{ timeout: TIMEOUT_MS, maxBuffer: 1024 * 1024, signal },
			(error, stdout) => {
				if (error && typeof error.code !== "number") {
					reject(error);
					return;
				}
				resolve({ stdout, code: (error?.code as number | undefined) ?? 0 });
			},
		);
	});
}

// The feedback appended to an edit or write result. undefined means
// clean: nothing is appended, so a clean edit reads as a clean edit.
async function lintFeedback(path: string): Promise<string | undefined> {
	let result: SeResult;
	try {
		result = await seLint(path);
	} catch (err) {
		const e = err as NodeJS.ErrnoException;
		if (e.code === "ENOENT") {
			return "`se` is not installed, so the file was not linted. Install it first: `gem install simple_english`, then retry.";
		}
		return `se lint failed, so the file was not linted. Run \`se lint ${path}\` to see the error.`;
	}
	if (result.code >= 2) {
		return `se exited ${result.code} and the file was not linted. Run \`se lint ${path}\` to see the error.`;
	}
	const full = result.stdout.trim();
	if (result.code === 0 || !full) {
		return undefined;
	}
	const findings = full.split("\n").length;
	const text =
		full.length > OUTPUT_LIMIT
			? `${full.slice(0, OUTPUT_LIMIT)}\n... truncated (${full.length} chars, ${findings} findings). Full output: run \`se lint ${path}\` with bash.`
			: full;
	return `se found ${findings} lint finding(s) in ${path}. Fix them, then lint again:\n${text}`;
}

// The last state entry on the branch wins. Earlier toggles are history,
// not the current state.
function savedEnabled(ctx: ExtensionContext): boolean | undefined {
	let saved: boolean | undefined;
	for (const entry of ctx.sessionManager.getBranch()) {
		if (entry.type !== "custom" || entry.customType !== STATE_ENTRY_TYPE) {
			continue;
		}
		const data = entry.data as Partial<SeLintState> | undefined;
		if (typeof data?.enabled === "boolean") {
			saved = data.enabled;
		}
	}
	return saved;
}

export default function (pi: ExtensionAPI) {
	let enabled = true;

	const updateStatus = (ctx: ExtensionContext): void => {
		if (!enabled) {
			ctx.ui.setStatus(STATUS_KEY, undefined);
			return;
		}
		const dot = ctx.ui.theme.fg("success", "●");
		ctx.ui.setStatus(STATUS_KEY, `${dot} ${ctx.ui.theme.fg("accent", "simple-english")}`);
	};

	const registerLintTool = (exposure: "direct" | "hidden"): void => {
		pi.registerTool({
			name: "se_lint",
			label: "Lint prose",
			description:
				"Lint Markdown prose and code comments against plain-English rules (short sentences, active voice, no jargon, no filler). " +
				"Call this after writing or editing any documentation file (.md) or prose-heavy text to verify it reads clean. " +
				"Also call it on demand when asked to lint or simplify text. " +
				"Input: a file or directory path. Returns findings with line numbers and suggested rewrites, or 'clean' when nothing is flagged. " +
				"After fixing findings, re-run until it reports clean.",
			parameters: Type.Object({
				path: Type.String({ description: "File or directory path to lint, relative to the CWD or absolute" }),
			}),
			exposure,

			async execute(_toolCallId, params, signal): Promise<AgentToolResult<SeDetails>> {
				let stdout: string;
				let code: number;
				try {
					({ stdout, code } = await seLint(params.path, signal));
				} catch (err) {
					const e = err as NodeJS.ErrnoException;
					if (e.code === "ENOENT") {
						throw new Error(
							"`se` not found. Install it first: `gem install simple_english`, then retry.",
						);
					}
					throw new Error(`se lint failed: ${e.message}`);
				}

				if (code !== 0 && code !== 1) {
					throw new Error(`se lint exited with code ${code}: ${stdout.trim()}`);
				}

				const full = stdout.trim();
				if (!full) {
					return {
						content: [{ type: "text" as const, text: `clean: no findings in ${params.path}` }],
						details: { path: params.path, exitCode: code, findings: 0, full: undefined },
					};
				}

				const findings = full.split("\n").length;
				const text =
					full.length > OUTPUT_LIMIT
						? `${full.slice(0, OUTPUT_LIMIT)}\n... truncated (${full.length} chars, ${findings} findings). Full output: run \`se lint ${params.path}\` with bash.`
						: `${findings} finding(s) in ${params.path}:\n${full}`;
				return {
					content: [{ type: "text" as const, text }],
					details: { path: params.path, exitCode: code, findings, full },
				};
			},
		});
	};

	const setEnabled = (next: boolean, ctx: ExtensionContext): void => {
		enabled = next;
		pi.appendEntry(STATE_ENTRY_TYPE, { enabled } satisfies SeLintState);
		registerLintTool(next ? "direct" : "hidden");
		updateStatus(ctx);
		ctx.ui.notify(`Prose lint ${next ? "on" : "off"}`, "info");
	};

	const restoreState = (ctx: ExtensionContext): void => {
		enabled = savedEnabled(ctx) ?? true;
		registerLintTool(enabled ? "direct" : "hidden");
		updateStatus(ctx);
	};

	registerLintTool("direct");

	pi.registerCommand("se", {
		description: "Toggle prose linting (se_lint tool and edit enforcement) for this session",
		handler: async (args, ctx) => {
			const argument = args.trim().toLowerCase();

			if (argument === "") {
				setEnabled(!enabled, ctx);
				return;
			}

			if (argument === "on") {
				setEnabled(true, ctx);
				return;
			}

			if (argument === "off" || argument === "stop") {
				setEnabled(false, ctx);
				return;
			}

			ctx.ui.notify("Usage: /se [on|off]", "warning");
		},
	});

	pi.on("tool_result", async (event: ToolResultEvent): Promise<ToolResultEventResult | undefined> => {
		if (!enabled) return;
		if (event.toolName !== "edit" && event.toolName !== "write") return;
		// A failed edit wrote nothing: there is nothing to lint.
		if (event.isError) return;
		const path = event.input.path;
		if (typeof path !== "string" || path === "") return;
		const feedback = await lintFeedback(path);
		if (!feedback) return;
		return { content: [...event.content, { type: "text" as const, text: feedback }] };
	});

	pi.on("session_start", async (_event, ctx) => restoreState(ctx));
	pi.on("session_tree", async (_event, ctx) => restoreState(ctx));
}
