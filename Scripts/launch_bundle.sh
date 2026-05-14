#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
app_name="iQuit.app"
bundle_path="${repo_root}/.build/${app_name}"
lsregister="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

if [[ -d "/Volumes/iQuit/${app_name}" ]]; then
  echo "Unregistering mounted DMG copy so TCC uses the dev bundle..."
  "$lsregister" -u "/Volumes/iQuit/${app_name}" 2>/dev/null || true
fi

# Match the Mosspath Lite dev-launch pattern: always build and launch the same
# signed app bundle path so macOS TCC grants attach to a stable app identity.
"${repo_root}/Scripts/build-app.sh" debug

if [[ ! -d "${bundle_path}" ]]; then
  echo "Could not find bundle at ${bundle_path}" >&2
  exit 1
fi

"$lsregister" -f "$bundle_path" 2>/dev/null || true

echo "Stopping existing iQuit bundle processes..."
while read -r pid; do
  [[ -z "$pid" ]] && continue
  kill "$pid" 2>/dev/null || true
done < <(pgrep -f "${bundle_path}/Contents/MacOS/iQuit" || true)
sleep 0.5

echo "Launching signed bundle:"
echo "  ${bundle_path}"
open "${bundle_path}"

sleep 1
echo
echo "Current iQuit process:"
ps -axo pid,command | rg "/${app_name}/Contents/MacOS/iQuit" || true
