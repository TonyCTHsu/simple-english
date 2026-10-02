# Agent Integrations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build three agent adapters (pi, Claude Code, Codex), the `se mcp` stdio server, and a validation framework that proves all of them work.

**Architecture:** The engine stays as is. `se mcp` joins the daemon tier as a hand-rolled JSON-RPC stdio server over the existing lint pipeline. Three thin adapters live under `integrations/`, each wired to that agent's strongest primitive. Contract tests replay fixtures in CI without tokens. A separate on-demand workflow drives live agents end to end.

**Tech Stack:** Ruby 3.3 (minitest, Thor), bash hook script, TypeScript pi extension, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-10-02-agent-integrations-design.md`

## Global Constraints

- Zero new runtime dependencies. The MCP server hand-rolls JSON-RPC framing, in the style of `daemon/http.rb`.
- Unit tests run without LanguageTool. Stub the lint path where a test needs the daemon.
- Internals are `private_class_method`. One object definition per file.
- Never commit on the default branch. Branch names start with `tonyc.t.hsu/`.
- New GitHub Actions steps pin to the release SHA and comment the release, per the repo pin rule.
- Every new `.md` file passes `rake lint`. Prose follows the plain-English rules.
- A changie fragment lands only where the CLI behavior changes. `se mcp` is one `Added` entry. Adapter files and tests get none.
- The exposed names list in the spec (section Names) is the source of truth. Renames stay inside that list until release.

## Review Focus

Input classes the spec implies but no happy-path test exercises, most likely first. A test in the owning task pins each one.

1. Hook fires on a file that is not Markdown. Expect a quiet exit 0, no feedback, no lint run. Pinned in Task 7.
2. Daemon unreachable, or `se` missing from PATH. The hook degrades quietly. The MCP tool returns a JSON-RPC error, never a crash. Pinned in Tasks 2 and 7.
3. Malformed or unexpected JSON-RPC input: unknown method, notification, or a request with no `id`. The server answers with the protocol error, or stays silent for notifications. Pinned in Task 2.
4. Hook payload with unusual paths: spaces, unicode, or a file that does not exist. The hook never feeds a broken command line to the linter. Pinned in Task 7.
5. MCP `lint` called with a missing path or a directory. The tool returns an `isError` result with a clear message. Pinned in Task 2.

---

### Task 1: Verify agent facts

The later tasks consume exact schemas and commands. This task records them. Nothing else in the plan can guess these.
**Files:**
- Create: `integrations/verification.md`
- Create: `test/fixtures/claude_code/post_tool_use.json`

**Interfaces:**
- Produces: `integrations/verification.md` sections named `claude-code-hook`, `mcp-stdio`, `codex-plugin`, `local-install`, `headless`. Tasks 2, 7, 8, and 10 cite them.

- [ ] **Step 1: Verify the Claude Code hook feedback schema**

Check the live docs. Record the exact stdin payload fields for a PostToolUse
hook after Edit and Write. Record the exit code that feeds findings back to
Claude. Record the stdout JSON field names Claude reads. Capture one real
payload into `test/fixtures/claude_code/post_tool_use.json` from a live
session.

- [ ] **Step 2: Verify the MCP stdio framing and protocol version**

Check the live MCP docs. Record whether stdio messages are newline-delimited
JSON, and the current `protocolVersion` string to echo in `initialize`.

- [ ] **Step 3: Verify the Codex plugin manifest and install commands**

Check the live docs. Record the required fields of `.codex-plugin/plugin.json`,
and the command that installs a plugin from a local path.

- [ ] **Step 4: Verify local installs and headless runs**

Record the exact commands: `claude plugin marketplace add` from a local path,
`claude -p` headless use, `codex exec` headless use, and the pi non-interactive
or headless invocation.

- [ ] **Step 5: Lint and commit**

Run: `rake lint`. Expected: clean.
Commit: `Record the agent verification facts`.

### Task 2: MCP responder

The protocol brain: one pure function from a request to a response.

**Files:**
- Create: `lib/simple_english/daemon/mcp.rb`
- Test: `test/simple_english/mcp_respond_test.rb`

**Interfaces:**
- Produces: `SimpleEnglish::MCP.respond(request, linter:) -> Hash or nil`. `request` is a parsed JSON-RPC request Hash. `linter` is a callable that takes a path and returns findings or nil (nil means unreachable). Returns the response Hash, or nil for notifications.
- Produces: tool descriptor name `lint`, parameter `path` (string, required).

- [ ] **Step 1: Write the failing tests**

Cases:

- `initialize` echoes the protocol version from `verification.md` and names
  the server `simple-english`.
- `tools/list` returns the one `lint` tool with a `path` input schema.
- `tools/call` with a stub linter returning findings answers with text
  content, one line per finding, and `isError` false.
- A stub linter returning `[]` answers `clean`.
- A stub linter returning nil answers with a JSON-RPC error whose message
  names the daemon.
- `tools/call` with a missing path or a directory answers with `isError`
  true and a clear message.
- An unknown method answers with error code -32601. Input without `id`
  returns nil.

- [ ] **Step 2: Run them to verify they fail**

Run: `bundle exec ruby test/run.rb`. Expected: load error, no such file
`mcp.rb`.

- [ ] **Step 3: Implement `MCP.respond` in `lib/simple_english/daemon/mcp.rb`**

Module with `module_function` and `private_class_method` for helpers, per the
repo pattern. Findings render through the existing CLI report path so MCP text
matches `se lint` output. Every method returns the response Hash or nil. No
IO in this file.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bundle exec ruby test/run.rb`. Expected: all pass.

