#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/build"
APP="$BUILD/Mac Utils.app"

VERSION="$(plutil -extract version raw "$ROOT/package.json")"
BUILD_NUMBER="$(plutil -extract config.buildNumber raw "$ROOT/package.json")"

if [[ -n "${SIGN_ID:-}" ]]; then
  IDENTITY="$SIGN_ID"
elif security find-identity -v -p codesigning | grep -q '"mac-utils Dev"'; then
  IDENTITY="mac-utils Dev"
elif security find-identity -v -p codesigning | grep -q '"macOS Utility Dev"'; then
  IDENTITY="macOS Utility Dev"
else
  IDENTITY="-"
fi

build_package() {
  local dir="$1"
  swift build -c release --package-path "$dir" >&2
  swift build -c release --package-path "$dir" --show-bin-path
}

MAC_BIN="$(build_package "$ROOT/apps/mac")"
HELPER_BIN="$(build_package "$ROOT/apps/folder-helper")"

mkdir -p "$BUILD"
STAGING="$(mktemp -d "$BUILD/.bundle-XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT

BUNDLE="$STAGING/Mac Utils.app"
HELPER="$BUNDLE/Contents/Library/LoginItems/FolderHelper.app"

assemble() {
  local target="$1" binary="$2" plist="$3"
  mkdir -p "$target/Contents/MacOS"
  cp "$binary" "$target/Contents/MacOS/"
  cp "$plist" "$target/Contents/Info.plist"
  plutil -replace CFBundleShortVersionString -string "$VERSION" "$target/Contents/Info.plist"
  plutil -replace CFBundleVersion -string "$BUILD_NUMBER" "$target/Contents/Info.plist"
}

assemble "$BUNDLE" "$MAC_BIN/MacUtils" "$ROOT/apps/mac/Info.plist"
assemble "$HELPER" "$HELPER_BIN/FolderHelper" "$ROOT/apps/folder-helper/Info.plist"

for target in "$HELPER" "$BUNDLE"; do
  codesign --force --sign "$IDENTITY" "$target"
  codesign --verify --strict "$target"
done

rm -rf "$APP"
mv "$BUNDLE" "$APP"

echo "Built $APP $VERSION ($BUILD_NUMBER)"
echo "Signing identity: $IDENTITY"
if [[ "$IDENTITY" == "-" ]]; then
  echo "Ad-hoc build: macOS privacy permissions may need granting again after rebuilding."
fi
