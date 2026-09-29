# Releasing

Releasing needs the `gh` command line, signed in to the
repository. A local prepare also needs the `changie` binary:

```bash
brew install changie
```

1. Prepare:

   ```bash
   gh workflow run release-prep.yml --ref master
   gh run watch
   ```

   Override the computed version with `-f version=1.0.0`. Or run
   locally on a clean tree:

   ```bash
   rake release:prepare
   ```

2. Merge, after CI passes:

   ```bash
   gh pr ready release/v0.1.1
   gh pr merge release/v0.1.1 --merge
   ```

3. Publish:

   ```bash
   gh workflow run release.yml --ref master
   ```

Every behavior change needs a changie fragment (`changie new`)
before it merges. Documentation-only changes need no fragment.

Version numbers follow semantic versioning. A `Fixed` entry bumps
the patch. An `Added` or `Changed` entry bumps the minor. A change
that breaks the CLI, the config, or an output format bumps the
major.

Do not push tags by hand. The workflow tags the release commit.

The version lives in `lib/simple_english/version.rb`, and a version
bump is the only change that belongs in it.
