# simple_english

Lint Markdown prose with the SimpleEnglish Plain-mode rules. Pattern rules run
on LanguageTool (`rules/simple-english.xml`). Counting rules run in Ruby.

## Docs

- `README.md` is the user guide (lint prose). `docs/DAEMON.md` holds
  the daemon HTTP API
- `docs/RULES.md` lists every rule in prose. Regenerate it with
  `bin/render-rules` after a rule change.
- `docs/DEVELOPMENT.md` is the dev guide (layout, tests, rules, container).
  `docs/RELEASING.md` holds the release flow (prepare, merge, publish)

## Branches

- Never commit on the default branch. Prefix branch names with your
  own handle to show ownership. Release prep uses `release/vX.Y.Z`.

## GitHub

- Follow the repo's templates. Issues go through the forms in
  `.github/ISSUE_TEMPLATE/`. Pull requests use
  `.github/pull_request_template.md`. Fill their sections as written.
  Do not bypass a template by passing `--body` to `gh`.
- `CONTRIBUTING.md` holds the process: false findings get an issue
  first, not a direct fix. Pull requests are drafts.
- Changelog: run `changie new` and commit the fragment under `.changes/unreleased/`
  only when the tool's behavior changes. Documentation-only changes get no entry.
  The kinds are Breaking, Added, Changed, and Fixed. Only Breaking maps to
  a major bump in `changie next auto`. Breaking means the change breaks
  the CLI, the config, or an output format.

## Layout

- `lib/simple_english.rb` is the composition root: `lint_text`,
  `lint_file`. `test/corpus_check.rb` runs the corpus pairs
- `lib/simple_english/version.rb` holds the gem version, and a version bump
  is the only change that belongs in it. `cli.rb` is the Thor CLI
- The tree groups files by domain: `setup/`, `lint/`, `client/`,
  `daemon/`
- `setup/` resolves the environment once, at the process edge. It
  holds `languagetool.rb` (pinned-distro facts), `install.rb`
  (cache dir, jar paths, java), `config.rb`, and `fingerprint.rb`
- `lint/` is the pipeline domain: `lint_plan.rb`, `markdown.rb`,
  `extractor.rb`, `annotated_text.rb`, `counts.rb`, `suppressions.rb`
- `client/` is the client tier. `language_tool.rb` speaks the
  LanguageTool wire protocol, used by the daemon's engine.
  `daemon.rb` probes, trusts, and boots the daemon
- `daemon/` holds the server tier: `engine.rb` (lint pipeline),
  `http.rb` (wire framing), `server.rb` (lifecycle). Server failures
  raise typed errors (`PortInUse`, `InnerDied`, `InnerTimeout`)
- One object definition per file: value objects live in their own files
  in `lint/` (`finding.rb`, `paragraph.rb`, `span.rb`, `segment.rb`,
  `result.rb`, `plain_text.rb`)
- Internals are `private_class_method`

## Constraints

- Runtime dependencies stay minimal. The gemspec adds
  `tree_sitter_language_pack` for comment extraction and Markdown
  structure, and `thor` for the CLI. Any further runtime dependency
  needs a stated reason here first. (Thor was a
  user-directed refactor, 2026-02-27.) `rubyzip` unpacks the
  LanguageTool download. It replaces the curl and unzip system
  dependencies (2026-09-28). `rexml` merges user rule files into
  the staged set at daemon boot. It stopped shipping as a Ruby
  default gem in 4.x (2026-09-30).
- Dev and test tools are the exception. Pick the best tool for the
  job even when it adds a dev-only dependency. Record it here with a
  one-line reason. Keep such tools out of the gemspec runtime list.
  Current tools, each with its reason: `minitest` for tests. The
  bundled gem alone is not enough, because `bundle exec` cannot
  require a bundled gem that the lockfile omits. `minitest-mock`
  restores `Object#stub` after minitest 6 dropped it. `rake` runs them.
  Both are dev-only, in the gemspec. `changie` (a brew binary, not
  a gem) batches change fragments into `CHANGELOG.md` at release
  time (2026-09-29). Pull requests add fragments, not changelog
  lines, so they never conflict.
- `Markdown.strip` must keep the line count identical to the source. Findings cite
  original line numbers, so stripping changes must preserve them.
- Ruby 3.3 minimum. CI enforces it. The
  gemspec declares no floor.

## Adding a rule

1. Pattern rule: add to `rules/simple-english.xml` with incorrect and correct
   examples
2. Counting rule: `lib/simple_english/lint/counts.rb`
3. Add a corpus pair `test/corpus/NN-before.md` / `NN-after.md`. The before file
   must trigger the rule. The after file must stay clean.

## Suppressions

A line containing `se: ignore` suppresses findings reported on that line;
`se: ignore=RULE1,RULE2` scopes it to rules. Pattern findings cite the line
of the match (not the paragraph or comment start), so put the directive on the
line the finding reports. Counting findings cite the paragraph's first line.

## Config

`.simple-english.yml` in the CWD. Keys: `ignore:` (path globs. `**` crosses directories and `*` does not) and `disabled-rules:` (rule IDs dropped from every file). `rules:` names LanguageTool XML rule files, merged into the built-in set. The daemon reads them at start, from its start CWD.

## Tests

- `rake check`: unit tests, rule examples, corpus, self-lint. CI adds
  `standardrb`, `actionlint`, `hadolint`, and an `e2e` job on top of
  it. The e2e job installs the built gem, runs `se setup`, and lints
  files outside the repo. standardrb stays out of the bundle. Reason:
  rubocop pins `json ~> 2.3`,
  and Ruby 4.0's default json gem is 3.x. Bundling it breaks
  `bundle exec` on 4.0
- `rake test`: unit tests only, no LanguageTool needed
- `ruby test/examples_check.rb` and `ruby test/corpus_check.rb`: need
  LanguageTool (run `bin/se setup` first)

See `docs/DEVELOPMENT.md` for the full test strategy.
