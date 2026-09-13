# Mac Utils

Native SwiftUI utilities for macOS 27 (Golden Gate), built with Swift 6.4 and the macOS 27 SDK. The main app, Dock
helper, and shared folder storage are separate Swift Package Manager targets.

## Build and run

Select Xcode 27 with `xcode-select`. The scripts require Python 3 and either npm or Bun; there are no JavaScript
dependencies to install. Version and build numbers come from `package.json`.

```sh
bun run build          # Signed release bundle: build/Mac Utils.app
bun run start          # Open the built app
bun run r              # Rebuild, stop the old app/helper, and open the new app
bun run dev            # Swift executable without a bundle; Dock Folders needs the release bundle
bun run check          # Strict Swift formatting, plist validation, and debug compilation
bun run format         # Format Swift sources using the project's .swift-format
bun run format:check   # Check formatting without changing files
bun run clean          # Remove Swift build products and the app bundle
```

Every command also works with `npm run`, for example `npm run build`. The Makefile has been removed.

Additional scripts:

- `helper:start` / `helper:stop`: start or stop the bundled Dock helper.
- `keys:status`: read the current HID mapping.
- `keys:reset`: clear the active HID mapping; this does not remove an installed startup mapping.
- `permissions:reset`: reset Accessibility grants for the app and helper.

`r` rebuilds, then stops the old app and helper before opening the new app. Enable it again from Dock Folders if it is
not registered to start at login. `build` alone does not launch or terminate either app.

## Features

- **Overview:** storage, memory, Siri status, and quick navigation.
- **Storage Cleaner:** bounded parallel scanning of local volumes, caches, logs, developer output, Trash, and project
  `node_modules`. Review items, back them up, move them to the Trash, or remove them permanently. Nested selections are
  counted and acted on once. Only safe categories are selected initially. Simulator devices and system runtimes are
  managed in Xcode, not deleted here.
- **App Leftovers:** inspect startup items, helpers, plug-ins, containers, preferences, and cached data. Only an
  explicitly named, provably missing local program is a confirmed orphan. Bundle-ID matches are suggestions that require
  review; unavailable external volumes are not proof of removal.
- **Performance:** CPU and memory samples every three seconds, search, sorting, and optional quit actions. Process
  identity, ownership, and protection are rechecked immediately before termination. Suggested memory is the resident
  memory of distinct processes, not a promise of reclaimed RAM.
- **Siri:** disable the supported Siri controls in one click, inspect their resulting state, and restore the previous
  settings. See the limits below.
- **Spotlight Privacy:** inspect indexing exclusions with administrator authorization and open System Settings to edit
  them. Unexpected command output is reported as an error.
- **Keyboard:** remap supported keys using `hidutil`, with optional boot persistence. Configuration saves are atomic,
  conflicting sources are rejected, and privileged operations run asynchronously.
- **Dock Folders:** browse selected Dock folders through the embedded helper, with modern `SMAppService` login
  registration. Packages open as apps/files rather than folders.
- **Default Apps:** choose applications by file type. Extensions sharing a type also share its default.

## Siri on macOS 27

The control was checked against this Mac's installed launch agents, executables, preference data, SDK, and command
output on macOS 27.0 build 26A428. It does not depend on System Settings UI automation.

**Disable Siri** saves the original state, writes the observed `Assistant Enabled` and `Cloud Sync Enabled` preferences
to false, blocks startup for installed supported user agents, and attempts to unload or stop their processes. It checks
each operation's result and reads the settings back.

The supported agents are `com.apple.campo` (Siri AI), `com.apple.Siri.agent`, `com.apple.assistantd`,
`com.apple.siriinferenced`, and `com.apple.siriknowledged`. This affects the current macOS account.

On the tested build, macOS System Integrity Protection refuses unloading some agents and launchd can restart their
current processes. The app reports **Sign out needed** in that case. Sign out and back in, then use **Recheck**;
completion after a new login has not been verified in this session. The app only reports disabled when the two
preferences are off and every detected supported agent has blocked startup and is stopped. This is not a guarantee about
every Apple Intelligence service.

Downloaded AI models are **not deleted**. Siri's model assets are protected and can be shared with other features. This
app does not disable SIP, change the sealed system volume, or claim that all Apple Intelligence features are off.
Blocking Siri AI may affect its Spotlight integration.

**Restore previous settings** restores values and startup states from
`~/Library/Application Support/Mac Utils/siri-restore.json`. Missing preference keys are restored as missing. The first
snapshot is retained across repeat disable attempts and failed operations, and is removed only after successful
restoration. Don't delete it if you want to restore that state.

## Permissions and signing

