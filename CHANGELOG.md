# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.4.0] - 2026-07-18

### Added

- Dock Folders: clicking a checked folder in the Dock opens a custom browsable list instead of the
  macOS stack, so items inside can be right-clicked (Open in Terminal / Ghostty / VS Code, Reveal
  in Finder, Copy Path). Backed by a new background helper, `macOS Utility Helper`.
- Menu bar folder browser for pinned folders.
- Test suite (`make test`) covering path-safety rules, shell/AppleScript escaping, and saved-data
  migration.
- `make tcc` resets the app's and helper's Accessibility grants.

### Changed

- App and helper are now signed with a stable local certificate instead of ad-hoc, so Accessibility
  and Full Disk Access grants survive a rebuild. Set `SIGN_ID` to override; defaults to the local
  `macOS Utility Dev` identity.
- Version and build numbers are injected from the Makefile at build time rather than duplicated in
  the plists.
- The Rekey startup daemon is now `dev.marius.macosutility.rekey.plist`. Older `mariuzm.rekey` and
  `dev.marius.rekey` daemons are booted out and removed automatically on install, or via the
  "Remove" button in the Rekey pane.
- Saved key mappings persist by HID usage rather than by display name, so renaming a key label no
  longer orphans existing mappings.
- Code layout: helper-only and app-only code moved out of the shared `FolderKit` library, which now
  holds only genuinely shared configuration and storage.

### Fixed

- Cancelling the administrator password prompt was reported as "everything failed" — `osascript`
  writes its cancellation to stderr, which was never captured.
- The count of removed items was derived from shell exit codes that `rm -rf` does not set on
  failure; removal is now verified per path.
- Paths containing apostrophes were corrupted in the failure list.
- A corrupt pinned-folders file caused the defaults to immediately overwrite it, losing the user's
  folders. Missing and unreadable files are now distinguished.
- `hidutil` output larger than the pipe buffer could deadlock the app on the main thread.
- Cancelling a scan no longer repopulates the list seconds later; cancelling a delete no longer
  starts a new scan; a failed backup no longer opens Finder on an empty folder.
- Spotlight privacy reads no longer stage a script in a writable temp directory before running it
  as root.
- Relative or empty paths could resolve against the working directory and bypass the protected-root
  guard.
- Backup and delete failures now report the underlying reason instead of only a count.
- An unreadable folder in the popover showed "Empty folder" rather than a permissions message.
- The Dock panel's trust-polling timer could run for the process lifetime after overrides were
  removed; the event tap is now torn down on deallocation.

## [0.3.0] - 2026-07-13

### Added

- Rekey section: remap keyboard keys (e.g. F-keys to brightness, volume, mute, playback) via
  macOS's native `hidutil`, with an optional startup daemon that re-applies mappings at every
  boot. Merged from the standalone macos-rekey app.

### Changed

- Top tab bar replaced with a left sidebar, with a smoothly animated show/hide toggle (⌃⌘S).
- Bundle identifier renamed from `dev.marius.macosutility` to `mariuzm.macosutility` —
  re-grant Full Disk Access after updating. (Reverted to `dev.marius.macosutility` in 0.4.0.)
- The Rekey startup daemon installs as `mariuzm.rekey.plist`. (Renamed again in 0.4.0.)
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
