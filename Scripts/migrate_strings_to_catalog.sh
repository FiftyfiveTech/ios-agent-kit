#!/usr/bin/env bash
# migrate_strings_to_catalog.sh [<module>] [--keep-strings]
#
# One-way migration for a project that predates the String Catalog default (§8.5):
# folds a module's per-locale <locale>.lproj/Localizable.strings into a single
# Localization/Localizable.xcstrings, then regenerates that module's L10n.swift.
#
# Every existing translation is carried over as `translated` — a migration is not
# the moment to re-open shipped strings for review. Keys, values, and `/* … */`
# comments are preserved; anything that doesn't parse as a `"key" = "value";`
# entry is skipped rather than guessed at, and reported.
#
# The old .strings files are deleted afterwards, because leaving both in place is
# the exact two-sources-of-truth failure §8.5 warns about — and check_strings.sh
# fails while both exist. Deletion only happens for git-tracked files, so it is
# always recoverable; pass --keep-strings to skip it and clean up by hand.
#
# Run `xcodegen generate` (or `tuist generate`) afterwards: this changes which
# files exist on disk, which is exactly when a regenerate is required.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

if ! command -v python3 >/dev/null 2>&1; then
  echo "migrate_strings_to_catalog.sh: python3 is required (.xcstrings is JSON)." >&2
  exit 1
fi

KEEP_STRINGS=0
MODULE_FILTER=""
for arg in "$@"; do
  case "$arg" in
    --keep-strings) KEEP_STRINGS=1 ;;
    -*) echo "migrate_strings_to_catalog.sh: unknown option '$arg'" >&2; exit 1 ;;
    *) MODULE_FILTER="$arg" ;;
  esac
done

BASE_LOCALE="en"
MIGRATED=0

migrate_root() {
  local root="$1"
  local module
  module="$(basename "$(dirname "$root")")"
  local catalog="$root/Localizable.xcstrings"

  if [ -f "$catalog" ]; then
    echo "migrate_strings_to_catalog.sh: module '$module' already has a String Catalog — skipping."
    return 0
  fi

  # Collect "<locale>=<path>" pairs: en.lproj/Localizable.strings, or a bare
  # Localizable.strings at the root (the T1 pre-locale-split shape).
  local pairs=()
  while IFS= read -r file; do
    local dir locale
    dir="$(basename "$(dirname "$file")")"
    if [ "$dir" = ".lproj" ] || [[ "$dir" != *.lproj ]]; then
      locale="$BASE_LOCALE"
    else
      locale="${dir%.lproj}"
    fi
    [ "$locale" = "Base" ] && locale="$BASE_LOCALE"
    pairs+=("$locale=$file")
  done < <(find "$root" -name "Localizable.strings" | sort)

  if [ "${#pairs[@]}" -eq 0 ]; then
    return 0
  fi

  echo "migrate_strings_to_catalog.sh: migrating module '$module' (${#pairs[@]} locale file(s))"
  python3 Scripts/lib/xcstrings.py migrate "$catalog" "$BASE_LOCALE" "${pairs[@]}"

  if [ "$KEEP_STRINGS" -eq 0 ]; then
    for pair in "${pairs[@]}"; do
      local file="${pair#*=}"
      if git ls-files --error-unmatch "$file" >/dev/null 2>&1; then
        git rm -q "$file"
        echo "  removed $file (tracked in git — recoverable)"
      else
        echo "  KEPT $file — untracked by git, delete it yourself once you've checked it." >&2
      fi
    done
    # Drop now-empty .lproj folders so nothing references a directory with no content.
    find "$root" -type d -name "*.lproj" -empty -delete
  fi

  Scripts/generate_strings.sh "$module" || true
  MIGRATED=$((MIGRATED + 1))
}

while IFS= read -r root; do
  if [ -n "$MODULE_FILTER" ]; then
    [ "$(basename "$(dirname "$root")")" = "$MODULE_FILTER" ] || continue
  fi
  migrate_root "$root"
done < <(find . -type d -name "Localization" -not -path "*/.build/*" | sort)

if [ "$MIGRATED" -eq 0 ]; then
  echo "migrate_strings_to_catalog.sh: nothing to migrate."
  exit 0
fi

echo ""
echo "Migrated $MIGRATED module(s). Next:"
echo "  1. xcodegen generate      # the set of files on disk changed"
echo "  2. Scripts/check_strings.sh"
echo "  3. Open the catalog in Xcode and confirm the locale list looks right."
