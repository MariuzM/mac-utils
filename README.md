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

## Build & run

```bash
make dev            # build & run for development
make build          # release build -> build/macOS Utility.app
```

Grant **Full Disk Access** (System Settings → Privacy & Security) to scan and clean protected system
locations. Without it, those locations are skipped.
