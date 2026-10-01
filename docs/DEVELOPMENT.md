# Developing simple_english

If you want to change the linter, add rules, or run the tests, start
here. If you only want to lint prose, read the [README](../README.md).

## Layout

The tree mirrors the architecture: one directory per domain, the
client/daemon seam visible in `client/` and `daemon/`.

- `lib/simple_english.rb` is the composition root: `lint_text`,
  `lint_file`. `test/corpus_check.rb` runs the corpus pairs
- `lib/simple_english/setup/` resolves the environment, once, at
  the process edge. `languagetool.rb` holds the pinned-distro
  facts: version, rules file, download. `install.rb` resolves the
  on-machine installation (cache dir, jar paths, java). Build it
  with `Install.from_env`. Tests construct installs directly, so no
  test mutates ENV. `config.rb` reads `.simple-english.yml`, and
  `fingerprint.rb` computes the identity digests for the handshake
- `lib/simple_english/lint/` is the pipeline domain. `lint_plan.rb`
  picks prose, code, or skip. `markdown.rb` strips Markdown.
  `extractor.rb` and `annotated_text.rb` extract code comments and
  map offsets back. `counts.rb` holds the counting rules, and
  `suppressions.rb` applies `se: ignore`
- Value objects live one per file: `finding.rb`, `paragraph.rb`,
  `span.rb`, `segment.rb`, `result.rb`, `plain_text.rb`
- `lib/simple_english/client/` is the client tier. `language_tool.rb`
  speaks the LanguageTool wire protocol. The daemon's engine calls
  it against the inner JVM. `daemon.rb` is the se daemon client:
  probe, handshake, boot, lint
- `lib/simple_english/daemon/` is the server tier. `engine.rb` runs
  the daemon-side lint pipeline (Markdown and code-comment paths).
  `http.rb` holds the HTTP/1.1 wire framing. `server.rb` holds the
  lifecycle: staging, port guards, spawn/monitor, signals, cleanup.
  Failures raise typed errors (`PortInUse`, `InnerDied`,
  `InnerTimeout`). `cli.rb` at the top maps them to warnings and
  exit codes

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
rake check                  # self-lint, unit tests, rule examples
rake test                   # unit tests only, no LanguageTool needed
ruby test/examples_check.rb   # every rule against its own examples
ruby test/corpus_check.rb   # corpus pairs
```

The last two need LanguageTool (run `bin/se setup` first, it
downloads to `~/.cache/se`). If `java` is not on PATH, set
`SE_JAVA`. The unit tests need the bundle's gems but no JVM.

## Test strategy

Five tiers. The theme: keep the JVM (LanguageTool) out of every test
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
5. **CI user story** (`bin/e2e-story`): CI's `e2e` job builds and
   installs the gem, runs `se setup`, then runs this script. It lints
   every corpus pair outside the repo, so the corpus has one CI
   home. It asserts exit codes: findings on each before file, clean
   on each after file. It also lints a code comment through the
   comment pipeline. The first lint boots the daemon.

Priority order: line and column fidelity first, then failure paths
(every `exit 2` has a test), then rule correctness. Last: a JVM-free
unit suite that runs in one second.

## Adding a rule

1. Pattern rule: add to `rules/simple-english.xml` with incorrect and
   correct examples.
2. Counting rule: `lib/simple_english/lint/counts.rb`.
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

Releasing is a command-line flow with `gh`. It folds the changie
fragments into a release, merges the version bump, and publishes
the gem and the image. See `docs/RELEASING.md`.
