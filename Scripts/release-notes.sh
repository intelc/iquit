#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${1:?Usage: release-notes.sh VERSION}"
CHANGELOG="$ROOT/CHANGELOG.md"

if [[ ! -f "$CHANGELOG" ]]; then
  exit 1
fi

awk -v version="$VERSION" '
  $0 == "## " version {
    in_section = 1
    next
  }
  in_section && /^## / {
    exit
  }
  in_section {
    print
  }
' "$CHANGELOG" | sed '/./,$!d'
