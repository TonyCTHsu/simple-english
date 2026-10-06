# Releasing

Releasing needs the `gh` command line, signed in to the
repository.

1. Prepare:

   ```bash
   gh workflow run release-prep.yml --ref master
   gh run watch
   ```

2. Review, approve, and merge:

   ```bash
   release_pr="$(gh pr list --label release --state open --json headRefName --jq '.[0].headRefName')"
   gh pr review "$release_pr" --approve
   gh pr merge "$release_pr" --merge
   ```

   The pull request runs no CI. GitHub does not start workflows for
   a pull request opened with `GITHUB_TOKEN`. Your merge starts the
   CI run on master. The prep workflow validates the changelog.

3. Publish:

   Wait for CI on master to finish before publishing.

   ```bash
   gh workflow run release.yml --ref master
   ```

Do not push tags by hand. The workflow tags the release commit. It builds
and verifies native servers on Ubuntu 22.04 x86-64, Ubuntu 22.04
arm64, and macOS arm64. It builds,
installs, and exercises each platform gem before publication.

Each gem carries the native server and its SBOM, and the release holds
a copy of each published gem. Verify a downloaded gem with
`gh attestation verify`.
The container image uses the Linux platform gems, one per
cpu architecture.

If one platform fails, re-run the failed jobs from the release run. The
workflow checks RubyGems first. A published platform keeps its gem copy
from the attempt that pushed it, and the re-run leaves it alone.
