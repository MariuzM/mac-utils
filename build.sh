#!/usr/bin/env bash
set -euo pipefail

CONFIG="${1:-release}"
APP_NAME="macOS Utility"
BIN_NAME="MacOSUtility"
ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT/.build/$CONFIG"
APP_DIR="$ROOT/dist/$APP_NAME.app"

echo "▶︎ Building ($CONFIG)…"
swift build -c "$CONFIG"

echo "▶︎ Assembling bundle…"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BUILD_DIR/$BIN_NAME" "$APP_DIR/Contents/MacOS/$BIN_NAME"
cp "$ROOT/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"

echo "▶︎ Signing (ad-hoc)…"
codesign --force --deep --sign - "$APP_DIR" >/dev/null 2>&1 || echo "  (codesign skipped)"

echo "✓ Built: $APP_DIR"
echo "  Run:   open \"$APP_DIR\""

open -R "$APP_DIR"
echo ""
echo "For system-wide scanning, grant Full Disk Access:"
echo "  System Settings → Privacy & Security → Full Disk Access → add the app"
