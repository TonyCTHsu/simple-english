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

Codex accepts the portable Agent Plugins format, the same one as
Cursor. The root `plugin.json` carries the v1.0.0 `$schema`. The
root `mcp.json` names a stdio server, and a root `skills/`
directory holds the skills. The manifest carries no `skills` or
`mcpServers` pointers: Codex finds the components by convention.
OpenAI's plugin docs describe the format and keep
`.codex-plugin/plugin.json` as a legacy compatibility fallback,
which this plugin no longer uses.

The install flow is unchanged. Verified 2026-10-08 with codex
0.160.0, live, up to server registration: the local marketplace
installs the portable manifest. `codex mcp list` shows the
`simple-english` server running `se mcp`, with `PLUGIN_ROOT` and
`PLUGIN_DATA` injected. The headless agent run is not yet re-run
on the portable manifest. The earlier run (2026-10-03) confirmed
the same server behind the legacy manifest.

Local install needs a local marketplace. This repository ships one,
under `.agents/plugins/marketplace.json`:

```json
{
  "name": "simple-english",
  "plugins": [
    {
      "name": "simple-english",
      "source": {
        "source": "local",
        "path": "./integrations/codex"
      }
    }
  ]
}
```

Users add the repository as the marketplace:

```bash
codex plugin marketplace add TonyCTHsu/simple-english
codex plugin add simple-english@simple-english
```

A development marketplace can hold other plugins too. A directory
holds `.agents/plugins/marketplace.json`:

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

Enablement comes from `codex plugin add`, which writes global state.
Every MCP tool call asks for approval by default. A headless
`codex exec` answers every approval with policy `never`, so the
call fails: "MCP tool call requires approval, but approval
policy is never". Approve the plugin's server in the project's
`.codex/config.toml`:

```toml
[plugins."the-plugin-name@local-dev".mcp_servers.the-server-name]
default_tools_approval_mode = "approve"
```

The server name is the key in the plugin's `mcp.json`. Check it with
`codex mcp list`.

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

## cursor

Cursor supports two plugin formats. A Cursor Plugin puts its
manifest at `.cursor-plugin/plugin.json` and covers
Cursor-specific parts: rules, agents, commands, and hooks. An Agent
Plugin follows the open Agent Plugins standard, v1.0.0, with its
`plugin.json` manifest at the plugin root. The `skills/`
directory and the root `mcp.json` complete the bundle, and
`mcp.json` allows only `$schema` and `mcpServers` at the top level.
The manifest is closed. Client-specific data belongs
under `extensions`.

Install happens in the Customize pane, at project or user scope.
Local testing drops the plugin directory into
`~/.cursor/plugins/local`, then a window reload. The Cursor
Marketplace distributes plugins as Git repositories, manually
reviewed, submitted through the Cursor team. Teams and Enterprise
plans add private team marketplaces.

Cursor also accepts the unwired project files. `.cursor/mcp.json`
adds an MCP server and `.cursor/skills/` adds skills, or the same
paths under `~/.cursor/` serve every project. A plugin installs
both at once.

The Cursor CLI, `agent`, drives the same agent headless. Its
install script is `curl https://cursor.com/install -fsS | bash`.
A person authenticates with `agent login`. A CI run needs
`CURSOR_API_KEY`, but the dashboard sells that key only on a paid
plan (checked 2026-10-07). The workflow therefore keeps the cursor
job dispatch-only. `agent --list-models` names the models, and a
free plan may use only `auto`.

A headless run uses `-p` with `--output-format json`. `--plugin-dir`
loads the plugin directory for one run. `--approve-mcps` alone does
not clear MCP tool calls: each call dies with "User rejected MCP",
and `--force` allows them. `--trust` skips the workspace prompt.
The plugin's MCP tool reaches the agent as
`plugin-<name>-<server>-<tool>`, and the agent reads the skill on
its own. `agent mcp list` shows only the `mcp.json` servers, never
a plugin's.

