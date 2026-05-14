#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="iQuit"
DMG_PATH="${1:-$ROOT/.build/$APP_NAME.dmg}"
APP_PATH="$ROOT/.build/$APP_NAME.app"
INFO_PLIST="$APP_PATH/Contents/Info.plist"
APPCAST_DIR="${APPCAST_DIR:-$ROOT/.build/appcast}"
APPCAST_PATH="$APPCAST_DIR/appcast.xml"
REPO_SLUG="${GITHUB_REPOSITORY:-intelc/iquit}"

if [[ ! -f "$DMG_PATH" ]]; then
  echo "Error: DMG not found at $DMG_PATH" >&2
  echo "  Run ./Scripts/notarize-dmg.sh first." >&2
  exit 1
fi

if [[ ! -f "$INFO_PLIST" ]]; then
  echo "Error: app bundle Info.plist not found at $INFO_PLIST" >&2
  echo "  Run ./Scripts/build-dmg.sh first." >&2
  exit 1
fi

SPARKLE_BIN="$ROOT/.build/artifacts/sparkle/Sparkle/bin/generate_appcast"
if [[ ! -x "$SPARKLE_BIN" ]]; then
  echo "Error: Sparkle generate_appcast tool was not found." >&2
  echo "  Run swift build --product iQuit first so SwiftPM downloads Sparkle." >&2
  exit 1
fi

APP_VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INFO_PLIST")"
BUILD_NUMBER="$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$INFO_PLIST")"
RELEASE_TAG="${RELEASE_TAG:-v$APP_VERSION}"
ARCHIVE_NAME="${APP_NAME}-${APP_VERSION}.dmg"
DOWNLOAD_URL_PREFIX="${IQUIT_DOWNLOAD_URL_PREFIX:-https://github.com/$REPO_SLUG/releases/download/$RELEASE_TAG/}"

rm -rf "$APPCAST_DIR"
mkdir -p "$APPCAST_DIR"
cp "$DMG_PATH" "$APPCAST_DIR/$ARCHIVE_NAME"

notes_path="$APPCAST_DIR/${APP_NAME}-${APP_VERSION}.md"
if ! "$ROOT/Scripts/release-notes.sh" "$APP_VERSION" > "$notes_path" || [[ ! -s "$notes_path" ]]; then
  cat > "$notes_path" <<NOTES
# ${APP_NAME} ${APP_VERSION}

This release includes the latest ${APP_NAME} improvements and fixes.
NOTES
fi

appcast_args=(
  --download-url-prefix "$DOWNLOAD_URL_PREFIX"
  --embed-release-notes
  --maximum-versions "${SPARKLE_MAXIMUM_VERSIONS:-1}"
  --maximum-deltas "${SPARKLE_MAXIMUM_DELTAS:-0}"
  -o "$APPCAST_PATH"
  "$APPCAST_DIR"
)

if [[ -n "${SPARKLE_PRIVATE_KEY:-}" ]]; then
  printf '%s' "$SPARKLE_PRIVATE_KEY" | "$SPARKLE_BIN" --ed-key-file - "${appcast_args[@]}"
else
  "$SPARKLE_BIN" "${appcast_args[@]}"
fi

echo "Generated appcast:"
echo "  $APPCAST_PATH"
echo "Archive:"
echo "  $APPCAST_DIR/$ARCHIVE_NAME"
echo "Version:"
echo "  $APP_VERSION ($BUILD_NUMBER)"
echo "Download URL prefix:"
echo "  $DOWNLOAD_URL_PREFIX"
