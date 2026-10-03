# Changelog fragment bodies

A fragment body is one line. `changeFormat` prefixes `- ` once, so a
multi-line body falls out of the list.

The body writes for a user scanning the changelog for whether the
upgrade affects them.

- Open with an imperative verb: "Skip ...", not "Directory expansion
  skips ..."
- Lead with the user-visible effect, not the mechanism.
- Use code spans for what the user runs or names.
- No implementation jargon, no internal file names.
- End with a period.
- A Fix names the symptom and its condition, then the corrected
  behavior.
- An Add names the capability and its access point.
- A Change names the new behavior and its escape hatch.
- Ground every claim in the diff and its tests.
