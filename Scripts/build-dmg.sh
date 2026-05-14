#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="iQuit"
APP_PATH="$ROOT/.build/$APP_NAME.app"
STAGING_DIR="$ROOT/.build/dmg/$APP_NAME"
DMG_PATH="$ROOT/.build/$APP_NAME.dmg"
CONFIG_FILE="$ROOT/Config/iQuit-Debug.xcconfig"
LOCAL_CONFIG_FILE="$ROOT/Config/iQuit.local.xcconfig"

read_xcconfig_value() {
  local key="$1"
  local files=("$CONFIG_FILE")
  if [[ -f "$LOCAL_CONFIG_FILE" ]]; then
    files+=("$LOCAL_CONFIG_FILE")
  fi
  awk -v key="$key" '
    $1 ~ "^[[:space:]]*" key "[[:space:]]*$" {
      value=substr($0, index($0, "=") + 1)
      sub(/^[[:space:]]*/, "", value)
      sub(/[[:space:]]*$/, "", value)
    }
    END { print value }
  ' "${files[@]}"
}

CODE_SIGN_IDENTITY="$(read_xcconfig_value CODE_SIGN_IDENTITY)"

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

if [[ -n "$CODE_SIGN_IDENTITY" && "$CODE_SIGN_IDENTITY" != "-" ]]; then
  /usr/bin/codesign --force --sign "$CODE_SIGN_IDENTITY" --timestamp "$DMG_PATH"
fi

echo "Built DMG:"
echo "  $DMG_PATH"