- [ ] **Step 5: Commit**

Commit: `Add the MCP JSON-RPC responder`.

### Task 3: MCP stdio loop and the `se mcp` subcommand

**Files:**
- Modify: `lib/simple_english/daemon/mcp.rb`
- Modify: `lib/simple_english/cli.rb`
- Test: `test/simple_english/mcp_stdio_test.rb`

**Interfaces:**
- Consumes: `MCP.respond` from Task 2.
- Produces: `SimpleEnglish::MCP.run(io:, out:, linter:)`. Defaults: `$stdin`, `$stdout`, and a linter that calls `SimpleEnglish.lint_file(path)`. Reads one JSON object per line until EOF, writes one response per line.
- Produces: CLI subcommand `se mcp`.

- [ ] **Step 1: Write the failing tests**

Drive `MCP.run` with `StringIO` doubles. A three-line script (initialize,
tools/list, tools/call with a stub linter) produces three response lines in
order. A notification line produces no output. EOF ends the loop cleanly.

- [ ] **Step 2: Run them to verify they fail**

Run: `bundle exec ruby test/run.rb`. Expected: no method `run`.

- [ ] **Step 3: Implement the loop and the subcommand**

`MCP.run` wraps `respond`. In `cli.rb`, add the Thor task with
`desc "mcp", "Run the MCP stdio server"` next to `serve`. The task body is
one call to `MCP.run`.

- [ ] **Step 4: Run the tests and add the changie entry**

Run: `bundle exec ruby test/run.rb`. Expected: all pass.
Run: `changie new`, pick `Added`, one-line body: the `se mcp` subcommand runs
an MCP stdio server with one lint tool.

- [ ] **Step 5: Commit**

Commit: `Run the MCP server over stdio behind se mcp`.

### Task 4: Freeze the `se --json` contract

**Files:**
- Test: `test/simple_english/cli_json_contract_test.rb`

**Interfaces:**
- Consumes: the existing JSON report format in `cli.rb`.
- Produces: a test that fails when a field is renamed or removed.

- [ ] **Step 1: Write the failing test**

Follow `cli_format_test.rb`. Feed fabricated findings through the JSON report
path and assert the exact top-level keys and per-finding keys the hook script
will parse. Assert no key disappears across the pair, by asserting the full
key set literally.

- [ ] **Step 2: Run it, then mark it expected-pass**

