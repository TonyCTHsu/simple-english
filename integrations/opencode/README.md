# simple-english for `opencode`

An `opencode` integration that lints the prose the agent writes.

## What it does

`opencode` has no Agent Plugins support, so this is not a plugin
bundle. The integration wires the two parts `opencode` does support. The
`simple-english` MCP server runs `se mcp` from the gem. The
`lint-simple-english` skill tells the agent to call the `lint` tool
and fix every finding. The `write-simple-english` skill carries the
rules themselves, so the agent writes clean prose the first time.

## Prerequisites

The linter is a Ruby gem. Install it once, before the integration:

```bash
gem install simple_english
```

## Install

Add the MCP server to `opencode.json` in the project root, or to
`~/.config/opencode/opencode.json` for every project:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "servers": {
      "simple-english": {
        "type": "local",
        "command": ["se", "mcp"]
      }
    }
  }
}
```

Copy both skills to `.opencode/skills/` in the project:

```bash
mkdir -p .opencode/skills
cp -R integrations/opencode/skills/lint-simple-english integrations/opencode/skills/write-simple-english .opencode/skills/
```

Or to `~/.config/opencode/skills/` for every project:

```bash
mkdir -p ~/.config/opencode/skills
cp -R integrations/opencode/skills/. ~/.config/opencode/skills/
```

Confirm the server with `opencode mcp list`.

## Versions

The skill tracks the gem version. The changelog is the repository
changelog. See the section that matches the version:

https://github.com/TonyCTHsu/simple-english/blob/master/CHANGELOG.md
