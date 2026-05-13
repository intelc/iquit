#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="iQuit"
APP_PATH="$ROOT/.build/$APP_NAME.app"
STAGING_DIR="$ROOT/.build/dmg/$APP_NAME"
DMG_PATH="$ROOT/.build/$APP_NAME.dmg"

"$ROOT/Scripts/build-app.sh" release

rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"

cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

/usr/bin/hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo "Built DMG:"
echo "  $DMG_PATH"
