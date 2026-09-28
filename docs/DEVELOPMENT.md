# Developing simple_english

If you want to change the linter, add rules, or run the tests, start
here. If you only want to lint prose, read the [README](../README.md).

## Layout

- `lib/simple_english.rb` is the composition root: `lint_text`, `lint_file`, `corpus_test`
- `lib/simple_english/markdown.rb`, `counts.rb`, `languagetool.rb`, `extractor.rb`,
  and `annotated_text.rb` do text analysis: Markdown strip, sentence counts,
  process helpers, comment extraction, offset mapping
- Value objects live one per file: `finding.rb`, `paragraph.rb`, `span.rb`,
  `segment.rb`, `result.rb`, `plain_text.rb`
- `lib/simple_english/languagetool.rb` holds the pinned-distro facts:
  version, rules file, download
- `lib/simple_english/install.rb` resolves the on-machine installation
  (cache dir, jar paths, java) once, from the environment, at the process
  edge. Build it with `Install.from_env` in the composition root. Tests
  construct installs directly, so no test mutates ENV
- `lib/simple_english/engine.rb` holds the daemon-side lint pipeline (Markdown
  and code-comment paths)
- `lib/simple_english/http.rb` holds the daemon's HTTP/1.1 wire framing
- `lib/simple_english/server.rb` holds the daemon lifecycle: staging, port
  guards, spawn/monitor, signals, cleanup. Failures raise typed errors
  (`PortInUse`, `InnerDied`, `InnerTimeout`). `cli.rb` maps them to
  warnings and exit codes
- `lib/simple_english/client.rb`, `config.rb`, and `suppressions.rb` hold the
  daemon client, `.simple-english.yml`, and `se: ignore` directives

All modules keep internals `private_class_method`.

## Constraints

- Runtime dependencies stay minimal. The gemspec adds
  `tree_sitter_language_pack` and `thor`. Any further runtime
  dependency needs a stated reason in `AGENTS.md`
  first.
- Dev and test tools may deviate. Pick the best tool for the job,
  record the reason in `AGENTS.md`, and keep it out of the runtime
  gemspec. Current tools, each with its reason: `minitest` for
  tests. The bundled gem alone is not enough, because `bundle exec`
  cannot require a bundled gem that the lockfile omits. `rake` runs
  them. Both are dev-only, in the gemspec.
- `Markdown.strip` must keep the line count identical to the source.
  Findings cite original line numbers, so stripping changes must preserve
  them.
- Ruby 3.3 minimum. CI enforces it.

## Running the tests

```
rake check                  # everything CI runs: standardrb, tests,
                            # examples, corpus, self-lint
rake test                   # unit tests only, no LanguageTool needed
ruby test/examples_check.rb   # every rule against its own examples
ruby test/corpus_check.rb   # corpus pairs
```

The last two need LanguageTool (run `bin/se setup` first, it
downloads to `~/.cache/se`). If `java` is not on PATH, set
`SE_JAVA`. The unit tests need the bundle's gems but no JVM.

## Test strategy

Four tiers. The theme: keep the JVM (LanguageTool) out of every test
except the tests whose job is the JVM boundary.

1. **Unit tests** (`test/simple_english/*_test.rb`, minitest): one class
   per file. `StubHTTPServer` in `test_helper.rb` fakes the LanguageTool
   and daemon endpoints. It reuses the daemon's own HTTP framing. So
   client, engine, and CLI tests run without a daemon.
2. **Process tests** (`server_staging_test.rb` and friends): daemon
   lifecycle with the JVM faked. A `sleep` script stands in for the
   inner-death path. A dying script stands in for fast-fail. Real
   `TCPServer`s test the port guards.
3. **Corpus pairs** (`test/corpus/NN-before.md` / `NN-after.md`): each
   rule triggers on its before file. It stays silent on its after file.
   The after file is the document-level false-positive guard.
4. **LanguageTool boundary** (env-gated, skips locally):
   `examples_check.rb` proves each XML rule fires on its incorrect
   example. It proves the rule stays silent on its correct example.
   `roundtrip_test.rb` and the daemon end-to-end test check offset
   mapping and the full serve → lint path with a real daemon.

Priority order: line and column fidelity first, then failure paths
(every `exit 2` has a test), then rule correctness. Last: a JVM-free
unit suite that runs in one second.

## Adding a rule

1. Pattern rule: add to `rules/simple-english.xml` with incorrect and
   correct examples.
2. Counting rule: `lib/simple_english/counts.rb`.
3. Add a corpus pair `test/corpus/NN-before.md` / `NN-after.md`. The
   before file must trigger the rule. The after file must stay clean.
4. Verify with `ruby test/examples_check.rb` (per-rule isolation), then
   `ruby test/corpus_check.rb` (rule interaction), then lint a real document
   by eye.

## Developing in a container

You need podman or Docker. The image holds Ruby, Java, LanguageTool, and
the jar path, so no local setup is needed.

```
podman build -t se-dev .
podman run --rm --entrypoint ruby -v "$PWD":/work -w /work se-dev test/run.rb
podman run --rm -v "$PWD":/work -w /work se-dev README.md
```

The image runs `se` as its entrypoint. Pass `--entrypoint` to run
something else, like the test suite above. Pass
file arguments as relative paths. Then the findings print paths that
match your checkout.

## Releasing

Releasing is one command, one merge, one click.

1. Run `rake 'release:prepare[0.1.1]'` on a clean tree. The task
   sets the gem version and moves the `Unreleased` changelog entries
   under a dated `## [0.1.1]` heading. It leaves a fresh empty
   `Unreleased` above.
2. Commit the diff, open a pull request, and merge it. CI runs first.
3. Open the `Release` workflow on GitHub and run it on `master`.

The release workflow starts only by hand, from the "Run workflow"
button. It reads the gem version and checks the changelog holds a
section for it, then runs three jobs in order:

- `release`: tag the release commit and create the GitHub release
  from the changelog body. One step does both, and it skips what
  already exists.
- `gem`: publish the gem to RubyGems through the trusted publisher
  (no API key is stored)
- `image`: build `ghcr.io/tonycthsu/simple-english` from the
  published gem, tagged `v0.1.1` and `latest`

Every user-visible change needs one line under `Unreleased` in
`CHANGELOG.md` before it merges. Docs-only changes need no entry.
The release workflow fails if the changelog section for the tagged
version is missing, so a release cannot ship without notes.

Version numbers follow semantic versioning. A `Fixed` entry bumps
the patch. An `Added` or `Changed` entry bumps the minor. A change
that breaks the CLI, the config, or an output format bumps the
major.

Do not push tags by hand. The workflow tags the release commit, so
a hand-pushed tag can drift from the gem version.

The version lives in `lib/simple_english/version.rb`, and a version
bump is the only change that belongs in it.
