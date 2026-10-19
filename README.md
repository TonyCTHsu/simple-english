[![CI](https://github.com/TonyCTHsu/simple-english/actions/workflows/ci.yml/badge.svg)](https://github.com/TonyCTHsu/simple-english/actions/workflows/ci.yml) <!-- se: ignore=SE_PARAGRAPH_TOO_LONG -->
[![Gem Version](https://badge.fury.io/rb/simple_english.svg)](https://badge.fury.io/rb/simple_english)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://github.com/TonyCTHsu/simple-english/blob/master/LICENSE)

# simple_english

> Write plain English for humans. Keep the agent honest.

You can teach an agent plain-English prose with a skill or a
prompt. It writes clean prose in the first paragraph and slop again
by the third. This linter keeps the agent honest: it reads what the
agent wrote and names every broken rule. Send the findings back, and
the agent corrects its own text.

<table>
<tr>
<th width="50%">Before</th>
<th width="50%">After</th>
</tr>
<tr>
<td valign="top">

> Your API keys are rotated by the service every 90 days — you will need to update them if you get a 401; don't panic, simply re-run the setup command, which regenerates the credentials without any downtime. <!-- se: ignore -->

</td>
<td valign="top">

> The service rotates your API keys every 90 days. If you get a 401, update them. Do not panic. Re-run the setup command. It regenerates the credentials without any downtime.

</td>
</tr>
</table>

The linter covers Markdown prose plus code comments in Python, Ruby,
JavaScript, TypeScript, Go, Rust, Java, C, C++, and C#. It also
reads Objective-C, Kotlin, Swift, Scala, Dart, PHP, Perl, Elixir,
Lua, R, Haskell, Zig, SQL, and bash. It reads comments in config
formats and markup as well: YAML, TOML, INI, Makefile, Dockerfile,
HTML, and XML. Findings print as plain text, JSON, or SARIF.

If your language is not on the list, [open an issue](https://github.com/TonyCTHsu/simple-english/issues).

## Agent integrations

Plug the linter into your coding agent. It writes plain English on
the first pass and checks its own draft before you read the file.

| Coding agent | Ships as | Docs |
|---|---|---|
| `pi` | npm package `pi-simple-english` | [README](integrations/pi/README.md) |
| `claude-code` | plugin `simple-english` | [README](integrations/claude-code/README.md) |
| `codex` | plugin `simple-english` | [README](integrations/codex/README.md) |
| `cursor` | plugin folder `simple-english` | [README](integrations/cursor/README.md) |
| `opencode` | plugin `simple-english` | [README](integrations/opencode/README.md) |
| `vscode-copilot` | config wiring | [README](integrations/vscode-copilot/README.md) |

If your agent is not on the list, [open an issue](https://github.com/TonyCTHsu/simple-english/issues).

## The rules

- **Voice:** say who does the action.
- **Tense:** simple tenses only, no present perfect.
- **Modals:** `can`, `will`, `must` only.
- **Punctuation:** no em-dashes, no semicolons.
- **Contractions:** write every word in full.
- **Sentence shape:** condition before command, no `-ing` phrase after a comma.
- **Word choice:** about 50 substitution rules, from `leverage` to `in conclusion`. `make sure that` keeps its "that".
- **Code comments:** same pattern rules, with line and column range.
- **Counts (Markdown only):** 20 words per sentence in list items, 25 in paragraphs, six sentences per paragraph at most.

The full list, with a wrong and a right example for each rule [docs/RULES.md](docs/RULES.md).

## Install

### Ruby gem (macOS arm64, Linux x86-64 and arm64)

```bash
gem install simple_english
```

### Homebrew (macOS arm64)

```bash
brew install TonyCTHsu/tap/simple-english
```

### Container

```bash
docker run --rm -v "$PWD":/work ghcr.io/tonycthsu/simple-english .
```

## Usage

Lint files, directories, or stdin:

```bash
se README.md
se docs/            # every .md, .py, .rb, .yaml, .yml, ... under docs/
se - < notes.md     # stdin (Markdown)
```

Lint only what changed:

```bash
git diff --name-only --diff-filter=ACM main | xargs -I{} se {}
```

### Outputs

Pattern findings print an exclusive column range as
`file:line:start-end: [RULE_ID] message`. A range that crosses lines ends
with `end-line:end-column`. Columns count UTF-16 code units. Counting findings
identify only the paragraph's first line. JSON and SARIF output expose the same
source ranges:

```bash
se --format json docs/
se --format sarif src/ > results.sarif
```

### Exit codes

- `0`: no findings
- `1`: findings
- `2`: input, configuration, installation, or daemon error

### MCP server

Start an MCP stdio server with one tool, `lint`. Any MCP
client can call it.

```
se mcp
```

### CI

Gate the pull request's prose in GitHub Actions. The lint fails the build on findings:

```yaml
name: lint-docs
on: [pull_request]
jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - uses: TonyCTHsu/simple-english@v0.12.0
        with:
          files: |
            docs/
            README.md
```

To see the findings inline in the pull request, lint with
`format: sarif` and upload the report. Add
`permissions: {security-events: write}` to the workflow:

```yaml
      - uses: TonyCTHsu/simple-english@v0.12.0
        with:
          format: sarif
      - uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: simple-english.sarif
        if: always()
```

Any CI can run the lint. Install the gem, run `se lint .`, and fail the
build on exit code 1.

### Git hooks

Install the gem once, then wire your hook runner. The command to run
is `se lint`.

#### Pre-commit framework

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/TonyCTHsu/simple-english
    rev: v0.12.0
    hooks:
      - id: se-lint
```

For Husky with lint-staged, map every staged file to `se lint`. For
Lefthook, run `se lint {staged_files}` in a `pre-commit` command.

## Config and suppressions

### Config file

`.simple-english.yml` in the working directory:

```yaml
ignore:
  - vendor/**
disabled-rules:
  - SE_NO_EMDASH
```

`ignore` globs: `**` crosses directories, `*` stays in one segment.

### Inline suppressions

A line containing `se: ignore` suppresses findings reported on that
line. Use `se: ignore=RULE1,RULE2` to scope it to rules. Pattern
findings cite the line of the match, so put the directive on the line the
finding reports.

In Markdown:

```markdown
The daemon keeps it's own lock. <!-- se: ignore=SE_NO_CONTRACTIONS -->
```

In a code comment:

```ruby
# Don't touch this constant. se: ignore=SE_NO_CONTRACTIONS
```

## FAQ

### Why not Vale?

We ported rules to Vale and ran the corpus on both engines.
About 60 rules behave the same. Vale has no check for the em-dash
and semicolon rules: its checks see words, not punctuation. Its
tagger also mislabels verbs, so the condition-first rule stays
silent. Closing the Vale gaps needs scripts or an external
tagger, and that erases Vale's main advantage: one binary with no
service behind it.

## Compliance

This tool does not check ASD-STE100 compliance. This repo holds no
ASD-STE100 text. For full compliance, read the free standard at
<https://www.asd-ste100.org/>.

The tool checks no external style standard. The rules are this repo's
own, but they draw on the [GOV.UK A to Z style
guide](https://guidance.publishing.service.gov.uk/writing-to-gov-uk-standards/style-guides/a-to-z-style-guide/)
and the [US plain language
guide](https://digital.gov/guides/plain-language/).

The rule sources are `rules/simple-english.xml` for pattern rules and
`lib/simple_english/lint/counts.rb` for counting rules. The full list
sits in [docs/RULES.md](docs/RULES.md).

## Develop

To change the linter, add rules, or run the tests, read [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md).
