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

## No Java? Run the daemon in a container

You need no Java and no Ruby on your machine. Pull the image and run
the daemon in it:

```bash
docker run -d --name se-daemon -p 8181:8181 ghcr.io/tonycthsu/simple-english:latest serve
```

Then point the CLI at it:

```bash
SE_SERVER_URL=http://localhost:8181 se lint README.md
```

The CLI sends text over HTTP, so it needs no Java and never starts a
daemon of its own. Pin the image tag to your gem version, because
different versions carry different rules. If port 8181 is busy on
your machine, map another port on both sides, for example
`-p 8281:8181` and `SE_SERVER_URL=http://localhost:8281`.

## Lifecycle

- Stop it with Ctrl-C or `kill` (TERM). If the inner server dies on
  its own, the daemon exits with code 2.
- A custom `SE_SERVER_URL` is never auto-started: if it does not
  answer, the CLI exits 2.
