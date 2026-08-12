#!/usr/bin/env bash
# Blocks the commit if a staged Swift file constructs a color literal outside any Theme/
# directory — colors must be Swift token values in Theme/, never inline (§6, §7).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

PATTERN='UIColor\(red:|Color\(red:|UIColor\(hex:|Color\(hex:|#[0-9A-Fa-f]{6}\b'

STAGED_SWIFT_FILES="$(git diff --cached --name-only --diff-filter=ACM -- '*.swift' 2>/dev/null || true)"

if [ -z "$STAGED_SWIFT_FILES" ]; then
  # Not run from a pre-commit context (e.g. CI on a full checkout) — scan everything tracked.
  STAGED_SWIFT_FILES="$(git ls-files -- '*.swift' 2>/dev/null || true)"
fi

VIOLATIONS=0

while IFS= read -r file; do
  [ -z "$file" ] && continue
  [ -f "$file" ] || continue

  case "$file" in
    */Theme/*) continue ;;
  esac

  MATCHES="$(grep -nE "$PATTERN" "$file" || true)"
  if [ -n "$MATCHES" ]; then
    echo "check_hardcoded_colors.sh: hardcoded color outside Theme/ in $file:" >&2
    echo "$MATCHES" | sed 's/^/  /' >&2
    VIOLATIONS=1
  fi
done <<< "$STAGED_SWIFT_FILES"

if [ "$VIOLATIONS" -ne 0 ]; then
  echo "" >&2
  echo "Define colors as Swift token values in a Theme/ directory instead — see docs/ai/theming_rules.md (§6)." >&2
  exit 1
fi

exit 0
