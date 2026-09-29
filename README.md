[![CI](https://github.com/TonyCTHsu/simple-english/actions/workflows/ci.yml/badge.svg)](https://github.com/TonyCTHsu/simple-english/actions/workflows/ci.yml) <!-- se: ignore=SE_PARAGRAPH_TOO_LONG -->
[![Gem Version](https://badge.fury.io/rb/simple_english.svg)](https://badge.fury.io/rb/simple_english)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://github.com/TonyCTHsu/simple-english/blob/master/LICENSE)

# simple_english

> Write for human readers, not for reviewers or another AI.

AI writes your docs and code comments in seconds. This linter cuts
the slop it leaves behind. Every finding says what to write
instead.

```console
$ printf 'You should leverage this tool in order to make sure that your docs are readable.' > note.md
$ se note.md
note.md:1:5-11: [SE_MODAL_RESTRICTED] "should" - Use can, will, or must. State the requirement exactly.
note.md:1:31-42: [SE_SLOP_IN_ORDER_TO] "in order to" - Write "to".
note.md:1:12-20: [SE_SLOP_LEVERAGE] "leverage" - Write "use".
```

Markdown prose plus code comments in Python, Ruby, JavaScript,
TypeScript, Go, Rust, Java, C#, Kotlin, bash, and YAML. Output as plain
text, JSON, or SARIF.

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

**Requirements:** Ruby 3.3 or newer, Java 11 or newer for
LanguageTool. The Docker image bundles both.

### Ruby gem

```bash
gem install simple_english
se setup    # run once: downloads LanguageTool, locates Java, verifies both
se README.md
```

`se setup` puts LanguageTool into `~/.cache/se` and touches nothing
in your shell profile. Pass `--dir PATH` or set `SE_CACHE_DIR` to
put the cache somewhere else. If `java` is not on PATH, set `SE_JAVA`
to your java binary.

### Container

The image holds Ruby, Java, and LanguageTool, so it needs no setup:

```bash
docker run -v "$PWD":/work ghcr.io/tonycthsu/simple-english:latest docs/
```

Or keep the daemon in a container and lint through it:

```bash
docker run -d --name se-daemon -p 8181:8181 ghcr.io/tonycthsu/simple-english:latest serve
SE_SERVER_URL=http://localhost:8181 se lint docs/
```

### Git repository

Run `bundle install`, then use `bin/se`.

## Usage

Lint files, directories, or stdin. From a checkout, the same commands
run through `bin/se`:

```bash
se README.md
se docs/            # every .md, .py, .rb, .yaml, .yml, ... under docs/
se - < notes.md     # stdin (Markdown)
```

Lint only what changed:

```bash
git diff --name-only --diff-filter=ACM main | xargs se
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
- `2`: setup error

### CI

Gate the docs in the pull request that changes them. The plain run
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
      - run: se setup
      - run: se --format sarif . > lint.sarif
      - run: se .
      - uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: lint.sarif
        if: always()
```

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

## The daemon

The first lint starts the daemon automatically (about 15 seconds
once, then you need Java and one run of `se setup`). Later lints hit
the running daemon and take milliseconds. To start it ahead of time:

```bash
se serve --port 8181 &
```

Any tool or language can lint through its HTTP API:

```bash
curl -d "text=Don't do this." http://localhost:8181/lint
# [{"line":1,"column":3,"end_line":1,"end_column":6,"rule":"SE_NO_CONTRACTIONS","message":"..."}]
```

The full wire format: [docs/DAEMON.md](docs/DAEMON.md).

## Scope

The rule set comes from the Plain-mode rules of the MIT-licensed
SimpleEnglish project. This tool does not check ASD-STE100 compliance.
This repo holds no ASD-STE100 text. If you need full compliance, read
the free standard at <https://www.asd-ste100.org/>.

## Develop

To change the linter, add rules, or run the tests, read [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md).