Full Disk Access is needed to read protected locations. Inaccessible paths can be skipped by scans; scan totals describe
accessible data. Administrator removal is permanent and has a separate confirmation. It cannot bypass macOS protection.
Backups preserve source paths inside a uniquely named folder on the Desktop.

Dock Folders needs Accessibility access for **Mac Utils Helper**. Login registration may need approval in System
Settings; the app displays the registration state and a link when required.

Builds use the local `mac-utils Dev` signing identity when available, otherwise ad-hoc signing. Set `SIGN_ID` to
override:

```sh
SIGN_ID=- bun run build
SIGN_ID='Developer ID Application: Your Name (TEAMID)' bun run build
```

Ad-hoc builds can require renewed privacy grants after rebuilding. A stable signing certificate provides a stable
identity. For a local development certificate, use Keychain Access → Certificate Assistant → Create a Certificate, with
the name `mac-utils Dev` and type Code Signing. Distribution outside your Mac additionally needs your own
signing/notarization workflow; these scripts do not notarize.

## Code structure

```text
Sources/MacUtils/
  App/          Window, navigation, overview
  Design/       Shared colors, cards, typography, buttons
  Cleaner/      Scan rules, engine, backup/removal, views
  Leftovers/    Installed-app inventory and leftover review
  Performance/  Process samples, suggestions, termination
  Siri/         System adapter, controller, snapshots, view model, view
  Spotlight/    Indexing exclusions
  Keyboard/     HID mappings and startup persistence
  Folders/      Helper management and folder preferences
  Extensions/   File-type default applications
  System/       Process execution, paths, permissions, deletion policy
Sources/FolderKit/     Shared folder models and persistence
Sources/FolderHelper/  Dock Accessibility integration and folder browser
scripts/app.py        Package-script implementation and bundle signing
```

The project uses Swift 6 concurrency checking. Process execution is centralized with bounded stdout/stderr collection,
binary output support, cancellation, and timeouts. File removal shares one normalized-path policy for ordinary and
administrator operations.

## Verification

`bun run check` is the repeatable repository check. No test target is added to the shipping package. During this
refactor, a separate temporary Swift Testing harness exercised command execution, path protection, fixture deletion,
package sizing, orphan detection, Spotlight parsing, Siri failure/recovery, process identity checks, and keyboard
serialization. All nine pages were rendered offscreen in light and dark appearances. A live Siri disable/restore cycle
restored the prior state.

Permission dialogs, login-item approval, a new login session, Dock interaction, and live privileged
cleanup/keyboard/default-app changes require separate interactive validation. Compilation and rendering do not establish
those outcomes.

## Cleanup access and review

The access panel checks whether this process can read several protected user locations. It does not query or promise a
global Full Disk Access grant. Missing probe folders are reported as unknown; denied locations are reported separately.
Grant access to the exact bundled app shown by **Show App**, quit and reopen it, then rescan. An ad-hoc rebuild changes
the app's signing identity, so an existing toggle can need removal and re-adding. `bun run dev` runs an unbundled
executable and does not share the bundled app's identity.

Full Disk Access, administrator authorization, filesystem permissions, file locks, read-only volumes, and SIP are
different controls. No single grant bypasses all of them. Scans now report access/read errors instead of silently
treating them as empty folders. Incomplete folders are excluded from cleanup results. Error details are bounded to 100
paths. Scan totals describe discovered accessible files, not guaranteed physically recoverable space.

Deletion records the underlying error for each failure. Only access-denied failures offer an administrator retry, which
explicitly deletes permanently. User-owned files are also eligible when a restricted parent or child prevents ordinary
deletion. Privileged removal verifies each path within the authorized process and preserves its error. The result dialog
stays actionable instead of starting a rescan that blocks retry. After cleanup or cancellation, rescan to refresh sizes;
a system-authorized operation may still be finishing after cancellation.

Expand a category to select individual items. All entries are available in a lazy list. Broad app caches, build caches,
and `node_modules` require review rather than automatic selection. External-volume Trash is limited to the current
account. Temporary cleanup lists only regular files unchanged for at least 30 days; it excludes temporary folders and
Unix system logs. Age alone does not establish that a file is unused, so these entries are review-only.

Additional categories cover VS Code/Cursor caches and logs, npm logs, Maven's local repository, NuGet packages, and
Hugging Face model/dataset downloads. Editor settings, workspaces, and installed extensions are excluded. Maven may
contain locally installed artifacts, and package/model downloads may be required offline; these are never preselected.
Apple-managed AI models, Docker virtual disks, Time Machine snapshots, simulator state, and personal Downloads are not
added as bulk deletion targets.
