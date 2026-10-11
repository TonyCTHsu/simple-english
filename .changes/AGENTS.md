# Changelog fragment bodies

A fragment body is one line. `changeFormat` prefixes `- ` once, so a
multi-line body falls out of the list.

The body writes for a user scanning the changelog for whether the
upgrade affects them.

- Open with an imperative verb: "Skip ...", not "Directory expansion
  skips ..."
- Lead with the user-visible effect, not the mechanism.
- Install steps live in the adapter READMEs, not in the body.
- Use code spans for identifiers: commands, package and skill names.
  Agent names are identifiers in their directory spelling: `claude-code`,
  `codex`, `cursor`, `opencode`, `pi`. Always span them, always lowercase.
- An article and a code span mark the same thing: a specific noun.
  Keep one. Drop the article before a spanned name; keep it on plain
  prose nouns ("Bundle the lint engine").
- No implementation jargon, no internal file names.
- End with a period.
- A Fix names the symptom and its condition, then the corrected
  behavior.
- An Add names the capability and its access point.
- A Change names the new behavior and its escape hatch.
- Ground every claim in the diff and its tests.
