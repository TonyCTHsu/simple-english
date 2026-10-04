---
name: lint
description: Lint prose with simple_english after writing or editing documentation,
  READMEs, or code comments. Use when the agent writes prose, when asked to lint
  or simplify text, or when a doc change lands.
---

Lint prose the linter can see. Call the lint tool after writing or
editing any documentation file or prose-heavy text. Read the findings.
Fix every finding. Re-run until the result is clean.

The tool names differ by agent:

- pi exposes the tool `se_lint`.
- MCP clients expose the tool `lint`.

Fixing the findings is part of writing the prose. A draft with findings
is not done.
