# simple-english for Codex

A Codex plugin that lints the prose the agent writes.

## What it does

The plugin ships the `simple-english-lint` skill and an MCP server.
The server runs `se mcp` from the gem. The skill tells the agent to
call the `lint` tool on the `simple-english` server and fix every
finding.

## Install

Install the gem first. Then add this repository as a marketplace
and install the plugin:

```bash
codex plugin marketplace add TonyCTHsu/simple-english
codex plugin add simple-english@simple-english
```

MCP tool calls need approval by default. `integrations/verification.md`
holds the approval settings, and a local-marketplace recipe for a
development checkout.

## Versions

The plugin version tracks the gem version. The changelog is the
repository changelog. See the section that matches the version:

https://github.com/TonyCTHsu/simple-english/blob/master/CHANGELOG.md
