# macOS Utility

A native SwiftUI app that scans your Mac and every mounted volume for removable files — caches,
logs, trash, developer junk, temporary files — grouped per drive. Review what's found, back it up,
or delete it.

## Features

- **Scan** all volumes in parallel; results grouped by drive → User Files / System Files → category
  → item, each with size, path, and a safety badge. Check the categories you want and act on the
  selection.
- **node_modules** folders are searched per drive and grouped by the folder that contains the
  projects, so each location is its own category.
- **Back up** to `~/Desktop/macOS Utility Backup <timestamp>/`, keeping each item's original path so
  you can see where it came from.
- **Delete** via Move to Trash or permanent delete. Protected items are handled the right way —
  root-owned with your admin password, simulator runtimes via `simctl`.
- **Console** with live output, a working Cancel, and a watchdog for long operations.
- **Rekey** — remap keyboard keys (e.g. F-keys to brightness, volume, mute, playback) via macOS's
  native `hidutil`. The remap lives in the kernel's HID layer, so nothing needs to keep running;
  optionally install a startup daemon so mappings apply at every boot, even at the login screen.

- **Dock Folders** — clicking a checked folder in the Dock opens a browsable list instead of the
  macOS stack, so items inside can be right-clicked. Runs from a small background helper.

## Build & run

```bash
make dev            # build & run for development (no .app bundle — Folders needs `make r`)
make build          # release build -> build/macOS Utility.app
make r              # rebuild, restart the app and the helper
make test           # run the test suite
make tcc            # reset Accessibility grants for the app and helper
```

Grant **Full Disk Access** (System Settings → Privacy & Security) to scan and clean protected system
locations. Without it, those locations are skipped.

Dock Folders additionally needs **Accessibility** access — granted to the *helper*
(`macOS Utility Helper`), not the app.

### Signing

`make build` works anywhere with no setup: if a code-signing certificate named
`macOS Utility Dev` is in your keychain it signs with that, otherwise it falls back to ad-hoc
signing and says so.

The distinction only matters for permissions. macOS ties an Accessibility or Full Disk Access
grant to the binary's *designated requirement*. Ad-hoc signing makes that requirement the
binary's own hash, so every rebuild produces a new hash and silently invalidates the grant — the
System Settings toggle stays on while matching nothing. Signing with a certificate makes the
requirement the bundle ID plus the certificate, which is stable across rebuilds.

So ad-hoc is fine for a one-off build, and worth avoiding if you are iterating on the Dock
Folders feature, which needs Accessibility.

To create the certificate: Keychain Access → Certificate Assistant → Create a Certificate →
name it `macOS Utility Dev`, identity type Self Signed Root, certificate type Code Signing.

```bash
make build                                 # auto: certificate if present, else ad-hoc
make build SIGN_ID=-                       # force ad-hoc
make build SIGN_ID="Developer ID Application: …"
```
