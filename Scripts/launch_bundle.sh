#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
app_name="iQuit.app"
bundle_path="${repo_root}/.build/${app_name}"

# Match the Mosspath Lite dev-launch pattern: always build and launch the same
# signed app bundle path so macOS TCC grants attach to a stable app identity.
"${repo_root}/Scripts/build-app.sh" debug

if [[ ! -d "${bundle_path}" ]]; then
  echo "Could not find bundle at ${bundle_path}" >&2
  exit 1
fi

echo "Stopping existing iQuit bundle processes..."
pkill -f "/${app_name}/Contents/MacOS/iQuit" 2>/dev/null || true
sleep 0.5

echo "Launching signed bundle:"
echo "  ${bundle_path}"
open "${bundle_path}"

sleep 1
echo
echo "Current iQuit process:"
ps -axo pid,command | rg "/${app_name}/Contents/MacOS/iQuit" || true