Verified 2026-10-07 with agent 2026.10.01-e373342 in live
sessions. The seeded scenario passed: the agent fixed the
violations it was not asked to touch and answered clean. One run
of four died mid-session with `RetriableError: WritableIterable
closed` after connection retries, so the e2e leg keeps its second
attempt.

Source: the plugin docs at `https://cursor.com/docs/plugins`, the
CLI docs at `https://cursor.com/docs/cli/overview`, and the
specification at `https://agent-plugins.org/specification`.

## opencode

opencode has no Agent Plugins support (open feature request,
anomalyco/opencode#40993). The integration is config wiring: an
`mcp` block in the project's `opencode.json`, and the skill under
`.opencode/skills/`. A local MCP server takes `type: "local"` and
`command` as an array. MCP tools are permission-keyed
`<server>_<tool>`, and a headless run can never answer an approval,
so the config allows `simple-english_lint` and `edit` up front.

`opencode run` ignores the process cwd and picks the enclosing git
repo, so a headless run in another directory needs `--dir`.
Verified live 2026-10-10, run 38094528402: without `--dir` the agent
searched the repository, not the scenario directory, and never found
the seeded file.

The Google provider reads `GOOGLE_GENERATIVE_AI_API_KEY`, not
`GEMINI_API_KEY`. Verified live, run 38094380373: the model call dies
with ProviderAuthError naming the variable. `opencode mcp list`
confirms a project's config, and the MCP tool reaches the model as
`simple-english_lint`.

The e2e leg passed 2026-10-10 with opencode 1.18.35 and
`openai/gpt-6-luna`, pass on attempt 2. `google/gemini-3.1-flash-lite`
called the lint tool but did not fix the findings, so it fails the
gate. Weak models are the first suspect on a red opencode leg.

Source: the opencode docs at `https://docs.opencode.ai/docs/config`,
the tools and MCP pages, and the runs named above.

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

## docs-walkthrough

Recorded 2026-10-11 on macOS. Every integration README's install
instructions ran as written, against the released gem 0.6.0 from
RubyGems and the published npm package 0.6.0. Each run used an
isolated home: scratch `CLAUDE_CONFIG_DIR`, `CODEX_HOME`, and
`PI_CODING_AGENT_DIR`, a redirected `HOME` for the Cursor copy, and a
temporary project directory for opencode. No real agent config was
touched. The e2e workflow stays the functional gate. This walkthrough
checks that the written instructions work.

claude-code: `gem install simple_english` pulls 0.6.0 from RubyGems.
`claude plugin marketplace add TonyCTHsu/simple-english` and
`claude plugin install simple-english@simple-english` succeed in a
scratch config dir. `claude plugin list` shows the plugin at 0.6.0,
user scope, enabled. The project-scope variants are not exercised
yet.

codex: `codex plugin marketplace add TonyCTHsu/simple-english`
clones the repo as a marketplace. `codex plugin add
simple-english@simple-english` caches 0.6.0. `codex mcp list` shows
the server: command `se`, args `mcp`, status enabled. The approval
config from the README did not run here. The e2e leg proves the same
shape with local-marketplace names.

cursor: copying `integrations/cursor` to
`~/.cursor/plugins/local/simple-english` lands `plugin.json`,
`mcp.json`, and `skills/` as the README says. The reload and the
Customize check are GUI steps, so they stay manual. The cursor CLI
was not installed on this host, so its headless path did not run
here either.

opencode: the README's `opencode.json` block plus the skill copy into
`.opencode/skills/`. `opencode mcp list` reports simple-english
connected. The server runs `se mcp`. The README does not mention the
`permission` allow block that headless runs need. The e2e leg writes
it.

pi: `pi install npm:pi-simple-english` into a scratch agent dir
installs the package. It lands with `extensions/se-lint.ts` and
`skills/simple-english-lint/SKILL.md` beside `package.json`, the
layout pi's loader reads. The npm path had no recorded run before
this date. The e2e leg tests the local checkout by design, and the
published tarball matches the dev directory.
