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
- `2`: setup error

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

## The background daemon

The CLI runs a small background server on your machine. The first
lint starts it, which takes about 15 seconds. Later lints take
milliseconds.

The first lint after a gem update prints a warning. Run `se serve`
then. It stops the old daemon and reloads it. You never talk to the daemon directly. Its HTTP
interface is internal and can change in any release.

## Scope

The rule set comes from the Plain-mode rules of the MIT-licensed
SimpleEnglish project. This tool does not check ASD-STE100 compliance.
This repo holds no ASD-STE100 text. If you need full compliance, read
the free standard at <https://www.asd-ste100.org/>.

## FAQ

### Have you thought about an agent skill?

The [SimpleEnglish project](https://github.com/AminBlg/SimpleEnglish)
ships one. Its skill guides an agent while it writes. This tool does
the other half of the work. It checks the result against fixed
rules. Use both: the skill helps the first draft, and the linter
catches what the agent missed.

### Why not Vale?

We ported all 67 rules to Vale and ran the corpus on both engines.
About 60 rules behave the same. Vale has no check for the em-dash
and semicolon rules: its checks see words, not punctuation. Its
tagger also mislabels verbs, so the condition-first rule stays
silent. The rules here are LanguageTool XML with examples that CI
verifies. Closing the Vale gaps needs scripts or an external
tagger, and that erases Vale's main advantage: one binary with no
service behind it.

## Develop

To change the linter, add rules, or run the tests, read [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md).
