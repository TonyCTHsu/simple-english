#!/bin/bash
# Boot the daemon the way launchd does: no LANG, no LC_ALL, nothing
# inherited. The daemon must boot anyway. This is the exact 0.4.0
# crash; run it here so it can never come back unnoticed.

set -u

env -i PATH="$PATH" HOME="$HOME" se serve --port 8281 &
daemon=$!
for _ in $(seq 1 60); do
  if curl -fsS http://localhost:8281/ >/dev/null 2>&1; then
    echo "the daemon answers under an empty environment"
    kill "$daemon" 2>/dev/null || true
    wait "$daemon" 2>/dev/null || true
    exit 0
  fi
  sleep 1
done
echo "the daemon never answered under an empty environment" >&2
kill "$daemon" 2>/dev/null || true
wait "$daemon" 2>/dev/null || true
exit 1
