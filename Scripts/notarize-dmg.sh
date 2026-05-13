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
PROFILE="${APPLE_NOTARY_PROFILE:-$(read_xcconfig_value NOTARY_KEYCHAIN_PROFILE)}"

require_tool() {
  local tool="$1"
  local hint="$2"
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "Error: required tool '$tool' not found." >&2
    echo "  $hint" >&2
    exit 1
  fi
}

require_tool xcrun "Install Xcode or Xcode command line tools."
require_tool hdiutil "hdiutil ships with macOS."
require_tool spctl "spctl ships with macOS."

if [[ -n "$PROFILE" ]]; then
  notarize_creds=(--keychain-profile "$PROFILE")
elif [[ -n "${APPLE_ID:-}" && -n "${APPLE_APP_SPECIFIC_PASSWORD:-}" && -n "${APPLE_TEAM_ID:-}" ]]; then
  notarize_creds=(
    --apple-id "$APPLE_ID"
    --password "$APPLE_APP_SPECIFIC_PASSWORD"
    --team-id "$APPLE_TEAM_ID"
  )
else
  cat >&2 <<'MESSAGE'
Missing Apple notarization credentials.

Preferred local setup:
  xcrun notarytool store-credentials iquit-notary --team-id YOUR_TEAM_ID

Then set either:
  export APPLE_NOTARY_PROFILE=iquit-notary

Or add this to ignored Config/iQuit.local.xcconfig:
  NOTARY_KEYCHAIN_PROFILE = iquit-notary

CI fallback:
  APPLE_ID, APPLE_APP_SPECIFIC_PASSWORD, and APPLE_TEAM_ID
MESSAGE
  exit 1
fi

if [[ ! -f "$DMG_PATH" ]]; then
  "$ROOT/Scripts/build-dmg.sh"
fi

echo "=== Submitting DMG for notarization ==="
notarize_log="$(mktemp -t iquit_notarize_log)"

if [[ -n "$PROFILE" ]]; then
  echo "  Using keychain profile: $PROFILE"
else
  echo "  Using APPLE_ID / APPLE_APP_SPECIFIC_PASSWORD / APPLE_TEAM_ID"
fi

if ! xcrun notarytool submit "$DMG_PATH" \
  "${notarize_creds[@]}" \
  --output-format json \
  --wait \
  --no-progress \
  > "$notarize_log"; then
  echo "Error: notarytool submit failed." >&2
  cat "$notarize_log" >&2
  rm -f "$notarize_log"
  exit 1
fi

notarize_status="$(grep -o '"status"[[:space:]]*:[[:space:]]*"[^"]*"' "$notarize_log" | head -1 | sed 's/.*"\([^"]*\)"$/\1/')"
notarize_id="$(grep -o '"id"[[:space:]]*:[[:space:]]*"[^"]*"' "$notarize_log" | head -1 | sed 's/.*"\([^"]*\)"$/\1/')"
echo "  notarytool status=${notarize_status:-<unknown>} id=${notarize_id:-<unknown>}"

if [[ "$notarize_status" != "Accepted" ]]; then
  echo "Error: Apple notarization did not accept the submission." >&2
  cat "$notarize_log" >&2
  if [[ -n "$notarize_id" ]]; then
    echo "" >&2
    echo "Inspect diagnostics with:" >&2
    if [[ -n "$PROFILE" ]]; then
      echo "  xcrun notarytool log $notarize_id --keychain-profile \"$PROFILE\"" >&2
    else
      echo "  xcrun notarytool log $notarize_id --apple-id \\$APPLE_ID --password \\$APPLE_APP_SPECIFIC_PASSWORD --team-id \\$APPLE_TEAM_ID" >&2
    fi
  fi
  rm -f "$notarize_log"
  exit 1
fi

rm -f "$notarize_log"

echo "=== Stapling notarization ticket ==="
xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"

echo "=== Gatekeeper validation ==="
mount_point=""
dmg_dev_entry=""
mount_plist="$(mktemp)"

cleanup_mount() {
  rm -f "$mount_plist"
  if [[ -n "$mount_point" ]]; then
    hdiutil detach "$mount_point" -quiet 2>/dev/null || true
  elif [[ -n "$dmg_dev_entry" ]]; then
    hdiutil detach "$dmg_dev_entry" -quiet 2>/dev/null || true
  fi
}
trap cleanup_mount EXIT

if ! hdiutil attach "$DMG_PATH" -nobrowse -plist -mountrandom /tmp > "$mount_plist" 2>/dev/null; then
  echo "Error: hdiutil attach failed for $DMG_PATH" >&2
  exit 1
fi

dmg_dev_entry="$(/usr/libexec/PlistBuddy -c "Print :system-entities" "$mount_plist" 2>/dev/null \
  | awk -F' = ' '/dev-entry/ {print $2; exit}')"
mount_point="$(/usr/libexec/PlistBuddy -c "Print :system-entities" "$mount_plist" 2>/dev/null \
  | awk -F' = ' '/mount-point/ {print $2; exit}')"

if [[ -z "$mount_point" || ! -d "$mount_point" ]]; then
  echo "Error: failed to mount DMG for validation." >&2
  exit 1
fi

app_in_dmg="$mount_point/$APP_NAME.app"
if [[ ! -d "$app_in_dmg" ]]; then
  echo "Error: mounted DMG does not contain $APP_NAME.app" >&2
  exit 1
fi

broken_symlinks="$(find "$app_in_dmg" -type l ! -exec test -e {} \; -print 2>/dev/null)"
if [[ -n "$broken_symlinks" ]]; then
  echo "Error: broken symlinks found in app bundle:" >&2
  echo "$broken_symlinks" >&2
  exit 1
fi
echo "  No broken symlinks"

spctl --assess -t execute -vv "$app_in_dmg"
spctl --assess -t open --context context:primary-signature -vv "$DMG_PATH"

hdiutil detach "$mount_point" -quiet 2>/dev/null || true
mount_point=""
trap - EXIT

echo "Notarized and stapled:"
echo "  $DMG_PATH"
