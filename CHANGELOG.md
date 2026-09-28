# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-09-28

### Added

- `se lint` command: lints Markdown prose and code comments against the
  SimpleEnglish Plain-mode rules
- Plain-mode pattern rules in `rules/simple-english.xml`: voice, tense,
  modals, punctuation, contractions, sentence shape, and about 50 word
  substitution rules
- Counting rules for Markdown: 20 words per sentence in list items, 25 in
  paragraphs, six sentences per paragraph
- `se serve` daemon with an HTTP lint API
- `se setup` command: installs the pinned LanguageTool distro
- Config file `.simple-english.yml` and inline `se: ignore` suppressions
- Text, JSON, and SARIF output formats
- Container image

[Unreleased]: https://github.com/TonyCTHsu/simple-english/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/TonyCTHsu/simple-english/releases/tag/v0.1.0
