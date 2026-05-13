#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="iQuit"
DMG_PATH="${1:-$ROOT/.build/$APP_NAME.dmg}"
CONFIG_FILE="$ROOT/Config/iQuit-Debug.xcconfig"
LOCAL_CONFIG_FILE="$ROOT/Config/iQuit.local.xcconfig"

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

TEAM_ID="$(read_xcconfig_value DEVELOPMENT_TEAM)"
PROFILE="$(read_xcconfig_value NOTARY_KEYCHAIN_PROFILE)"

if [[ -z "$PROFILE" ]]; then
  cat >&2 <<'MESSAGE'
Missing NOTARY_KEYCHAIN_PROFILE.

Add it to Config/iQuit.local.xcconfig, for example:
  NOTARY_KEYCHAIN_PROFILE = iquit-notary

Then store credentials in your macOS keychain:
  xcrun notarytool store-credentials iquit-notary --team-id YOUR_TEAM_ID
MESSAGE
  exit 1
fi

if [[ ! -f "$DMG_PATH" ]]; then
  "$ROOT/Scripts/build-dmg.sh"
fi

submit_args=(
  submit
  "$DMG_PATH"
  --keychain-profile "$PROFILE"
  --wait
)

if [[ -n "$TEAM_ID" ]]; then
  submit_args+=(--team-id "$TEAM_ID")
fi

xcrun notarytool "${submit_args[@]}"
xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"

echo "Notarized and stapled:"
echo "  $DMG_PATH"
