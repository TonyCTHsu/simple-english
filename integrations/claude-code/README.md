# simple-english for Claude Code

A Claude Code plugin that lints the prose Claude writes.

## What it does

A PostToolUse hook runs after every file write or edit. It lints the
edited file with `se lint` and feeds the findings back to Claude, so
Claude fixes them in its next turn. The plugin also ships the
`simple-english-lint` skill and a `/lint` command.

## Install

The linter is a Ruby gem. Install the gem, then install the plugin:

```bash
gem install simple_english
claude plugin marketplace add TonyCTHsu/simple-english
```

Then, inside Claude Code:

```
/plugin install simple-english@simple-english
```

You can also try the plugin from a checkout of this repository:

```bash
claude --plugin-dir integrations/claude-code
```

## Versions

The plugin version tracks the gem version. The changelog is the
repository changelog. See the section that matches the version:

https://github.com/TonyCTHsu/simple-english/blob/master/CHANGELOG.md
