# pi-simple-english

Lint prose and code comments with `simple_english`, from inside pi.

The package adds two things to pi:

- the `se_lint` tool, which lints a file or a directory
- the `simple-english-lint` skill, which tells the agent to lint the
  prose it writes and fix every finding

## Install

The linter is a Ruby gem. Install the gem, run `se setup`, then
install the package:

```bash
gem install simple_english
se setup
pi install npm:pi-simple-english
```

## Versions

The package version tracks the gem version. The changelog is the
repository changelog. See the section that matches the version:

https://github.com/TonyCTHsu/simple-english/blob/master/CHANGELOG.md
