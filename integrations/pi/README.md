# simple-english for pi

A pi package that lints the prose the agent writes.

The package ships the `simple-english-lint` skill and the `se_lint`
tool. The tool lints a file or a directory. The skill tells the agent
to lint the prose it writes and fix every finding.

## Prerequisites

The linter is a Ruby gem. Install it once, before the adapter:

```bash
gem install simple_english
```

## Install

For yourself, on every project:

```bash
pi install npm:pi-simple-english
```

For one project, with the team, install into the project instead. Run
the install with `-l` from the project root:

```bash
pi install npm:pi-simple-english -l
```

The project install writes `.pi/settings.json`, which you commit. Pi
loads it only after you grant project trust.

## Versions

The package version tracks the gem version. The changelog is the
repository changelog. See the section that matches the version:

https://github.com/TonyCTHsu/simple-english/blob/master/CHANGELOG.md
