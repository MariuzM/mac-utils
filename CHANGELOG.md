# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.0] - 2026-07-13

### Added

- Rekey section: remap keyboard keys (e.g. F-keys to brightness, volume, mute, playback) via
  macOS's native `hidutil`, with an optional startup daemon that re-applies mappings at every
  boot. Merged from the standalone macos-rekey app.

### Changed

- Top tab bar replaced with a left sidebar, with a smoothly animated show/hide toggle (⌃⌘S).
- Bundle identifier renamed from `dev.marius.macosutility` to `mariuzm.macosutility` —
  re-grant Full Disk Access after updating.
- The Rekey startup daemon installs as `mariuzm.rekey.plist`.
- `build.sh` replaced by a Makefile (`make dev`, `make build`, `make r`, `make clean`,
  `make status`, `make reset`); release bundles now build into `build/` instead of `dist/`.

## [0.2.0] - 2026-07-04

### Added

- Per-drive search for `node_modules` folders, grouped into a separate category for each location
  (the folder that contains the projects).

## [0.1.0] - 2026-07-04

Initial release.

### Added

- Parallel scan of all mounted volumes for removable files — caches, logs, trash, developer junk,
  and temporary files — grouped by drive → category → item with size, path, and a safety badge.
- Results split into **User Files** and **System Files**, with a checkbox per category and
  check-all / uncheck-all controls; Delete and Back Up act on the checked selection.
- Back up to `~/Desktop/macOS Utility Backup <timestamp>/`, preserving each item's original path.
- Delete via Move to Trash or permanent delete, with root-owned items removed using an admin
  password and simulator runtimes handled via `simctl`.
- Console with live output, working Cancel, and a watchdog for long operations.
- Spotlight Privacy tab.

[0.2.0]: https://github.com/MariuzM/macos-utility/releases/tag/v0.2.0
[0.1.0]: https://github.com/MariuzM/macos-utility/releases/tag/v0.1.0
