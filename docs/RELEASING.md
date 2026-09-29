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
   gh pr review release/vX.Y.Z --approve
   ```

   The pull request merges itself once approved. It runs no CI;
   the prep workflow validates the changelog. If auto-merge is off,
   merge by hand with `gh pr merge release/vX.Y.Z --merge`.

3. Publish:

   ```bash
   gh workflow run release.yml --ref master
   ```

Do not push tags by hand. The workflow tags the release commit.
