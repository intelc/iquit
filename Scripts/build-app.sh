#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="${1:-release}"
APP_NAME="iQuit"
APP_DIR="$ROOT/.build/$APP_NAME.app"
BIN_DIR="$APP_DIR/Contents/MacOS"
RES_DIR="$APP_DIR/Contents/Resources"
FRAMEWORKS_DIR="$APP_DIR/Contents/Frameworks"
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
  awk -v key="$key" '
    $1 ~ "^[[:space:]]*" key "[[:space:]]*$" {
      value=substr($0, index($0, "=") + 1)
      sub(/^[[:space:]]*/, "", value)
      sub(/[[:space:]]*$/, "", value)
    }
    END { print value }
  ' "${files[@]}"
}

BUNDLE_IDENTIFIER="$(read_xcconfig_value IQUIT_BUNDLE_IDENTIFIER)"
CODE_SIGN_IDENTITY="$(read_xcconfig_value CODE_SIGN_IDENTITY)"
APP_VERSION="${IQUIT_VERSION:-$(read_xcconfig_value IQUIT_VERSION)}"
BUILD_NUMBER="${IQUIT_BUILD_NUMBER:-$(read_xcconfig_value IQUIT_BUILD_NUMBER)}"
APPCAST_URL="${IQUIT_APPCAST_URL:-$(read_xcconfig_value IQUIT_APPCAST_URL)}"
SPARKLE_PUBLIC_ED_KEY="${SPARKLE_PUBLIC_ED_KEY:-$(read_xcconfig_value SPARKLE_PUBLIC_ED_KEY)}"

if [[ -z "$BUNDLE_IDENTIFIER" ]]; then
  BUNDLE_IDENTIFIER="com.yihengchen.iquit"
fi

if [[ -z "$CODE_SIGN_IDENTITY" ]]; then
  CODE_SIGN_IDENTITY="-"
fi

if [[ -z "$APP_VERSION" ]]; then
  APP_VERSION="0.1.5"
fi

if [[ -z "$BUILD_NUMBER" ]]; then
  BUILD_NUMBER="${GITHUB_RUN_NUMBER:-}"
fi

if [[ -z "$BUILD_NUMBER" ]]; then
  BUILD_NUMBER="$(git -C "$ROOT" rev-list --count HEAD 2>/dev/null || true)"
fi

if [[ -z "$BUILD_NUMBER" ]]; then
  BUILD_NUMBER="6"
fi

if [[ -z "$APPCAST_URL" ]]; then
  APPCAST_URL="https://github.com/intelc/iquit/releases/latest/download/appcast.xml"
fi

swift build -c "$CONFIG" --product iQuit

rm -rf "$APP_DIR"
mkdir -p "$BIN_DIR" "$RES_DIR" "$FRAMEWORKS_DIR"

cp "$ROOT/.build/$CONFIG/iQuit" "$BIN_DIR/iQuit"
chmod +x "$BIN_DIR/iQuit"

sparkle_framework=""
sparkle_candidates=(
  "$ROOT/.build/$CONFIG/Sparkle.framework"
  "$ROOT/.build/$(uname -m)-apple-macosx/$CONFIG/Sparkle.framework"
  "$ROOT/.build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
)

for candidate in "${sparkle_candidates[@]}"; do
  if [[ -d "$candidate" ]]; then
    sparkle_framework="$candidate"
    break
  fi
done

if [[ -z "$sparkle_framework" ]]; then
  echo "Error: Sparkle.framework was not found after swift build." >&2
  echo "  Expected one of:" >&2
  printf '  %s\n' "${sparkle_candidates[@]}" >&2
  exit 1
fi

/usr/bin/ditto "$sparkle_framework" "$FRAMEWORKS_DIR/Sparkle.framework"

if ! /usr/bin/otool -l "$BIN_DIR/iQuit" | grep -q '@executable_path/../Frameworks'; then
  /usr/bin/install_name_tool -add_rpath "@executable_path/../Frameworks" "$BIN_DIR/iQuit"
fi

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
  <string>__APP_VERSION__</string>
  <key>CFBundleVersion</key>
  <string>__BUILD_NUMBER__</string>
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
/usr/bin/sed -i '' "s/__APP_VERSION__/${APP_VERSION//\//\\/}/g" "$APP_DIR/Contents/Info.plist"
/usr/bin/sed -i '' "s/__BUILD_NUMBER__/${BUILD_NUMBER//\//\\/}/g" "$APP_DIR/Contents/Info.plist"

if [[ -n "$SPARKLE_PUBLIC_ED_KEY" ]]; then
  /usr/libexec/PlistBuddy -c "Add :SUFeedURL string $APPCAST_URL" "$APP_DIR/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c "Add :SUPublicEDKey string $SPARKLE_PUBLIC_ED_KEY" "$APP_DIR/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c "Add :SUEnableAutomaticChecks bool true" "$APP_DIR/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c "Add :SUAutomaticallyUpdate bool true" "$APP_DIR/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c "Add :SUAllowsAutomaticUpdates bool true" "$APP_DIR/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c "Add :SUScheduledCheckInterval integer 86400" "$APP_DIR/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c "Add :SUScheduledImpatientCheckInterval integer 604800" "$APP_DIR/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c "Add :SUVerifyUpdateBeforeExtraction bool true" "$APP_DIR/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c "Add :SURequireSignedFeed bool true" "$APP_DIR/Contents/Info.plist"
else
  echo "Warning: SPARKLE_PUBLIC_ED_KEY is empty; Sparkle will stay disabled in this build." >&2
fi

codesign_args=(
  --force
  --deep
  --sign "$CODE_SIGN_IDENTITY"
  --identifier "$BUNDLE_IDENTIFIER"
)

framework_codesign_args=(
  --force
  --deep
  --sign "$CODE_SIGN_IDENTITY"
)

if [[ "$CODE_SIGN_IDENTITY" != "-" ]]; then
  codesign_args+=(--timestamp --options runtime)
  framework_codesign_args+=(--timestamp --options runtime)
fi

if [[ -f "$ENTITLEMENTS_FILE" ]]; then
  codesign_args+=(--entitlements "$ENTITLEMENTS_FILE")
fi

/usr/bin/codesign "${framework_codesign_args[@]}" "$FRAMEWORKS_DIR/Sparkle.framework"
/usr/bin/codesign "${codesign_args[@]}" "$APP_DIR"

echo "Built signed bundle:"
echo "  $APP_DIR"
echo "Bundle identifier:"
echo "  $BUNDLE_IDENTIFIER"
echo "Version:"
echo "  $APP_VERSION ($BUILD_NUMBER)"
echo "Appcast:"
echo "  $APPCAST_URL"
