# The daemon (internal)

This document describes the daemon for maintainers. The HTTP
surface is internal. It can change in any release. Do not build
tools against it. `se serve` and the CLI are the supported ways to
reach the daemon.

## Why a daemon

Starting the lint engine takes time, so the CLI keeps a daemon running
between lints. The first lint starts it automatically. Later lints
reuse it.

## Start

The first lint starts the daemon automatically. Later lints use the
running daemon. To start it ahead of time:

```bash
se serve --detached
```

## The HTTP wire (internal)

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

`gem_digest` covers the gem code and the built-in rules. The CLI
compares it at every lint.

A `gem_digest` mismatch means the daemon runs different code than
the caller. The CLI never replaces a running daemon: `se serve`
owns that. It warns at every lint until the daemon is replaced,
and lints against the old code meanwhile. The warning names
`se serve --detached`. When the daemon is newer than the CLI, the warning
says `Update this gem` instead: `se serve` from an older CLI
boots an older daemon in its place.

`rules_digest` covers the built-in rules. A mismatch now only means a
different gem version, which the `gem_digest` mismatch already reports.
The field stays in the handshake for older clients.

The daemon is machine-global: one per port, shared by every
project. Every project lints with the same built-in rules.

## Lifecycle

- Stop it with Ctrl-C or `kill` (TERM). If the inner server dies on
  its own, the daemon exits with code 2.
- A lint starts the daemon when the port is cold. A lint never
  replaces a running daemon:
  `se serve` does that.
- `se serve` stops a running se daemon of its own, then boots in its
  place. A service that does not answer the se handshake keeps the
  `port is already in use` error.
- `se serve --detached` does the same replacement, then leaves the
  daemon in the background and returns the terminal. The daemon
  outlives the session, like the auto-started one.
- A custom `SE_SERVER_URL` is never auto-started: if it does not
  answer, the CLI exits 2.
