# Agent verification facts

Recorded 2026-10-02 against the live docs and one live Claude Code
session. The fixture `test/fixtures/claude_code/post_tool_use.json` comes
from that session, with the paths replaced by generic ones.

## claude-code-hook

A PostToolUse hook runs after Edit, Write, or NotebookEdit. It receives
one JSON object on stdin. The fields the hook reads:

- `hook_event_name`: always `PostToolUse`
- `tool_name`: `Write`, `Edit`, or `NotebookEdit`
- `tool_input.file_path`: the edited file
- `cwd`: the project directory

The full payload also carries `session_id`, `transcript_path`,
`prompt_id`, `permission_mode`, `effort`, `tool_response`,
`tool_use_id`, and `duration_ms`. The hook ignores them.

Feedback: exit 0 and print one JSON object on stdout.

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "the findings text"
  }
}
```

Claude sees `additionalContext` as a system reminder on its next
request. Exit code 2 is the blocking path. It shows stderr to Claude as
an error. We use exit 0 plus `additionalContext`, the documented clean
path for PostToolUse.

Source: the Claude Code hooks reference at
`https://docs.anthropic.com/en/docs/claude-code/hooks`, plus the
captured session.

## mcp-stdio

The stdio transport is JSON-RPC over stdin and stdout. One message per
line, UTF-8, compact JSON, no embedded newlines. Logs go to stderr.
Nothing but MCP messages goes on stdout.

`initialize` request carries `protocolVersion`, `capabilities`, and
`clientInfo`. The server answers with the same object shape: its chosen
`protocolVersion`, its `capabilities`, and `serverInfo` with `name` and
`version`. The current protocol version is `2025-06-18`. Echo the
client's requested version when the server supports it. Answer
`2025-06-18` otherwise.

After the response, the client sends `notifications/initialized`. It is
a notification. It has no `id` and gets no response.

`tools/list` answers `{"tools": [...]}`. Each tool carries `name`,
`description`, and `inputSchema`. `tools/call` answers
`{"content": [{"type": "text", "text": "..."}], "isError": false}`.

Source: the MCP specification at
`https://modelcontextprotocol.io/specification/2025-06-18`, transports
and lifecycle pages.

## codex-plugin

The manifest lives at `.codex-plugin/plugin.json` inside the plugin
root. Fields:

```json
{
  "name": "the-plugin-name",
  "version": "0.0.0",
  "description": "one line",
  "skills": "./skills/",
  "mcpServers": "./.mcp.json"
}
```

The `.mcp.json` top-level key is `mcpServers`. The paths are relative to
the plugin root and start with `./`.

Local install needs a local marketplace. A directory holds
`.agents/plugins/marketplace.json`:

```json
{
  "name": "local-dev",
  "plugins": [
    {
      "name": "the-plugin-name",
      "source": {"source": "local", "path": "./plugins/the-plugin-name"}
    }
  ]
}
```

Then:

```bash
codex plugin marketplace add ./local-marketplace
codex plugin add the-plugin-name@local-dev
```

Enablement comes from `codex plugin add`, which writes global
state. A headless `codex exec` 0.160.0 ignores a project-level
`.codex/config.toml`: a bogus key in it does not fail
`--strict-config`. The plugin docs still show a repo-enable block,
but no headless run needs one.

Codex launches a plugin's MCP server with a filtered environment:
`GEM_HOME` and `GEM_PATH` do not reach the child. So a gem-installed
`se` must live where its binstub finds it without those variables.
Otherwise the server dies inside rubygems before it answers, and
codex drops the tool. Verified 2026-10-03 with codex 0.160.0.

Two more codex 0.160.0 facts, same date:

1. A plugin MCP server is optional. It must answer `initialize`
   inside the startup grace (about one second), or codex omits it
   from the session's tool binding. The agent then reports the tool
   as unavailable. A trace log shows it as
   `omitting pending optional MCP server`.
2. MCP tools are not separate declarations in the request. They
   resolve inside the `exec` orchestrator as
   `tools.mcp__<server>__<tool>`, for example
   `tools.mcp__simple-english__lint`.

Source: the OpenAI plugin docs at
`https://developers.openai.com/plugins/build/plugins` and the Codex
non-interactive docs.

## local-install

Claude Code offers two local paths. Development loads the plugin root
directly:

```bash
claude --plugin-dir /path/to/plugin-root
```

The full flow tests the marketplace install:

```bash
claude plugin validate /path/to/marketplace-root
claude plugin marketplace add /path/to/marketplace-root
claude plugin install name@marketplace
```

The pi package loads from a local directory path listed in the `packages`
array of the pi settings. Superpowers shows the shape: a directory with
`package.json` carrying a `pi` block.

Codex installs from a local marketplace, as the codex-plugin section
records.

## headless

Claude Code runs headless with `-p`. Use
`--permission-mode acceptEdits` so file edits need no person:

```bash
claude -p --permission-mode acceptEdits "the prompt"
```

Codex runs headless with `exec`. Use `--sandbox workspace-write` when
the run edits files:

```bash
codex exec --sandbox workspace-write "the prompt"
```

pi runs headless with `-p`. Add `-a` to auto-approve tool calls:

```bash
pi -a -p "the prompt"
```

All three print the final answer on stdout.

## pi-git-install

Live-tested 2026-10-02 with `pi install git:github.com/TonyCTHsu/simple-english@<branch>`
into a scratch config dir, then read from pi's package manager source.

Pi clones the repo, then collects package resources from the clone
root only. It reads `package.json` at the clone root. It also reads
conventional directories (`extensions/`, `skills/`) beside it. It
never searches subdirectories. This repo keeps `package.json` in
`integrations/pi/`. So a git install of this repo reports success and
loads nothing.

Two consequences, both release decisions, not bugs in pi:

1. The pi package installs from a local path today
   (`pi install ./integrations/pi`, from a full checkout) or from npm
   once published. It cannot be git-installed from this repo as laid
   out.
2. Skills are vendored into each adapter dir since 2026-10-03. The
   pi package names `./skills`, inside its own root, so `npm pack`
   carries it. An earlier symlink to `../shared/skills` dangled in any
   install that copied a package dir alone. A test now pins every
   vendored copy to the shared skill.
