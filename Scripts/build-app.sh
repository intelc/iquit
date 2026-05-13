#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="${1:-release}"
APP_NAME="iQuit"
APP_DIR="$ROOT/.build/$APP_NAME.app"
BIN_DIR="$APP_DIR/Contents/MacOS"
RES_DIR="$APP_DIR/Contents/Resources"
ICON_PATH="$RES_DIR/iQuit.icns"
CONFIG_FILE="$ROOT/Config/iQuit-Debug.xcconfig"
LOCAL_CONFIG_FILE="$ROOT/Config/iQuit.local.xcconfig"
ENTITLEMENTS_FILE="$ROOT/iQuit.entitlements"

read_xcconfig_value() {
  local key="$1"
  local files=("$CONFIG_FILE")
  if [[ -f "$LOCAL_CONFIG_FILE" ]]; then
    files+=("$LOCAL_CONFIG_FILE")
  fi
  awk -F '=' -v key="$key" '
    $1 ~ "^[[:space:]]*" key "[[:space:]]*$" {
      value=$2
      sub(/^[[:space:]]*/, "", value)
      sub(/[[:space:]]*$/, "", value)
    }
    END { print value }
  ' "${files[@]}"
}

BUNDLE_IDENTIFIER="$(read_xcconfig_value IQUIT_BUNDLE_IDENTIFIER)"
CODE_SIGN_IDENTITY="$(read_xcconfig_value CODE_SIGN_IDENTITY)"

if [[ -z "$BUNDLE_IDENTIFIER" ]]; then
  BUNDLE_IDENTIFIER="com.yihengchen.iquit"
fi

if [[ -z "$CODE_SIGN_IDENTITY" ]]; then
  CODE_SIGN_IDENTITY="-"
fi

swift build -c "$CONFIG" --product iQuit

rm -rf "$APP_DIR"
mkdir -p "$BIN_DIR" "$RES_DIR"

cp "$ROOT/.build/$CONFIG/iQuit" "$BIN_DIR/iQuit"
chmod +x "$BIN_DIR/iQuit"

/usr/bin/swift "$ROOT/Scripts/generate-app-icon.swift" "$ICON_PATH"

cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>iQuit</string>
  <key>CFBundleIdentifier</key>
  <string>__BUNDLE_IDENTIFIER__</string>
  <key>CFBundleName</key>
  <string>iQuit</string>
  <key>CFBundleDisplayName</key>
  <string>iQuit</string>
  <key>CFBundleIconFile</key>
  <string>iQuit.icns</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.1</string>
  <key>CFBundleVersion</key>
  <string>2</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

/usr/bin/sed -i '' "s/__BUNDLE_IDENTIFIER__/${BUNDLE_IDENTIFIER//\//\\/}/g" "$APP_DIR/Contents/Info.plist"

codesign_args=(
  --force
  --deep
  --sign "$CODE_SIGN_IDENTITY"
  --identifier "$BUNDLE_IDENTIFIER"
)

if [[ "$CODE_SIGN_IDENTITY" != "-" ]]; then
  codesign_args+=(--timestamp --options runtime)
fi

if [[ -f "$ENTITLEMENTS_FILE" ]]; then
  codesign_args+=(--entitlements "$ENTITLEMENTS_FILE")
fi

/usr/bin/codesign "${codesign_args[@]}" "$APP_DIR"

echo "Built signed bundle:"
echo "  $APP_DIR"
echo "Bundle identifier:"
echo "  $BUNDLE_IDENTIFIER"
