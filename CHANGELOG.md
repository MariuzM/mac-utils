# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.9.0] - 2026-10-10

### Added

- Desktop switching shortcuts on the Keyboard page.
- `Restart Dock` button for unresponsive desktop shortcuts.
- Launch Items page.
- Settings window with accent color.

### Changed

- Sidebar navigation and page layout.
- `bun run build` reveals the app in Finder.

## [0.8.0] - 2026-09-13

### Cleanup review

- Replace the system-database permission probe with qualified protected-user-location checks and exact-app guidance.
- Report skipped scan paths and omit incomplete folders from cleanup results.
- Preserve per-file removal errors and retry access-denied user-owned files with administrator authorization.
- Keep result dialogs actionable, with no automatic scan blocking retry.
- Add individual item selection, current-user-only external Trash, and review-only older temporary files.
- Add editor caches, npm logs, Maven/NuGet packages, and Hugging Face downloads with conservative selection defaults.

### Added

- Siri controls with a persisted restore snapshot, per-service verification, and an honest sign-out-required state for
  protected running services. Downloaded AI models are not removed.
- Overview page and a consistent light/dark design with grouped navigation and reusable cards.
- `package.json` commands for build, run, checks, formatting, and existing utility operations.

### Changed

- Target macOS 27 and Swift 6.4; reorganize app code into feature directories.
- Centralize process execution, cancellation, bounded output, timeouts, and binary reads.
- Use `SMAppService` for the embedded helper's login registration.
- Use atomic configuration writes and asynchronous keyboard operations.
- Build and verify signed bundles through `scripts/app.py`; take version metadata from package.json.

### Fixed

- Duplicate scan/selection sizes, incomplete package sizing, and late progress updates after cancellation.
- Path normalization and symlink protection in ordinary and administrator deletion.
- Process termination now rechecks identity, ownership, and protection; memory suggestions do not double-count
  overlapping processes.
- Unknown Spotlight output and uncertain leftover ownership no longer imply a successful empty result or confirmed
  orphan.

### Removed

- Makefile; use `bun run` or `npm run` scripts.
- Bulk simulator deletion and whole-tree system temporary-directory cleanup.

## [0.6.0] - 2026-07-27

### Added

- **Performance** tab: live process list sampled every 3 seconds with real instantaneous CPU (from `proc_pid_rusage`
  deltas, not the lifetime average `ps` reports), resident memory, and role (App / Menu bar / Background / Process).
  Search, sort by memory/CPU/name, and a "Background only" filter.
- **Reclaim now** suggestions above the list, each with the memory it frees and a Quit button:
  - _Idle vendor stack_ — two or more background processes from one vendor totalling ≥100 MB while none of that vendor's
    apps has a window open (e.g. the Adobe Creative Cloud services left running after Photoshop is closed).
  - _Duplicate instances_ — the same executable started more than once by launchd. Quits the newer copies and keeps the
    oldest.
- **Leftovers** tab: one scan across every place an uninstalled app can leave something behind — launch agents and
  daemons, privileged helper tools, preference panes, kernel extensions, audio and Quick Look plug-ins, input methods,
  screen savers, internet plug-ins, containers, group containers, Application Support, Preferences, saved state,
  cookies, WebKit data and caches. Results are grouped, sized, and removed to the Trash (or as administrator for
  root-owned paths).

  Findings carry one of two confidence levels, and the distinction is the point:

  - **Confirmed orphan** — a file that names a program which is not on disk. Checked, not guessed. Selected
    automatically.
  - **Review first** — matched by bundle identifier against installed apps. This is a heuristic: an app's product name
    and its bundle id often differ (Spark ships as `com.readdle.smartemail-Mac` but keeps a `com.readdle.Spark-Mac`
    group container), so these are listed with their evidence, warned when the vendor still has other apps installed,
    and **never selected automatically**. "Remove" only ever acts on what is actually checked.

  Bundle identifier resolution indexes apps recursively (so vendors that install into a folder, like Adobe, are found),
  harvests nested app extensions, XPC services and login items, strips Team ID and `group.` prefixes, and matches on a
  normalised vendor+product key so that suffixes like `-Mac` or `.ShipIt` don't read as separate products.

### Fixed

- The Dock Folders helper could run as two processes at once. `HelperControl.start()` registered a copy through
  LaunchServices while the installed LaunchAgent started its own, and the `isRunning` guard raced between them. The
  LaunchAgent is now the single owner — `start()` drives it with `launchctl kickstart`, installing the agent terminates
  any LaunchServices-owned copy first, and `terminateDuplicates()` reaps extras keeping the oldest. `make helper-start`
  kickstarts the agent instead of `open`ing a second copy.

### Security

- Removal in **Leftovers** is a two-step escalation instead of a single choice. "Move to Trash" handles everything it
  can; whatever is root-owned or refused by macOS is collected and offered as one "Authorize and Remove…" step that
  triggers the administrator password prompt. Both the confirmation and the summary state plainly that administrator
  removal deletes permanently and does **not** go to the Trash, because `AdminDeleter` uses `rm -rf` and the items
  cannot be put back.

### Removed

- The test suite and the `make test` target. `Tests/` and both `testTarget` entries in `Package.swift` are gone.

### Safety

- Process actions are refused for anything not owned by the current user, PID ≤ 1, this app itself, a denylist of
  critical names (WindowServer, Dock, Finder, loginwindow, launchd, coreaudiod, …), and anything under `/System`,
  `/usr/libexec`, `/usr/sbin`, `/usr/bin`, `/sbin`, or `/bin`. Those rows show a lock instead of a Quit menu.
- Suggestions never include `com.apple.*` processes, so Apple's own background services — such as the several
  `SimMetalHost` instances a running simulator legitimately spawns — are listed but never proposed for termination.

