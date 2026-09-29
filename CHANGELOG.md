# Changelog

## [0.3.0] - 2026-09-29

### Added

- Comment linting supports C++ files (`.cpp`, `.cc`, `.cxx`, `.hpp`, `.h`)

### Added

- BYOR (bring your own rules): a `rules:` key in `.simple-english.yml`
  names extra LanguageTool rule files. They merge into the built-in set

### Changed

- Pattern findings print exact ranges in text, JSON, and SARIF output

### Fixed

- `SE_ING_AFTER_COMMA` no longer flags `-ing` nouns in enumerations, like "(accounts, VPC, secrets, troubleshooting)"

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

