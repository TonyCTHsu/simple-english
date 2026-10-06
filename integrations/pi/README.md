# pi-simple-english

Lint prose and code comments with `simple_english`, from inside pi.

The package adds two things to pi:

- the `se_lint` tool, which lints a file or a directory
- the `simple-english-lint` skill, which tells the agent to lint the
  prose it writes and fix every finding

## Install

The linter is a Ruby gem. Install the gem, then install the package.
For yourself, on every project:

```bash
gem install simple_english
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
