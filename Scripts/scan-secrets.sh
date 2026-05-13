#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$repo_root" ]]; then
  echo "scan-secrets: run this script from inside the git repository." >&2
  exit 2
fi

cd "$repo_root"

if ! command -v rg >/dev/null 2>&1; then
  echo "scan-secrets: ripgrep (rg) is required." >&2
  exit 2
fi

readonly known_secret_pattern='-----BEGIN (RSA|DSA|EC|OPENSSH|PRIVATE) KEY-----|sk-[A-Za-z0-9_-]{20,}|gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{35}|xox[baprs]-[A-Za-z0-9-]{10,}|AuthKey_[A-Z0-9]{10}\.p8'
readonly literal_assignment_pattern="(?i:(api[_-]?key|secret|token|password)\\s*[:=]\\s*['\\\"][^'\\\"\\n]{8,}['\\\"])"
readonly local_path_pattern='/Users/[A-Za-z0-9._-]+/'
readonly hardcoded_team_pattern='DEVELOPMENT_TEAM\s*=\s*(?!\$\(DEVELOPMENT_TEAM\)|YOUR_TEAM_ID)[A-Z0-9]{10}'
readonly hardcoded_signing_identity_pattern='(Apple Development|Apple Distribution|Developer ID Application|Developer ID Installer): [^"\n]+\([A-Z0-9]{10}\)'
readonly pattern="(${known_secret_pattern}|${literal_assignment_pattern}|${local_path_pattern}|${hardcoded_team_pattern}|${hardcoded_signing_identity_pattern})"

rg_common_args=(
  --pcre2
  -n
  -S
  --hidden
  --glob '!**/.git/**'
  --glob '!**/.build/**'
  --glob '!**/DerivedData/**'
  --glob '!**/build/**'
  --glob '!**/dist/**'
  --glob '!**/xcuserdata/**'
  --glob '!Config/iQuit.local.xcconfig'
)

usage() {
  cat <<'EOF'
Usage:
  Scripts/scan-secrets.sh
  Scripts/scan-secrets.sh --cached

Modes:
  default   Scan repository contents, excluding ignored/build files.
  --cached  Scan added lines in the staged diff.
EOF
}

report_failure() {
  local scope="$1"

  echo >&2
  echo "Potential secrets or personal machine-specific values found in $scope." >&2
  echo "Review the matches above before pushing." >&2
}

scan_worktree() {
  if rg "${rg_common_args[@]}" -e "$pattern" .; then
    report_failure "the working tree"
    return 1
  fi

  echo "Secret scan passed for working tree."
}

scan_cached() {
  local patch_file
  patch_file="$(mktemp)"
  git diff --cached --no-ext-diff --unified=0 --no-color > "$patch_file"

  if [[ -s "$patch_file" ]] && rg --pcre2 -n -S -e "^\+(?!\+\+\+ ).*$pattern" "$patch_file"; then
    rm -f "$patch_file"
    report_failure "staged changes"
    return 1
  fi

  rm -f "$patch_file"
  echo "Secret scan passed for staged changes."
}

case "${1:-}" in
  "")
    scan_worktree
    ;;
  --cached)
    scan_cached
    ;;
  -h|--help)
    usage
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
