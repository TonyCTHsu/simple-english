# Agent integrations design

Status: draft. Written 2026-10-02. This spec needs review before any
implementation starts.

## Goal

Let agents in pi, Claude Code, and Codex lint the prose they write, and fix
what the linter finds. Each agent gets one adapter. The adapters stay thin.
The engine does all the work.

One story drives all three adapters. The agent writes prose. The linter
returns findings into the agent's context. The agent rewrites until the
linter reports clean. The agent decides only how findings reach the
context.

This plan delivers three plugins, `se mcp`, and a test framework that
proves all of them work. Release is out of scope. The release path gets
a decision after this plan is done.

## Non-goals

- No fourth adapter. A new MCP-capable client gets lint through `se mcp`
  with no new code.
- No engine logic in any adapter. Filtering, formatting, and fallbacks
  belong in the CLI or in `se mcp`.
- No release from this repo. Version stamping, marketplace publishing,
  and any repo split are decisions for later.

## Architecture

Each agent gets the adapter that matches its strongest primitive. Pi
registers tools in its own process. Claude Code enforces through lifecycle
hooks. Codex extends through MCP.

```
                 engine: gem + rules + daemon
                           |
                   se mcp  (stdio JSON-RPC)
                  /        |         \         \
     pi extension   Claude Code    Codex    any MCP client
   (native tool)     (hook first,  (MCP is   (no new code)
                     MCP optional)  the core)
```

The CLI stays the engine interface. Humans run it, CI runs it, and the
Claude Code hook is a shell command that runs it. MCP is one transport
among three, not a replacement for the CLI.

## Components

### Engine (exists)

The gem, the rules, the daemon, and the CLI need no change beyond one
subcommand.

### `se mcp` (new, in the gem)

- `lib/simple_english/daemon/mcp.rb` runs a stdio JSON-RPC server. It
  answers `initialize`, `tools/list`, and `tools/call`.
- It exposes one tool, `lint`, with a file path argument. It delegates to
  the same pipeline as the daemon.
- The framing is hand-rolled, in the style of `daemon/http.rb`. No new
  runtime dependencies.
- `cli.rb` gains the `mcp` subcommand.

### Shared skill

`integrations/shared/skills/lint/SKILL.md` holds one instruction file for
all three agents. It tells the agent to lint after writing prose, fix every
finding, and re-run until the result is clean. It names tools, never
adapter details.

### pi package

`integrations/pi/` holds a `package.json` with the pi block, the
`se_lint` extension, and the skill. The extension exists today as a
local file, so this is a move, not new work. The tool description drives
when the agent calls it.

### Claude Code plugin

`integrations/claude-code/` holds `plugin.json`, `hooks/hooks.json`, and
`hooks/lint.sh`. The hook fires after Edit and Write on Markdown files.
It probes the daemon, runs `se --json`, and returns findings as hook
feedback, so Claude fixes them in its next turn. A `/lint` slash command
gives on-demand access. The plugin may also register `se mcp` for prose
that never lands in a file.

### Codex plugin

`integrations/codex/` holds `plugin.json`, the skill, and MCP wiring that
names `se mcp`. The skill makes Codex call the tool. The server provides
it.

### Marketplace

`.claude-plugin/marketplace.json` sits at the repo root. It lists one
plugin and points at `./integrations/claude-code`. It is the only root
footprint.

## Contracts

These five surfaces are the compatibility budget. Freeze them at
publish time.

1. The `se --json` findings schema. The hook script parses it. Add
   fields, never rename or remove one.
2. The `se mcp` tool names and parameter shapes. Skills and agents
   reference them.
3. The invocation strings. The binary is `se`. The subcommands are
   `lint`, `mcp`, and `serve`. The daemon handshake is `GET /`.
4. The skill text. It names tools, so it outlives adapters.
5. The prerequisite statement. Every README section says the same words:
   install the gem, run `se setup`.

A change to any contract is a `Breaking` changie entry. Everything else
is free to change.

## Versioning

All artifacts version together as the working assumption. The tag
`vX.Y.Z` matches the gem version and the adapter content. No release
machinery is built now. When the release decision comes, `rake
release:prepare` stamps manifests from one list of files and fields, and
a CI check reports drift.

## Release readiness

Nothing ships from this plan. Record three readiness criteria for the
later release decision.

1. Contract tests cover the frozen `se --json` schema.
2. The daemon runs for a few weeks with no daemon-class fix.
3. The gem ships 1.0 together with the plugins. The pin strangers
   install deserves that signal.

## Testing

Two layers.

Layer 1 runs in CI, costs nothing, and is deterministic. Each adapter
has a wire input that a fixture replays.

1. Claude Code: pipe a captured PostToolUse payload into the hook
   script. Assert the exit code, the feedback format, and the findings.
2. MCP: spawn `se mcp` and drive it with a canned JSON-RPC transcript.
3. Manifests: validate every manifest against its published schema.
4. pi: assert the extension handles clean output, findings, and a
   missing binary.

Layer 2 is automated and spends tokens. A separate workflow runs it on
demand, not on every push. It drives a live agent through one scripted
scenario per adapter. Seed three violations, ask the agent to write the
file, and pass when the agent fixes the findings on its own. Model variance
makes these runs flaky, so the workflow retries once and reports details
on failure. The secrets for the three providers live in GitHub encrypted
variables that only this workflow can use.

## Verification items

Two schemas and one installer fact need a check against live docs
before implementation.

1. The current Claude Code hook feedback schema: exit code and stdout
   framing.
2. The current Codex plugin manifest fields.
3. Whether a pi git install finds a package.json in a subdirectory, or
   only at the repo root.

## Deferred decisions

All of these wait until the plan is done.

1. How and when to release, and from which repo.
2. The pi home at publish time: this repo or the current packaging
   repo.
3. A repo split with a release cycle per adapter. Revisit only when a
   cadence demands it.
