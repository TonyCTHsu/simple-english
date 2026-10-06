/**
 * se_lint - lint Markdown prose and code comments with simple_english.
 *
 * Shells out to the `se` CLI. Assumes the gem is installed; on a
 * missing binary the tool fails with install steps.
 */

import { execFile } from "node:child_process";
import { Type } from "typebox";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const OUTPUT_LIMIT = 4000;
// ponytail: 120s allows a cold daemon boot (LanguageTool + JVM). If that
// ever proves slow in practice, cut to 30s and pre-warm via `se serve`.
const TIMEOUT_MS = 120_000;

export default function (pi: ExtensionAPI) {
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
			path: Type.String({ description: "File or directory to lint, relative to the CWD or absolute" }),
		}),

		async execute(_toolCallId, params, signal) {
			let stdout: string;
			let code: number;
			try {
				({ stdout, code } = await new Promise<{ stdout: string; code: number }>((resolve, reject) => {
					execFile(
						"se",
						["lint", params.path],
						{ timeout: TIMEOUT_MS, maxBuffer: 1024 * 1024, signal },
						(error, out) => {
							if (error && typeof error.code !== "number") {
								reject(error);
								return;
							}
							resolve({ stdout: out, code: (error?.code as number | undefined) ?? 0 });
						},
					);
				}));
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
					details: { path: params.path, exitCode: code, findings: 0 },
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
}
