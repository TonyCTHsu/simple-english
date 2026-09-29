# The daemon

The daemon speaks plain HTTP, so any tool or language can lint
through it: editors, pipelines, agents.

## Start

The first lint starts the daemon automatically (about 15 seconds
once, then you need Java and one run of `se setup`). Later lints hit
the running daemon and take milliseconds. To start it ahead of time:

```bash
se serve --port 8181 &
```

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

`gem_digest` covers the gem code and the built-in rules.
`rules_digest` covers the staged rule set with any custom rule
files. The CLI compares both at every lint.

A `gem_digest` mismatch means the daemon runs different code than
the caller. The CLI restarts it when it runs this gem's build or
older code. It warns instead when the daemon is newer or behind
`SE_SERVER_URL`.

A `rules_digest` mismatch means the daemon staged different rules
than the caller's config, so the CLI warns and `se serve` reloads.

## No Java? Run the daemon in a container

You need no Java and no Ruby on your machine. Pull the image and run
the daemon in it:

```bash
docker run -d --name se-daemon -p 8181:8181 \
  ghcr.io/tonycthsu/simple-english:v$(se version) serve
```

Then point the CLI at it:

```bash
SE_SERVER_URL=http://localhost:8181 se lint README.md
```

The CLI sends text over HTTP, so it needs no Java and never starts a
daemon of its own. The tag is `v` plus `se version`, so the image
carries the same rules as your gem. If port 8181 is busy on
your machine, map another port on both sides, for example
`-p 8281:8181` and `SE_SERVER_URL=http://localhost:8281`.

## Lifecycle

- Stop it with Ctrl-C or `kill` (TERM). If the inner server dies on
  its own, the daemon exits with code 2.
- The first lint after a gem update restarts an outdated daemon
  (about 15 s).
- `se serve` stops a running se daemon of its own, then boots in its
  place. A service that does not answer the se handshake keeps the
  `port is already in use` error.
- A custom `SE_SERVER_URL` is never auto-started: if it does not
  answer, the CLI exits 2.
