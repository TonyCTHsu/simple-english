# Developing simple_english

If you want to change the linter, add rules, or run the tests, start
here. If you only want to lint prose, read the [README](../README.md).

## Layout

- `lib/simple_english.rb` is the composition root: `lint_text` and `lint_file`
- `lint/` holds text analysis, suppression handling, and value objects
- `setup/languagetool.rb` holds pinned engine facts and the rules path
- `setup/install.rb` resolves the native executable once at the process edge.
  `SE_LANGUAGETOOL_EXECUTABLE` overrides the bundled path for source builds
  and tests
- `client/language_tool.rb` speaks the inner HTTP protocol.
  `client/daemon.rb` probes and starts the public daemon
- `daemon/engine.rb` holds the lint pipeline, `daemon/http.rb` holds HTTP
  framing, and `daemon/server.rb` owns process lifecycle. Server failures
  raise typed errors (`PortInUse`, `InnerDied`, `InnerTimeout`)
- `setup/config.rb` handles `.simple-english.yml`
- `cli.rb` maps results and failures to output and exit codes

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
rake lint                   # self-lint the repo's own prose
rake test                   # unit tests only, no LanguageTool needed
ruby test/examples_check.rb   # every rule against its own examples
ruby test/corpus_check.rb   # corpus pairs
```

The last two need the native LanguageTool server. Build it with
`ruby native/languagetool/build.rb`, then set
`SE_LANGUAGETOOL_EXECUTABLE=tmp/native-languagetool/languagetool-native`.
The unit tests do not need the native server.

The self-lint lints through a daemon on port 8181. On macOS, a
brew-installed se can run as a brew service. Its `KeepAlive` restarts
it whenever it dies, and a respawn stops any daemon holding the port
and takes it. While that service runs, `bin/se serve --detached`
cannot hold the port, and every checkout lint warns about stale
code. Stop the service once per machine:

```
brew services stop simple-english
```

Then `bin/se serve --detached` starts the checkout daemon, and the
warning stops.

## Test strategy

Five tiers. Most tests do not start the native LanguageTool server.
Only boundary tests exercise the real executable.

1. **Unit tests** (`test/simple_english/*_test.rb`, minitest): one class
   per file. `StubHTTPServer` in `test_helper.rb` fakes the LanguageTool
   and daemon endpoints. It reuses the daemon's own HTTP framing. So
   client, engine, and CLI tests run without a daemon.
2. **Process tests**: daemon lifecycle with the native server faked.
   A `sleep` script stands in for the
   inner-death path. A dying script stands in for fast-fail. Real
   `TCPServer`s test the port guards.
3. **Corpus pairs** (`test/corpus/NN-before.md` / `NN-after.md`): each
   rule triggers on its before file. It stays silent on its after file.
   The after file is the document-level false-positive guard.
4. **LanguageTool boundary**: with a built native executable,
   `examples_check.rb` proves each XML rule fires on its incorrect
   example. It proves the rule stays silent on its correct example.
   `roundtrip_test.rb` and the daemon end-to-end test check offset
   mapping and the full serve → lint path with a real daemon.
5. **CI user story** (`bin/e2e-story`): CI builds and installs the
   platform gem, then runs this script without an executable override.
   It lints
   every corpus pair outside the repo, so the corpus has one CI
   home. It asserts exit codes: findings on each before file, clean
   on each after file. It also lints a code comment through the
   comment pipeline. The first lint boots the daemon.

Priority order: line and column fidelity first, then failure paths
(every `exit 2` has a test), then rule correctness. Unit tests run
without starting the native server.

## Adding a rule

1. Pattern rule: add to `rules/simple-english.xml` with incorrect and
   correct examples.
2. Counting rule: `lib/simple_english/lint/counts.rb`.
3. Add a corpus pair `test/corpus/NN-before.md` / `NN-after.md`. The
   before file must trigger the rule. The after file must stay clean.
4. Verify with `ruby test/examples_check.rb` (per-rule isolation), then
   `ruby test/corpus_check.rb` (rule interaction), then lint a real document
   by eye.

## Releasing

Releasing is a command-line flow with `gh`. It folds the changie
fragments into a release, merges the version bump, and publishes
the gem and the image. See `docs/RELEASING.md`.
