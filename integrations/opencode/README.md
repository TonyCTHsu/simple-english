# simple-english for opencode

An opencode integration that lints the prose the agent writes.

## What it does

opencode has no Agent Plugins support, so this is not a plugin
bundle. The integration wires the two parts opencode does support. The
`simple-english` MCP server runs `se mcp` from the gem. The
`simple-english-lint` skill tells the agent to call the `lint` tool
and fix every finding.

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
    "simple-english": {
      "type": "local",
      "command": ["se", "mcp"]
    }
  }
}
```

Copy the skill to `.opencode/skills/` in the project, or to
`~/.config/opencode/skills/` for every project:

```bash
mkdir -p ~/.config/opencode/skills
cp -R integrations/opencode/skills/simple-english-lint ~/.config/opencode/skills/
```

Confirm the server with `opencode mcp list`.

## Versions

The skill tracks the gem version. The changelog is the repository
changelog. See the section that matches the version:

https://github.com/TonyCTHsu/simple-english/blob/master/CHANGELOG.md
