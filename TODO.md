# Deferred work

One agreed task, not yet started. It ships as its own commit on
its own branch, with its own changie fragment.

## 1. Remove BYOR (bring your own rules)

The `rules:` key in `.simple-english.yml` names extra LanguageTool
XML files. The daemon merges them into the staged rule set with
REXML (`daemon/server.rb`). Remove the feature.

- The gemspec loses the rexml dependency, its only use.
- `stage_rules` drops the merge and stages the built-in file alone.
- A config with a `rules:` key must warn that the key is ignored.
  A silent drop lints with the wrong rules and no signal.
- This breaks the config, so the changie fragment is Breaking.
- Update README, DAEMON.md, and AGENTS.md, which document the key.
- Estimate: a day, tests included.

## After it

The gem carries two runtime dependencies:
`tree_sitter_language_pack` and `thor`. The brew formula loses its
rexml resource.
