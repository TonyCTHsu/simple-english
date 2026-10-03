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
- A pull request that touches `.github/workflows/` follows the action
  pinning rules in `.github/AGENTS.md`.
- Changelog: run `changie new` and commit the fragment under `.changes/unreleased/`
  only when the tool's behavior changes. Documentation-only changes get no entry.
  Pull requests add fragments, not changelog lines, so they never conflict.
  The kinds are Breaking, Added, Changed, and Fixed. Only Breaking maps to
  a major bump in `changie next auto`. Breaking means the change breaks
  the CLI, the config, or an output format.
  Write the body as one line, per the rules in `.changes/AGENTS.md`.
  Preview the entry with `changie batch <kind> --dry-run` before the
  pull request. `rake lint` lints the fragment bodies.

## Layout

- `lib/simple_english.rb` is the composition root: `lint_text`,
  `lint_file`. `test/corpus_check.rb` runs the corpus pairs
- `lib/simple_english/version.rb` holds the gem version, and a version bump
  is the only change that belongs in it. `cli.rb` is the Thor CLI
- `lib/simple_english/model_context_protocol.rb` is the MCP stdio front
  door (`SimpleEnglish::ModelContextProtocol`). It is a client of the
  daemon, not a part of it
- The tree groups files by domain: `setup/`, `lint/`, `client/`,
  `daemon/`. `setup/` resolves the environment once, at the process
  edge. `daemon/` is the server tier: its failures raise typed errors
  (`PortInUse`, `InnerDied`, `InnerTimeout`)
- One object definition per file. Internals are `private_class_method`

## Constraints

- Runtime dependencies stay minimal. The gemspec adds
  `tree_sitter_language_pack` for comment extraction and Markdown
  structure, and `thor` for the CLI. Any further runtime dependency
  needs a stated reason here first. (Thor was a user-directed
  refactor, 2026-02-27.)
- Dev and test tools are the exception. Pick the best tool for the
  job. Every dev-only dependency states its reason beside its gemspec
  line. Keep them out of the gemspec runtime list.
- `Markdown.strip` must keep the line count identical to the source. Findings cite
  original line numbers, so stripping changes must preserve them.
- Ruby 3.3 minimum. CI enforces it. The
  gemspec declares no floor.

## Changes

Default to no comment. A comment earns its place only when it says
what the code cannot. It explains why: a non-obvious tradeoff, a
workaround for an upstream bug, a perf choice that looks wrong. It
warns of a real hazard: ordering, concurrency, a caller invariant.
It cites an external source. Never narration of the nearby code,
restatement of a good name, or notes about the change itself.
Prefer a clearer name or a test over a comment.

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

`.simple-english.yml` in the CWD. Keys: `ignore:` (path globs. `**` crosses directories and `*` does not) and `disabled-rules:` (rule IDs dropped from every file).

## Tests

- `rake test`: unit tests only, no LanguageTool needed
- `rake lint`: self-lint the repo's own prose, then the changie
  fragment bodies
- `ruby test/examples_check.rb` and `ruby test/corpus_check.rb`: need
  LanguageTool (run `bin/se setup` first)
- The corpus has that one CI home. standardrb stays out of the
  bundle. Reason: rubocop pins `json ~> 2.3`, and Ruby 4.0's default
  json gem is 3.x. Bundling it breaks `bundle exec` on 4.0

See `docs/DEVELOPMENT.md` for the full test strategy.
