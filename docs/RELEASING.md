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
installs, and exercises each platform gem before publication. Each native
executable also has a SHA-256 checksum and signed build-provenance attestation
on the GitHub release.
The container image uses the Linux x86-64 gem.

Release also publishes `integrations/pi` to npm as `pi-simple-english`. A
version that is already on the registry is skipped, so a re-run of the
workflow stays green. The publish uses npm trusted publishing, with no
npm token. Register the trusted publisher on the npm side before the
first release: the repository, and the workflow file `release.yml`.
