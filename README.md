[![CI](https://github.com/TonyCTHsu/simple-english/actions/workflows/ci.yml/badge.svg)](https://github.com/TonyCTHsu/simple-english/actions/workflows/ci.yml) <!-- se: ignore=SE_PARAGRAPH_TOO_LONG -->
[![Gem Version](https://badge.fury.io/rb/simple_english.svg)](https://badge.fury.io/rb/simple_english)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://github.com/TonyCTHsu/simple-english/blob/master/LICENSE)

# simple_english

> Write for human readers, not for reviewers or another AI.

AI writes your docs and code comments in seconds. This linter cuts
the slop it leaves behind. Every finding says what to write
instead.

```console
$ printf "Your API keys are rotated by the service every 90 days — you will need to update them if you get a 401; don't panic, simply re-run the setup command, which regenerates the credentials without any downtime." > note.md
$ se note.md
note.md:1:15-29: [SE_ACTIVE_VOICE] "are rotated by" - Use the active voice. Say who does the action.
note.md:1:67-89: [SE_CONDITION_FIRST] "need to update them if" - Put the condition first: “If the build fails, read the log.”
note.md:1:107-110: [SE_NO_CONTRACTIONS] "n't" - Write the words in full. No contractions.
note.md:1:56-57: [SE_NO_EMDASH] "—" - Write two sentences, or use a comma.
note.md:1:103-104: [SE_NO_SEMICOLON] ";" - Write two sentences, or name the relation.
note.md:1: [SE_SENTENCE_TOO_LONG] Sentence has more than 25 words. Split it.
note.md:1:118-124: [SE_SLOP_DELETE_ADVERBS] "simply" - Delete it. It carries no fact.
```

Markdown prose plus code comments in Python, Ruby, JavaScript,
TypeScript, Go, Rust, Java, C#, C++, Kotlin, bash, and YAML. Output as
plain text, JSON, or SARIF.

## Agent integrations

The linter runs as an MCP server: `se mcp`. It exposes one tool,
`lint`. Any MCP client can call it.

Before and after, where every fix answers one finding:

| Before | After |
|---|---|
| Your API keys are rotated by the service every 90 days — you will need to update them if you get a 401; don't panic, simply re-run the setup command, which regenerates the credentials without any downtime. <!-- se: ignore --> | The service rotates your API keys every 90 days. If you get a 401, update them. Do not panic. Re-run the setup command. It regenerates the credentials without any downtime. |

Agents that write the prose get the rules closer to hand. One skill,
`simple-english-lint`, ships inside every adapter. It tells the agent
to lint what it writes and fix every finding.

The adapters:

| Adapter | Install command |
|---|---|
| [pi](integrations/pi/README.md) | `pi install npm:pi-simple-english` |
| [Claude Code](integrations/claude-code/README.md) | `claude plugin marketplace add TonyCTHsu/simple-english` |
| [Codex](integrations/codex/README.md) | `codex plugin marketplace add TonyCTHsu/simple-english` |

Each adapter has its own README with scopes and prerequisites. See
[docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) for the full story.

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

The full list, with a wrong and a right example for each rule:
[docs/RULES.md](docs/RULES.md).

## Install

**Requirement:** Ruby 3.3 or newer on macOS 12 or newer (arm64), or Linux
x86-64 or Linux arm64 with glibc 2.35 or newer.

### Homebrew (macOS)

```bash
brew install TonyCTHsu/tap/simple-english
brew services start simple-english
```

Homebrew installs the CLI as one gem, with the lint engine inside
it. The service keeps a background daemon running. Run
`brew services stop simple-english` to stop it.

### Ruby gem (supported platforms and CI)

```bash
gem install simple_english
se README.md
```

### Docker (no Ruby needed)

```bash
docker run --rm -v "$PWD":/work ghcr.io/tonycthsu/simple-english:latest .
```

The image holds the CLI and the lint engine. It lints the mounted
directory, then exits. Pin the tag to a version for CI, like
`ghcr.io/tonycthsu/simple-english:v0.5.0`. The image ships for Linux
x86-64 and Linux arm64. On an Apple Silicon Mac, Docker runs the arm64
image. There is no install for Windows or Intel Macs on any channel.

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

### CI

Gate the prose in the pull request that changes it. The plain run
fails the build on findings, and the SARIF report puts them inline:

```yaml
name: lint-docs
on: [pull_request]
permissions:
  security-events: write
jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - uses: ruby/setup-ruby@v1
      - run: gem install simple_english
      - run: se --format sarif . > lint.sarif
      - run: se .
      - uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: lint.sarif
        if: always()
```

### The daemon

The first lint starts a background daemon. Later lints use it. A
lint after a gem update prints a warning. Run `se serve --detached`
once. It stops the old daemon and starts the new one.

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

### Have you thought about an agent skill?

Every adapter in [Agent integrations](#agent-integrations) bundles
one: the `simple-english-lint` skill rides with the linter, so an
agent drafts and lints with the same rules. The
[SimpleEnglish project](https://github.com/AminBlg/SimpleEnglish)
ships a standalone skill for hosts without an adapter. If you like,
use both: the skill helps the first draft, and the linter catches
what the agent missed.

### Why not Vale?

We ported all 67 rules to Vale and ran the corpus on both engines.
About 60 rules behave the same. Vale has no check for the em-dash
and semicolon rules: its checks see words, not punctuation. Its
tagger also mislabels verbs, so the condition-first rule stays
silent. The rules here include examples that CI verifies. Closing
the Vale gaps needs scripts or an external
tagger, and that erases Vale's main advantage: one binary with no
service behind it.

## Scope

The rule set comes from the Plain-mode rules of the MIT-licensed
SimpleEnglish project. This tool does not check ASD-STE100 compliance.
This repo holds no ASD-STE100 text. If you need full compliance, read
the free standard at <https://www.asd-ste100.org/>.

## Develop

To change the linter, add rules, or run the tests, read [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md).
