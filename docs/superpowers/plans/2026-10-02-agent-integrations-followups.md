# Agent integrations follow-ups

Deferred items from the review of the integrations branch. Each names
its trigger and its fix. Fix an item when its trigger arrives.

1. Dash-prefixed Markdown names, like `-note.md`, skip the hook's lint
   silently. Trigger: a user or agent edits such a file. Fix: prefix
   `./` onto `-*` paths in `integrations/claude-code/hooks/lint.sh`.
   The repo's path expansion strips `./` back off, so findings stay
   identical.
2. The `skills` symlink dangles if a marketplace install copies the
   plugin dir alone. Trigger: the release decision, or one real
   `claude plugin marketplace add` install. Fix: run that install and
   watch the skill. If it dangles, copy the skill into each plugin dir
   and drop the symlink.
3. Agent e2e retries stack: the script retry plus the workflow attempt
   give up to four paid runs per agent. Trigger: the first dispatch
   with real credentials, at the latest. Fix: drop one retry layer,
   either the workflow attempt or the script's `with_retry`.
4. The hook test's `stub_se` breaks on apostrophes in a fixture
   message. Trigger: a future fixture with a quote, like `Don't do
   this.`. Fix: write the canned body to a file and let the stub `cat`
   it.

## Open questions

1. Pin the agent e2e to each provider's cheapest model. Today the
   runs use each CLI's default model, which is the most expensive
   path. Candidates, checked 2026-10-02: `claude-haiku-4-5` for
   Claude Code, `gpt-6-luna` for Codex, `gemini-3.1-flash-lite` for
   pi on Google. Verify the Codex candidate inside `codex exec`
   before trusting it.
