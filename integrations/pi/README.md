# simple-english for `pi`

Lint the prose your pi agent writes. The package wires the
simple_english rules into pi as one tool and two skills.

## Install

Install the adapter:

```bash
pi install npm:pi-simple-english
```

Install it for one project only by adding `-l` and running the
command from the project root.

The tool calls the `se` CLI. That CLI ships as a Ruby gem. Install
it once, before the first lint:

```bash
gem install simple_english
```

## What you get

The `se_lint` tool lints a file or a directory. It returns each
finding with a line number, a rule ID, and a fix hint:

```
README.md:12:31-32: [SE_NO_SEMICOLON] ";" - Write two sentences, or name the relation.
```

The `write-simple-english` skill carries the rules, so the agent
writes clean prose the first time. The `lint-simple-english` skill
tells the agent to lint the prose it writes and fix every finding.

## Versions

The package version tracks the gem version. The changelog lives in
the repository:

https://github.com/TonyCTHsu/simple-english/blob/master/CHANGELOG.md
