# Workflow edits

Pin every action to the commit SHA of its latest release. Comment
the release next to the pin: `uses: owner/action@<sha> # vX.Y.Z`.
Resolve the latest with `gh api repos/OWNER/ACTION/releases/latest`.
A moving major tag (`v2`) names only the newest release inside
that major. It can sit behind the true latest. A bump that crosses
a major needs a diff of the action's inputs first.
