# Releasing

Releasing needs the `gh` command line, signed in to the
repository.

1. Prepare:

   ```bash
   gh workflow run release-prep.yml --ref master
   gh run watch
   ```

2. Approve:

   ```bash
   gh pr review "$(gh pr list --label release --state open --json headRefName --jq '.[0].headRefName')" --approve
   ```

   If auto-merge is off, merge by hand with the same selector and `--merge`:

   ```bash
   gh pr merge "$(gh pr list --label release --state open --json headRefName --jq '.[0].headRefName')" --merge
   ```

3. Publish:

   Wait for CI on master to finish before publishing.

   ```bash
   gh workflow run release.yml --ref master
   ```

Do not push tags by hand. The workflow tags the release commit.
