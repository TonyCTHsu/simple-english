# simple-english for Codex

A Codex plugin that lints the prose the agent writes.

## What it does

The plugin ships the `simple-english-lint` skill and an MCP server.
The server runs `se mcp` from the gem. The skill tells the agent to
call the `lint` tool on the `simple-english` server and fix every
finding.

## Prerequisites

The linter is a Ruby gem. Install it once, before the adapter:

```bash
gem install simple_english
```

## Install

Each user runs both commands:

```bash
codex plugin marketplace add TonyCTHsu/simple-english
codex plugin add simple-english@simple-english
```

Codex holds plugin enablement in global state, so there is no
project-scope install. The project-level piece is the approval. MCP
tool calls need approval by default. Put this in the project's
`.codex/config.toml` and commit it, so every teammate starts with the
server approved:

```toml
[plugins."simple-english@simple-english".mcp_servers.simple-english]
default_tools_approval_mode = "approve"
```

A development checkout installs from a local marketplace instead. The
recipe is in `integrations/verification.md` in this repository.

## Versions

The plugin version tracks the gem version. The changelog is the
repository changelog. See the section that matches the version:

https://github.com/TonyCTHsu/simple-english/blob/master/CHANGELOG.md