## [0.5.0] - 2026-07-22

### Added

- **Extensions** tab: choose which app opens each file extension, grouped by kind (Audio, Video, Images, Text &
  Documents, Development, Archives, Fonts, Other), with search and an "Other…" picker for unregistered apps. Defaults
  are set per file _type_, so `.jpg` and `.jpeg` change together.

### Changed

- Project renamed from **macOS Utility** to **Mac Utils** — repo (`MariuzM/mac-utils`), app bundle
  (`build/Mac Utils.app`), binary (`MacUtils`), bundle ids (`dev.marius.macutils`, `dev.marius.macutils.folderhelper`),
  rekey daemon (`dev.marius.macutils.rekey`), shared defaults suite, backup folder name, and signing identity
  (`mac-utils Dev`). Old rekey daemons and helper login items are removed automatically; shared settings migrate on
  first launch. Re-grant Full Disk Access and Accessibility (grants are keyed to the bundle id), and create a new
  `mac-utils Dev` certificate for stable signing.

## [0.4.0] - 2026-07-18

### Added

- Dock Folders: clicking a checked folder in the Dock opens a custom browsable list instead of the macOS stack, so items
  inside can be right-clicked (Open in Terminal / Ghostty / VS Code, Reveal in Finder, Copy Path). Backed by a new
  background helper, `macOS Utility Helper`.
- Menu bar folder browser for pinned folders.
- Test suite (`make test`) covering path-safety rules, shell/AppleScript escaping, and saved-data migration.
- `make tcc` resets the app's and helper's Accessibility grants.

### Changed

- App and helper are now signed with a stable local certificate instead of ad-hoc, so Accessibility and Full Disk Access
  grants survive a rebuild. Set `SIGN_ID` to override; defaults to the local `macOS Utility Dev` identity.
- Version and build numbers are injected from the Makefile at build time rather than duplicated in the plists.
- The Rekey startup daemon is now `dev.marius.macosutility.rekey.plist`. Older `mariuzm.rekey` and `dev.marius.rekey`
  daemons are booted out and removed automatically on install, or via the "Remove" button in the Rekey pane.
- Saved key mappings persist by HID usage rather than by display name, so renaming a key label no longer orphans
  existing mappings.
- Code layout: helper-only and app-only code moved out of the shared `FolderKit` library, which now holds only genuinely
  shared configuration and storage.

### Fixed

- Cancelling the administrator password prompt was reported as "everything failed" — `osascript` writes its cancellation
  to stderr, which was never captured.
- The count of removed items was derived from shell exit codes that `rm -rf` does not set on failure; removal is now
  verified per path.
- Paths containing apostrophes were corrupted in the failure list.
- A corrupt pinned-folders file caused the defaults to immediately overwrite it, losing the user's folders. Missing and
  unreadable files are now distinguished.
- `hidutil` output larger than the pipe buffer could deadlock the app on the main thread.
- Cancelling a scan no longer repopulates the list seconds later; cancelling a delete no longer starts a new scan; a
  failed backup no longer opens Finder on an empty folder.
- Spotlight privacy reads no longer stage a script in a writable temp directory before running it as root.
- Relative or empty paths could resolve against the working directory and bypass the protected-root guard.
- Backup and delete failures now report the underlying reason instead of only a count.
- An unreadable folder in the popover showed "Empty folder" rather than a permissions message.
- The Dock panel's trust-polling timer could run for the process lifetime after overrides were removed; the event tap is
  now torn down on deallocation.

## [0.3.0] - 2026-07-13

### Added

- Rekey section: remap keyboard keys (e.g. F-keys to brightness, volume, mute, playback) via macOS's native `hidutil`,
  with an optional startup daemon that re-applies mappings at every boot. Merged from the standalone macos-rekey app.

### Changed

- Top tab bar replaced with a left sidebar, with a smoothly animated show/hide toggle (⌃⌘S).
- Bundle identifier renamed from `dev.marius.macosutility` to `mariuzm.macosutility` — re-grant Full Disk Access after
  updating. (Reverted to `dev.marius.macosutility` in 0.4.0.)
- The Rekey startup daemon installs as `mariuzm.rekey.plist`. (Renamed again in 0.4.0.)
- `build.sh` replaced by a Makefile (`make dev`, `make build`, `make r`, `make clean`, `make status`, `make reset`);
  release bundles now build into `build/` instead of `dist/`.

## [0.2.0] - 2026-07-04

### Added

- Per-drive search for `node_modules` folders, grouped into a separate category for each location (the folder that
  contains the projects).

## [0.1.0] - 2026-07-04

Initial release.

### Added

- Parallel scan of all mounted volumes for removable files — caches, logs, trash, developer junk, and temporary files —
  grouped by drive → category → item with size, path, and a safety badge.
- Results split into **User Files** and **System Files**, with a checkbox per category and check-all / uncheck-all
  controls; Delete and Back Up act on the checked selection.
- Back up to `~/Desktop/macOS Utility Backup <timestamp>/`, preserving each item's original path.
- Delete via Move to Trash or permanent delete, with root-owned items removed using an admin password and simulator
  runtimes handled via `simctl`.
- Console with live output, working Cancel, and a watchdog for long operations.
- Spotlight Privacy tab.

[0.5.0]: https://github.com/MariuzM/mac-utils/releases/tag/v0.5.0
[0.2.0]: https://github.com/MariuzM/mac-utils/releases/tag/v0.2.0
[0.1.0]: https://github.com/MariuzM/mac-utils/releases/tag/v0.1.0
[0.8.0]: https://github.com/MariuzM/mac-utils/releases/tag/v0.8.0
