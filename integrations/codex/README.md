# simple-english for Codex

A Codex plugin that lints the prose the agent writes.

## What it does

The plugin ships the `simple-english-lint` skill and an MCP server.
The server runs `se mcp` from the gem. The skill tells the agent to
call the `lint` tool and fix every finding.

## Install

Install the gem first. Then install the plugin through a local
marketplace:

```bash
codex plugin marketplace add ./local-marketplace
codex plugin add simple-english@local-dev
```

`integrations/verification.md` in the repository holds the full
steps: the marketplace file and the approval settings.

## Versions

The plugin version tracks the gem version. The changelog is the
repository changelog. See the section that matches the version:

https://github.com/TonyCTHsu/simple-english/blob/master/CHANGELOG.md
