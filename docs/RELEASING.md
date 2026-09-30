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

Do not push tags by hand. The workflow tags the release commit.
