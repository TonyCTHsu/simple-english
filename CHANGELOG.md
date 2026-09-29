# Changelog

## [Unreleased]

### Changed

- Pattern findings print exact ranges in text, JSON, and SARIF output

## [0.2.0] - 2026-09-29

### Changed

- Text findings print the column and name the offending text

### Fixed

- Sentence counts ignore internal periods, like those in URLs and
  file paths

## [0.1.0] - 2026-09-28

### Added

- `se lint`, `se serve`, `se setup` commands
- Pattern rules for prose and code comments
- Counting rules for Markdown
- `.simple-english.yml` config and `se: ignore` suppressions
- Text, JSON, and SARIF output
- Container image
