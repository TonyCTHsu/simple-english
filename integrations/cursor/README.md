# simple-english for Cursor

A Cursor integration that lints the prose the agent writes.

## What it does

The integration ships two files. `.cursor/mcp.json` adds the
`simple-english` MCP server, which runs `se mcp` from the gem. The
`simple-english-lint` skill tells the agent to call the `lint` tool
and fix every finding.

## Prerequisites

The linter is a Ruby gem. Install it once, before the adapter:

```bash
gem install simple_english
```

## Install

Cursor has no plugin install. Copy the files into your project:

```bash
cp -R integrations/cursor/.cursor .
```

Cursor loads the MCP server and the skill on the next session. If your
project already has a `.cursor/mcp.json`, merge the `simple-english`
block into it.

For every project, copy the two files into your home directory
instead: `~/.cursor/mcp.json` and
`~/.cursor/skills/simple-english-lint/SKILL.md`.

## Versions

The adapter tracks the gem version. The changelog is the repository
changelog. See the section that matches the version:

https://github.com/TonyCTHsu/simple-english/blob/master/CHANGELOG.md
