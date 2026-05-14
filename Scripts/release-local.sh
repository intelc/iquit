#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${1:-}"
PRIVATE_KEY_FILE="${SPARKLE_PRIVATE_KEY_FILE:-$ROOT/sparkle-private-key.txt}"

usage() {
  cat >&2 <<'USAGE'
Usage: ./Scripts/release-local.sh VERSION

Example:
  ./Scripts/release-local.sh 0.1.6

This script builds, signs, notarizes, creates a signed Sparkle appcast, pushes
the version tag after local validation passes, and uploads release assets to
GitHub.
USAGE
}

if [[ -z "$VERSION" ]]; then
  usage
  exit 1
fi

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([-.+][0-9A-Za-z.-]+)?$ ]]; then
  echo "Error: VERSION must look like 0.1.6" >&2
  exit 1
fi

require_tool() {
  local tool="$1"
  local hint="$2"
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "Error: required tool '$tool' not found." >&2
    echo "  $hint" >&2
    exit 1
  fi
}

require_tool gh "Install GitHub CLI and run gh auth login."
require_tool git "Install git."

cd "$ROOT"

if [[ -n "$(git status --porcelain)" ]]; then
  cat >&2 <<'MESSAGE'
Error: working tree has uncommitted changes.

Commit the release changes first, then re-run this script. This keeps the tag,
DMG, and appcast tied to a reproducible commit.
MESSAGE
  exit 1
fi

if [[ ! -f "$PRIVATE_KEY_FILE" ]]; then
  cat >&2 <<MESSAGE
Error: Sparkle private key export not found:
  $PRIVATE_KEY_FILE

Create it with:
  .build/artifacts/sparkle/Sparkle/bin/generate_keys -x sparkle-private-key.txt
MESSAGE
  exit 1
fi

if ! "$ROOT/Scripts/release-notes.sh" "$VERSION" >/dev/null; then
  echo "Error: CHANGELOG.md does not contain a ## $VERSION section." >&2
  exit 1
fi

REPO_SLUG="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"
RELEASE_TAG="v$VERSION"
MAJOR="${VERSION%%.*}"
REST="${VERSION#*.}"
MINOR="${REST%%.*}"
PATCH_EXTRA="${REST#*.}"
PATCH="${PATCH_EXTRA%%[-+]*}"
BUILD_NUMBER=$((10#$MAJOR * 1000000 + 10#$MINOR * 1000 + 10#$PATCH))

export IQUIT_VERSION="$VERSION"
export IQUIT_BUILD_NUMBER="$BUILD_NUMBER"
export IQUIT_APPCAST_URL="https://github.com/$REPO_SLUG/releases/latest/download/appcast.xml"
export RELEASE_TAG

git fetch origin --tags

if ! git rev-parse -q --verify "refs/tags/$RELEASE_TAG" >/dev/null; then
  git tag -a "$RELEASE_TAG" -m "iQuit $VERSION"
fi

"$ROOT/Scripts/build-dmg.sh"
"$ROOT/Scripts/notarize-dmg.sh" "$ROOT/.build/iQuit.dmg"

SPARKLE_PRIVATE_KEY="$(cat "$PRIVATE_KEY_FILE")" \
  "$ROOT/Scripts/generate-appcast.sh" "$ROOT/.build/iQuit.dmg"

release_notes="$ROOT/.build/appcast/iQuit-$VERSION.md"
versioned_dmg="$ROOT/.build/appcast/iQuit-$VERSION.dmg"
appcast="$ROOT/.build/appcast/appcast.xml"

current_branch="$(git branch --show-current)"
if [[ -n "$current_branch" ]]; then
  git push origin "$current_branch"
fi

git push origin "$RELEASE_TAG"

if gh release view "$RELEASE_TAG" --repo "$REPO_SLUG" >/dev/null 2>&1; then
  gh release edit "$RELEASE_TAG" \
    --repo "$REPO_SLUG" \
    --title "iQuit $VERSION" \
    --notes-file "$release_notes" \
    --latest

  gh release upload "$RELEASE_TAG" \
    "$ROOT/.build/iQuit.dmg#iQuit.dmg" \
    "$versioned_dmg#iQuit-$VERSION.dmg" \
    "$appcast#appcast.xml" \
    --repo "$REPO_SLUG" \
    --clobber
else
  gh release create "$RELEASE_TAG" \
    "$ROOT/.build/iQuit.dmg#iQuit.dmg" \
    "$versioned_dmg#iQuit-$VERSION.dmg" \
    "$appcast#appcast.xml" \
    --repo "$REPO_SLUG" \
    --title "iQuit $VERSION" \
    --notes-file "$release_notes" \
    --latest
fi

cat <<MESSAGE
Released iQuit $VERSION.

Release:
  https://github.com/$REPO_SLUG/releases/tag/$RELEASE_TAG

Sparkle appcast:
  https://github.com/$REPO_SLUG/releases/latest/download/appcast.xml
MESSAGE
