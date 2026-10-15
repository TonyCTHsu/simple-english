# simple-english for `vscode-copilot`

A `vscode-copilot` integration that lints the prose the agent writes.

## What it does

VS Code Copilot has no plugin format for third parties, so this is not
a plugin bundle. The integration wires the two parts agent mode does
support. The `simple-english` MCP server runs `se mcp` from the gem.
The `lint-simple-english` skill tells the agent to call the `lint`
tool and fix every finding. The `write-simple-english` skill carries
the rules themselves, so the agent writes clean prose the first time.

## Prerequisites

The linter is a Ruby gem. Install it once, before the integration:

```bash
gem install simple_english
```

## Install

Add the MCP server to `.mcp.json` in the project root. If the
project has no `.mcp.json`, create one with this content:

```json
{
  "mcpServers": {
    "simple-english": {
      "type": "stdio",
      "command": "se",
      "args": ["mcp"]
    }
  }
}
```

A project that already has a `.mcp.json` merges the
`simple-english` entry into the existing `mcpServers` block. The
`.vscode/mcp.json` variant also works: its top-level key is
`servers`, not `mcpServers`.

Copy both skills to `.github/skills/` in the project:

```bash
mkdir -p .github/skills
cp -R integrations/vscode-copilot/skills/lint-simple-english integrations/vscode-copilot/skills/write-simple-english .github/skills/
```

Reload the window (`Developer: Reload Window`). VS Code asks to
approve workspace MCP servers. Approve it, then confirm the server in
the Tools picker, or with `MCP: List Servers` from the Command
Palette.

## Versions

The skill tracks the gem version. The changelog is the repository
changelog. See the section that matches the version:

https://github.com/TonyCTHsu/simple-english/blob/master/CHANGELOG.md
