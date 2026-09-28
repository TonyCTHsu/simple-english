# simple_english

Lint Markdown prose with the SimpleEnglish Plain-mode rules. Pattern rules run
on LanguageTool (`rules/simple-english.xml`). Counting rules run in Ruby.

## Docs

- `README.md` is the user guide (lint prose). `docs/DAEMON.md` holds
  the daemon HTTP API
- `docs/RULES.md` lists every rule in prose. Regenerate it with
  `bin/render-rules` after a rule change.
- `docs/DEVELOPMENT.md` is the dev guide (layout, tests, rules, container)

## Layout

- `lib/simple_english.rb` is the composition root: `lint_text`, `corpus_test`
- `lib/simple_english/markdown.rb`, `counts.rb`, `languagetool.rb`, `extractor.rb`,
  `annotated_text.rb`, `suppressions.rb`, `config.rb`, `client.rb`, `cli.rb` are
  separate modules with small public interfaces
- One object definition per file: value objects live in their own files
  (`finding.rb`, `paragraph.rb`, `span.rb`, `segment.rb`, `result.rb`,
  `plain_text.rb`, `install.rb`)
- `lib/simple_english/languagetool.rb` holds the pinned-distro facts (version,
  rules file, download). `install.rb` resolves the on-machine installation
  (cache dir, jar paths, java) once, from the environment, at the process edge
- `lib/simple_english/engine.rb` (lint pipeline), `http.rb` (wire framing), and
  `server.rb` (daemon lifecycle) hold the daemon side. Server failures raise
  typed errors (`PortInUse`, `InnerDied`, `InnerTimeout`). `cli.rb` turns them
  into warnings and exit codes
- Internals are `private_class_method`

## Constraints

- Runtime dependencies stay minimal. The gemspec adds
  `tree_sitter_language_pack` for comment extraction and Markdown
  structure, and `thor` for the CLI. Any further runtime dependency
  needs a stated reason here first. (Thor was a
  user-directed refactor, 2026-02-27.) `rubyzip` unpacks the
  LanguageTool download. It replaces the curl and unzip system
  dependencies (2026-09-28).
- Dev and test tools are the exception. Pick the best tool for the
  job even when it adds a dev-only dependency. Record it here with a
  one-line reason. Keep such tools out of the gemspec runtime list.
  Current tools, each with its reason: `minitest` for tests. The
  bundled gem alone is not enough, because `bundle exec` cannot
  require a bundled gem that the lockfile omits. `rake` runs them.
  Both are dev-only, in the gemspec.
- `Markdown.strip` must keep the line count identical to the source. Findings cite
  original line numbers, so stripping changes must preserve them.
- Ruby 3.3 minimum. CI enforces it. The
  gemspec declares no floor.

## Adding a rule

1. Pattern rule: add to `rules/simple-english.xml` with incorrect and correct
   examples
2. Counting rule: `lib/simple_english/counts.rb`
3. Add a corpus pair `test/corpus/NN-before.md` / `NN-after.md`. The before file
   must trigger the rule. The after file must stay clean.

## Suppressions

A line containing `se: ignore` suppresses findings reported on that line;
`se: ignore=RULE1,RULE2` scopes it to rules. Pattern findings cite the line
of the match (not the paragraph or comment start), so put the directive on the
line the finding reports. Counting findings cite the paragraph's first line.

## Config

`.simple-english.yml` in the CWD. Keys: `ignore:` (path globs. `**` crosses directories and `*` does not) and `disabled-rules:` (rule IDs dropped from every file).

## Tests

- `rake check`: unit tests, rule examples, corpus, self-lint. CI adds
  `standardrb`, `actionlint`, and `hadolint` steps on top of it.
  standardrb stays out of the bundle. Reason: rubocop pins `json ~> 2.3`,
  and Ruby 4.0's default json gem is 3.x. Bundling it breaks
  `bundle exec` on 4.0
- `rake test`: unit tests only, no LanguageTool needed
- `ruby test/examples_check.rb` and `ruby test/corpus_check.rb`: need
  LanguageTool (run `bin/se setup` first)

See `docs/DEVELOPMENT.md` for the full test strategy.
