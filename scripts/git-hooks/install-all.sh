#!/usr/bin/env bash
# Install shared pre-commit / pre-push quality gates from antinvestor/common.
#
# Source of truth lives in this repository:
#   scripts/git-hooks/{pre-commit,pre-push,install-all.sh,README.md}
#
# Usage:
#   # From a checkout of antinvestor/common:
#   ./scripts/git-hooks/install-all.sh
#   ./scripts/git-hooks/install-all.sh --dry-run
#   ./scripts/git-hooks/install-all.sh --only antinvestor,pitabwire,stawi
#   ./scripts/git-hooks/install-all.sh /path/to/one/repo
#
#   # Or with an explicit common root / code root:
#   COMMON_ROOT=/path/to/common CODE_ROOT=$HOME/code ./scripts/git-hooks/install-all.sh
#
# Copies hooks into each repo's .githooks/ and sets:
#   git config core.hooksPath .githooks
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# common repo root = scripts/git-hooks/../..
COMMON_ROOT="${COMMON_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
CODE_ROOT="${CODE_ROOT:-$HOME/code}"
DRY_RUN=0
ONLY_FILTER=""
EXPLICIT_REPOS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --only)
      ONLY_FILTER="${2:-}"
      shift 2
      ;;
    --only=*)
      ONLY_FILTER="${1#*=}"
      shift
      ;;
    -h|--help)
      sed -n '2,25p' "$0"
      exit 0
      ;;
    *)
      EXPLICIT_REPOS+=("$1")
      shift
      ;;
  esac
done

if [[ ! -f "$SCRIPT_DIR/pre-commit" || ! -f "$SCRIPT_DIR/pre-push" ]]; then
  echo "Missing hook templates in $SCRIPT_DIR" >&2
  exit 1
fi

echo "Hook source: $SCRIPT_DIR (common: $COMMON_ROOT)"

matches_filter() {
  local path="$1"
  if [[ -z "$ONLY_FILTER" ]]; then
    return 0
  fi
  local IFS=','
  local part
  for part in $ONLY_FILTER; do
    part="$(echo "$part" | xargs)" # trim
    [[ -z "$part" ]] && continue
    if [[ "$path" == *"$part"* ]]; then
      return 0
    fi
  done
  return 1
}

install_into_repo() {
  local repo="$1"
  if [[ ! -d "$repo/.git" && ! -f "$repo/.git" ]]; then
    echo "SKIP (not a git repo): $repo"
    return 0
  fi
  if ! matches_filter "$repo"; then
    return 0
  fi

  echo "INSTALL: $repo"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    return 0
  fi

  mkdir -p "$repo/.githooks"
  cp "$SCRIPT_DIR/pre-commit" "$repo/.githooks/pre-commit"
  cp "$SCRIPT_DIR/pre-push" "$repo/.githooks/pre-push"
  chmod +x "$repo/.githooks/pre-commit" "$repo/.githooks/pre-push"

  # Point this repo at .githooks (local config only — not committed).
  git -C "$repo" config core.hooksPath .githooks

  if [[ -f "$repo/.gitignore" ]] && grep -qE '(^|/)\.githooks/?$' "$repo/.gitignore"; then
    echo "  note: .githooks is listed in .gitignore — hooks still work locally via core.hooksPath"
  fi
}

discover_repos() {
  find "$CODE_ROOT" -maxdepth 4 \( -type d -name .git -o -type f -name .git \) 2>/dev/null \
    | sed 's|/.git$||' \
    | sort -u
}

count=0
if [[ ${#EXPLICIT_REPOS[@]} -gt 0 ]]; then
  for repo in "${EXPLICIT_REPOS[@]}"; do
    install_into_repo "$(cd "$repo" && pwd)"
    count=$((count + 1))
  done
else
  while IFS= read -r repo; do
    [[ -z "$repo" ]] && continue
    case "$repo" in
      */.git|*/node_modules/*|*/.tmp/*|*/vendor/*) continue ;;
      */GoLandWorkspace*) continue ;;
    esac
    install_into_repo "$repo"
    count=$((count + 1))
  done < <(discover_repos)
fi

echo ""
if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "Dry run complete (would process $count repos under $CODE_ROOT)."
else
  echo "Installed hooks from antinvestor/common into repos under $CODE_ROOT (processed $count)."
  echo "Hooks run: format/lint + full tests on commit and again on push."
  echo "Emergency skip: SKIP_HOOKS=1 git commit|push   or   --no-verify"
fi
