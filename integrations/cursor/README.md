# simple-english for `cursor`

A `cursor` plugin that lints the prose the agent writes.

## What it does

The plugin is an Agent Plugin. It bundles two things. The root
`mcp.json` adds the `simple-english` MCP server, which runs `se mcp`
from the gem. The `lint-simple-english` skill tells the agent to call
the `lint` tool and fix every finding. The `write-simple-english`
skill carries the rules themselves, so the agent writes clean prose
the first time.

## Prerequisites

The linter is a Ruby gem. Install it once, before the adapter:

```bash
gem install simple_english
```

## Install

Until the plugin reaches the `cursor` Marketplace, install it from a
local folder:

```bash
mkdir -p ~/.cursor/plugins/local
cp -R integrations/cursor ~/.cursor/plugins/local/simple-english
```

Then reload the window (`Developer: Reload Window`) and open
`Customize` to confirm the plugin loaded.

## Versions

The plugin version tracks the gem version. The changelog is the
repository changelog. See the section that matches the version:

https://github.com/TonyCTHsu/simple-english/blob/master/CHANGELOG.md