Run: `bundle exec ruby test/run.rb`. The test must pass against the current
output. If it fails now, the current output differs from the README example.
Fix the assertion to match reality. Its job is to fail on future drift.

- [ ] **Step 3: Commit**

Commit: `Pin the se json output shape with a contract test`.

### Task 5: Integrations scaffold and shared skill

**Files:**
- Create: `integrations/shared/skills/lint/SKILL.md`

**Interfaces:**
- Produces: the skill file all three adapters reference. It names the tools
  `se_lint` (pi) and `lint` (MCP), never adapter paths.

- [ ] **Step 1: Write the skill**

Short instruction file: lint after writing prose, fix every finding, re-run
until clean. No agent-specific detail.

- [ ] **Step 2: Lint and commit**

Run: `rake lint`. Expected: clean.
Commit: `Add the shared lint skill`.

### Task 6: pi package

**Files:**
- Create: `integrations/pi/package.json`
- Create: `integrations/pi/extensions/se-lint.ts`
- Test: `test/simple_english/integrations_pi_test.rb`

**Interfaces:**
- Consumes: the skill from Task 5.
- Produces: a pi package loadable from a local path. `package.json` holds the `pi` block with `extensions` and `skills`, name `simple-english`.

- [ ] **Step 1: Write the failing test**

Ruby test: `integrations/pi/package.json` parses, the `pi` block lists the
extension file and the skills directory, and both exist on disk. The extension
source contains the tool name `se_lint`.

- [ ] **Step 2: Run it to verify it fails**

Run: `bundle exec ruby test/run.rb`. Expected: missing file.

- [ ] **Step 3: Move the extension and write the manifest**

Copy the local extension from
`~/.pi/agent/extensions/se-lint.ts` into `integrations/pi/extensions/`. Point
its skill reference at `../shared/skills/lint`. Write `package.json` with the
`pi` block in the superpowers style.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bundle exec ruby test/run.rb`. Expected: all pass.

- [ ] **Step 5: Commit**

Commit: `Add the pi package under integrations`.

### Task 7: Claude Code plugin

**Files:**
- Create: `.claude-plugin/marketplace.json`
- Create: `integrations/claude-code/.claude-plugin/plugin.json`
- Create: `integrations/claude-code/hooks/hooks.json`
- Create: `integrations/claude-code/hooks/lint.sh`
- Create: `integrations/claude-code/commands/lint.md`
- Test: `test/simple_english/integrations_hook_test.rb`

**Interfaces:**
- Consumes: the fixture from Task 1, the feedback schema from `verification.md` section `claude-code-hook`, the skill from Task 5.
- Produces: `lint.sh`, a bash script. Stdin: the PostToolUse payload JSON. Env: `SE_BIN` overrides the `se` binary, default `se`. Behavior: non-Markdown path exits 0 with no output. Markdown path with findings exits with the feedback code from `verification.md` and writes the feedback JSON on stdout. Linter unreachable exits 0 with no output.

- [ ] **Step 1: Write the failing tests**

Spawn `lint.sh` with the fixture payload on stdin. Point `SE_BIN` at a
stub script that prints canned JSON findings. Assert the exit code and the
stdout JSON per `verification.md`. Cases:

- findings present
- clean output
- a `.py` file path
- a path with spaces
- a payload where `file_path` is missing
- `SE_BIN` pointing at a nonexistent binary
- the stub exiting non-zero

- [ ] **Step 2: Run them to verify they fail**

Run: `bundle exec ruby test/run.rb`. Expected: missing file.

- [ ] **Step 3: Write the manifests and the hook**

`marketplace.json` lists one plugin, source `./integrations/claude-code`.
`hooks.json` wires PostToolUse for Edit and Write to
`${CLAUDE_PLUGIN_ROOT}/hooks/lint.sh`. `lint.sh` parses the payload with a
`ruby -rjson` one-liner, filters on `.md`, runs `$SE_BIN lint --json`, and
emits the feedback shape from `verification.md`. No `jq` dependency.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bundle exec ruby test/run.rb`. Expected: all pass.

