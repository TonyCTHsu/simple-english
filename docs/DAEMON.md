# The daemon (internal)

This document describes the daemon for maintainers. The HTTP
surface is internal. It can change in any release. Do not build
tools against it. `se serve` and the CLI are the supported ways to
reach the daemon.

## Why a daemon

LanguageTool is a JVM process. A cold start takes seconds, so the
CLI keeps a daemon running between lints. The first lint starts it
automatically. Later lints take milliseconds.

## Start

The first lint starts the daemon automatically (about 15 seconds
once, then you need Java and one run of `se setup`). Later lints hit
the running daemon and take milliseconds. To start it ahead of time,
or to replace one after a gem update:

```bash
se serve --detached
```

## The HTTP wire (internal)

## The HTTP API

POST to `/lint` with form fields:

- `text`: raw Markdown or source, required.
- `language`: optional, selects the code-comment pipeline.

The response is a JSON array of
`{line, column, end_line, end_column, rule, message}`. Positions are
1-based, columns count UTF-16 code units, and end positions are exclusive.
Counting findings have `null` columns and end positions because they apply to
a whole sentence or paragraph.

```bash
curl -d "text=Don't do this." http://localhost:8181/lint
# [{"line":1,"column":3,"end_line":1,"end_column":6,"rule":"SE_NO_CONTRACTIONS","message":"..."}]
curl -d "text=x = 1 # Don't do this." -d "language=python" http://localhost:8181/lint
# code-comment linting uses positions in the source file
```

GET / answers the handshake:

```json
{"version": "0.2.0", "pid": 123, "gem_digest": "…", "rules_digest": "…"}
```

`gem_digest` covers the gem code and the built-in rules. The CLI
compares it at every lint.

A `gem_digest` mismatch means the daemon runs different code than
the caller. The CLI never replaces a running daemon: `se serve`
owns that. It warns at every lint until the daemon is replaced,
and lints against the old code meanwhile. The warning names
`se serve --detached`. When the daemon is newer than the CLI, the warning
says `Update this gem` instead: `se serve` from an older CLI
boots an older daemon in its place.

`rules_digest` covers the staged rule set. Every daemon stages the
same built-in rules, so a mismatch now only means a different gem
version, which the `gem_digest` mismatch already reports. The field
stays in the handshake for older clients.

The daemon is machine-global: one per port, shared by every
project. Every project lints with the same built-in rules.

## No Java? Run the CLI in a container

The image holds Ruby, Java, and LanguageTool. Lint with it in one
shot when the machine has no Java:

```bash
docker run -v "$PWD":/work ghcr.io/tonycthsu/simple-english:latest docs/
```

The daemon also runs in a container, with `serve` as the image
entrypoint. A user who needs that knows why. The CLI reaches a
remote daemon through `SE_SERVER_URL`. Both stay undocumented on
purpose: the wire is internal, and a remote daemon is never
restarted for you.

## Lifecycle

- Stop it with Ctrl-C or `kill` (TERM). If the inner server dies on
  its own, the daemon exits with code 2.
- A lint starts the daemon when the port is cold (the first lint
  takes about 15 s). A lint never replaces a running daemon:
  `se serve` does that.
- `se serve` stops a running se daemon of its own, then boots in its
  place. A service that does not answer the se handshake keeps the
  `port is already in use` error.
- `se serve --detached` does the same replacement, then leaves the
  daemon in the background and returns the terminal. The daemon
  outlives the session, like the auto-started one.
- A custom `SE_SERVER_URL` is never auto-started: if it does not
  answer, the CLI exits 2.
