# Changelog

## [0.6.0] - 2026-10-06

### Added

- Add `pi-simple-english` pi package.
- Add Claude Code plugin.
- Add Codex plugin.

### Changed

- Bundle the lint engine in the gem on supported platforms, with the engine's SBOM beside the binary.
- Turn `se setup` into a no-op that prints a notice.
- Drop Java/Jar dependency, `SE_JAVA` and `SE_CACHE_DIR`.

## [0.5.0] - 2026-10-05

### Added

- Add `se mcp`, an MCP stdio server with one lint tool. It honors `.simple-english.yml` like the CLI.

### Changed

- Skip `.git`, `node_modules`, and `vendor` when you lint a directory. Files you name directly still lint.

### Fixed

- Fix `ignore:` entries not matching the absolute paths that agent hooks pass, so globs like `docs/**` hold for every surface.

## [0.4.2] - 2026-10-02

### Fixed

- Fix `se tree` exiting with a `TypeError`.
- Fix daemon restart advice pointing at the wrong `se` when the linting code and the PATH `se` are different installs. The warning now prints the full path of the executable that matches the running code.


## [0.4.1] - 2026-10-01

### Fixed

- Fix `brew services start simple-english` crashing: the daemon crashed at boot and launchd kept retrying it.

## [0.4.0] - 2026-10-01

### Added

- Daemon handshake: `GET /` on the daemon reports its version, pid, and digests.
- The first lint after a gem update warns about an outdated daemon. Run `se serve --detached` to restart it.
- `se version` prints its version.
- `se serve --detached` replaces a running daemon and runs the new one in the background.

### Changed

- `se serve` stops a running se daemon and takes over its port.
- `se setup` reports each check as it completes.
- `se setup` no longer takes `--dir`. Set `SE_CACHE_DIR` instead.

## [0.3.0] - 2026-09-29

### Added

- Comment linting supports C++ files (`.cpp`, `.cc`, `.cxx`, `.hpp`, `.h`)

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

