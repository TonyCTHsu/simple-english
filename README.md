[![CI](https://github.com/TonyCTHsu/simple-english/actions/workflows/ci.yml/badge.svg)](https://github.com/TonyCTHsu/simple-english/actions/workflows/ci.yml) <!-- se: ignore=SE_PARAGRAPH_TOO_LONG -->
[![Gem Version](https://badge.fury.io/rb/simple_english.svg)](https://badge.fury.io/rb/simple_english)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://github.com/TonyCTHsu/simple-english/blob/master/LICENSE)

# simple_english

> Write for human readers, not for reviewers or another AI.

AI writes your docs and code comments in seconds. This linter cuts
the slop it leaves behind. Every finding says what to write
instead.

```console
$ printf "The config was written by setup — don't edit it; the daemon caches rules, making the first lint slow." > note.md
$ se note.md
note.md:1:12-26: [SE_ACTIVE_VOICE] "was written by" - Use the active voice. Say who does the action.
note.md:1:73-81: [SE_ING_AFTER_COMMA] ", making" - Start a new sentence instead of the -ing phrase.
note.md:1:37-40: [SE_NO_CONTRACTIONS] "n't" - Write the words in full. No contractions.
note.md:1:33-34: [SE_NO_EMDASH] "—" - Write two sentences, or use a comma.
note.md:1:48-49: [SE_NO_SEMICOLON] ";" - Write two sentences, or name the relation.
```

Markdown prose plus code comments in Python, Ruby, JavaScript,
TypeScript, Go, Rust, Java, C#, C++, Kotlin, bash, and YAML. Output as
plain text, JSON, or SARIF.

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

## Agent integrations

The linter runs as an MCP server: `se mcp`. It exposes one tool,
`lint`. Any MCP client can call it.

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

## Install

**Requirement:** Ruby 3.3 or newer on macOS 12 or newer (arm64), or Linux
x86-64 or Linux arm64 with glibc 2.35 or newer.

### Homebrew (macOS)

```bash
brew install TonyCTHsu/tap/simple-english
brew services start simple-english
```

Homebrew installs Ruby and the lint engine alongside the CLI. The
service keeps a background daemon running. Run
`brew services stop simple-english` to stop it.

### Ruby gem (supported platforms and CI)

```bash
gem install simple_english
se README.md
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
