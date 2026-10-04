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
rake lint                   # self-lint the repo's own prose
rake test                   # unit tests only, no LanguageTool needed
ruby test/examples_check.rb   # every rule against its own examples
ruby test/corpus_check.rb   # corpus pairs
```

The last two need LanguageTool (run `bin/se setup` first, it
downloads to `~/.cache/se`). If `java` is not on PATH, set
`SE_JAVA`. The unit tests need the bundle's gems but no JVM.

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

## Agent integrations

`integrations/` holds one adapter per agent: `pi/` (a native
extension), `claude-code/` (a hook plugin), and `codex/` (an MCP
plugin). `integrations/shared/skills/lint/SKILL.md` holds the skill all
three share. `integrations/verification.md` records the agent facts
the adapters rely on. `.claude-plugin/marketplace.json` at the repo
root lists the Claude Code plugin. The adapters ship nothing. Try them
from local paths:

- pi: `pi install <repo>/integrations/pi -l`
- Claude Code: `claude --plugin-dir <repo>/integrations/claude-code`
- Codex: a local marketplace, per `integrations/verification.md`

`se mcp` runs the MCP server behind the Codex plugin. Any MCP client
can use it.

Testing has two layers. Layer 1 runs in the unit suite
(`mcp_*_test.rb`, `integrations_*_test.rb`): fixtures replay each
adapter's wire input, and no tokens are spent. Layer 2 is
`bin/e2e-agents`: a live agent per adapter answers a seeded question
in note.md. The gate: the whole file ends clean, the answer was
appended, and violations the agent was never asked to fix are gone.
The `e2e-agents.yml` workflow runs it on demand, with credentials.

Each run writes its result, model, usage, and leftover findings to
the Actions run summary page, one table per agent in one process.
`SE_E2E_SKIP=1 bin/e2e-agents` prints
the scenarios.

### What the codex failures taught

The codex scenario went red five times before it went green. Three
bugs stacked, and each hid the next. The codex facts live in
`integrations/verification.md`. The process lessons live here.

1. A green run proves the whole set of changes. It does not prove
   each change is needed. Before you remove a fix, rerun without it
   and nothing else. One run failed because a fix was removed on
   reasoning that the passing run cannot support.
2. A config that fails no validation check is not proven unread.
   The audit confused "not validated" with "not read", and dropped
   a config the run needed.
3. Test a stdio server with the client's stdin still open. Closing
   stdin flushes Ruby's output buffer and hides buffering bugs. The
   server passed every closed-stdin test, then sat silent for a
   real client. The regression test keeps stdin open on purpose.
4. Read the wire, not the outcome. A fake provider captures the
   request. A logging proxy sits between client and server. Both
   answered what hours of result logs left open.
5. Make failures narrate themselves. The `RUST_LOG` lines printed
   into the job log named the failing mechanism. The agent's own
   words named the missing tool. Neither needed a local
   reproduction.


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