- [ ] **Step 5: Commit**

Commit: `Add the Claude Code plugin with the lint hook`.

### Task 8: Codex plugin

**Files:**
- Create: `integrations/codex/.codex-plugin/plugin.json`
- Create: `integrations/codex/.mcp.json`
- Test: `test/simple_english/integrations_codex_test.rb`

**Interfaces:**
- Consumes: the manifest fields from `verification.md` section `codex-plugin`, `se mcp` from Task 3, the skill from Task 5.
- Produces: a Codex plugin installable from a local path, wired to `se mcp`.

- [ ] **Step 1: Write the failing test**

The manifest parses, carries the required fields from `verification.md`, and
points its skills at the shared skill. `.mcp.json` names the command `se mcp`.

- [ ] **Step 2: Run it to verify it fails**

Run: `bundle exec ruby test/run.rb`. Expected: missing file.

- [ ] **Step 3: Write the plugin files**

Manifest in the shape `verification.md` records. MCP wiring per the local
install command from that file.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bundle exec ruby test/run.rb`. Expected: all pass.

- [ ] **Step 5: Commit**

Commit: `Add the Codex plugin wired to se mcp`.

### Task 9: Name audit

**Files:**
- Test: `test/simple_english/integrations_names_test.rb`

**Interfaces:**
- Consumes: the Names list in the spec, the files from Tasks 6 to 8.

- [ ] **Step 1: Write the failing test**

For each name in the spec Names list, grep the repo for occurrences outside
the recorded places (`integrations/`, `.claude-plugin/`, the spec itself, the
test). Assert the outside list is empty.

- [ ] **Step 2: Run it and fix the findings, then commit**

Run: `bundle exec ruby test/run.rb`. A failure names a file that leaks a
name. Fix by rename or by adding the place to the recorded list in the spec.
Commit: `Audit the exposed names with a test`.

### Task 10: Layer 2, automated agent runs

**Files:**
- Create: `bin/e2e-agents`
- Create: `.github/workflows/e2e-agents.yml`

**Interfaces:**
- Consumes: the headless commands from `verification.md` section `headless`, the adapters from Tasks 6 to 8.
- Produces: `bin/e2e-agents <pi|claude|codex|all>` exits 0 when the agent fixes three seeded violations on its own, and retries once before failing. The workflow runs it on demand with the provider secrets.

- [ ] **Step 1: Write the scenario script**

Ruby, in the style of `bin/e2e-story`. For each agent: install the adapter
from a local path with the command from `verification.md`. Copy a corpus
`before` file into a temp dir. Run the headless agent with a prompt to
improve the file. Then run `se lint` and pass only on clean output.
`SE_E2E_SKIP=1`
prints the plan and exits 0, for machines without credentials.

- [ ] **Step 2: Verify locally without credentials**

Run: `SE_E2E_SKIP=1 bin/e2e-agents all`. Expected: prints the three scenarios,
exits 0.

- [ ] **Step 3: Write the workflow**

`workflow_dispatch` only, no push trigger. One job per agent, each with a
retry. Secrets come from GitHub encrypted variables the maintainer adds:
the Claude Code, Codex, and pi provider credentials. Pin every action to a
release SHA with the release comment, per the repo rule.

- [ ] **Step 4: Actionlint and commit**

Run: `actionlint .github/workflows/e2e-agents.yml`. Expected: clean.
Commit: `Add the automated agent e2e scenarios`.

### Task 11: Documentation

**Files:**
- Modify: `docs/DEVELOPMENT.md`
- Modify: `README.md`

- [ ] **Step 1: Write the two sections**

`DEVELOPMENT.md` gains the integrations layout, the layer 1 and layer 2 test
story, and the local install commands from `verification.md`. `README.md`
gains one short section: what the integrations are, that they are not released
yet, and how to try them from local paths.

- [ ] **Step 2: Lint, run the full suite, and commit**

Run: `rake lint` then `bundle exec ruby test/run.rb`. Expected: both clean.
Commit: `Document the agent integrations`.
