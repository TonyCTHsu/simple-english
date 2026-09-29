# Releasing

Releasing needs the `gh` command line, signed in to the
repository.

1. Prepare:

   ```bash
   gh workflow run release-prep.yml --ref master
   gh run watch
   ```

2. Approve. The pull request merges itself once CI passes:

   ```bash
   gh pr review release/vX.Y.Z --approve
   gh pr checks release/vX.Y.Z --watch
   ```

   If auto-merge is off, merge by hand with
   `gh pr merge release/vX.Y.Z --merge`.

3. Publish:

   ```bash
   gh workflow run release.yml --ref master
   ```

Do not push tags by hand. The workflow tags the release commit.
