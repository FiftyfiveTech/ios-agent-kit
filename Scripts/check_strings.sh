#!/usr/bin/env bash
# Localization health check, per module (§3.11, §8.5). The source of truth is one
# String Catalog per resource-owning module: <module>/Localization/Localizable.xcstrings.
#
#   1. Key parity: every locale in a module's catalog has a real translation for
#      every key. A missing entry and Xcode's `new` state are the same thing to a
#      user — both fall back to the source-language string — so both fail here.
#   2. Drafts: entries still marked `needs_review` (what /translate writes) are
#      reported but do not fail — they are a review queue, not drift.
#   3. Cross-module duplicate keys — keys are namespaced by module (`shared.*`,
#      `app.*`) so a duplicate is very likely a copy/paste mistake, not real sharing.
#
# This is the parity check the template guarantees per §8.5 — it does not catch a
# wrong-bundle lookup at runtime (§3.11's documented limitation).
#
# Written against bash 3.2 (macOS's shipped /bin/bash) deliberately — no `mapfile`,
# no `declare -A`, so it runs without requiring a Homebrew bash.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

if ! command -v python3 >/dev/null 2>&1; then
  echo "check_strings.sh: python3 is required to read String Catalogs (.xcstrings is JSON)." >&2
  exit 1
fi

XCSTRINGS="python3 Scripts/lib/xcstrings.py"
FAIL=0
REVIEW_COUNT=0
SKIPPED_COUNT=0
PAIRS_FILE="$(mktemp)"
trap 'rm -f "$PAIRS_FILE"' EXIT

# A module's Localization root is any directory literally named "Localization"
# (App/Localization at T1, or <Module>/Resources/Localization at T2/T3 per §3.1/§3.9).
LOC_ROOTS=()
while IFS= read -r dir; do
  LOC_ROOTS+=("$dir")
done < <(find . -type d -name "Localization" -not -path "*/.build/*" | sort)

if [ "${#LOC_ROOTS[@]}" -eq 0 ]; then
  echo "check_strings.sh: no Localization/ directories found yet — nothing to check."
  exit 0
fi

for root in "${LOC_ROOTS[@]}"; do
  MODULE="$(basename "$(dirname "$root")")"
  CATALOG="$root/Localizable.xcstrings"

  # An adopted or pre-migration project may still carry per-locale .strings files.
  # Flag them rather than checking nothing and reporting success (§8.5).
  LEGACY="$(find "$root" -name "Localizable.strings" | head -n 5)"

  if [ ! -f "$CATALOG" ]; then
    if [ -n "$LEGACY" ]; then
      # A not-yet-migrated module is a warning, deliberately: an adopted project
      # gets these hooks before anyone has asked it to change format, and blocking
      # every commit on a migration nobody mentioned is not this check's job. Both
      # formats at once IS blocked below — that one silently hides half the strings.
      echo "check_strings.sh: module '$MODULE' still uses per-locale .strings, not a"
      echo "  String Catalog — this check can't verify it. Migrate when convenient:"
      echo "    Scripts/migrate_strings_to_catalog.sh $MODULE"
      SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
    else
      echo "check_strings.sh: no Localizable.xcstrings under $root — skipping module '$MODULE'."
    fi
    continue
  fi

  echo "check_strings.sh: checking module '$MODULE' ($CATALOG)"

  if [ -n "$LEGACY" ]; then
    echo "  BOTH a String Catalog and .strings files exist — two sources of truth for" >&2
    echo "  the same content, and this check only sees the catalog. Delete the .strings:" >&2
    echo "$LEGACY" | sed 's/^/    /' >&2
    FAIL=1
  fi

  while IFS=$'\t' read -r kind locale key; do
    [ -z "$kind" ] && continue
    case "$kind" in
      MISSING_BASE)
        echo "  MISSING in the base locale ($locale): $key" >&2
        FAIL=1
        ;;
      MISSING)
        echo "  MISSING in $locale: $key" >&2
        FAIL=1
        ;;
      NEEDS_REVIEW)
        REVIEW_COUNT=$((REVIEW_COUNT + 1))
        ;;
    esac
  done < <($XCSTRINGS report "$CATALOG")

  while IFS= read -r key; do
    [ -z "$key" ] && continue
    printf '%s\t%s\n' "$key" "$MODULE" >> "$PAIRS_FILE"
  done < <($XCSTRINGS keys "$CATALOG")
done

# Cross-module duplicate check: same key owned by more than one module.
echo "check_strings.sh: checking for cross-module key duplicates..."
DUPLICATES="$(sort "$PAIRS_FILE" | uniq | awk -F'\t' '
  { count[$1]++; modules[$1] = modules[$1] " " $2 }
  END { for (k in count) if (count[k] > 1) printf "%s ->%s\n", k, modules[k] }
')"

if [ -n "$DUPLICATES" ]; then
  echo "$DUPLICATES" | while IFS= read -r line; do
    echo "  DUPLICATE key: $line — namespace by module (§3.11)." >&2
  done
  FAIL=1
fi

if [ "$REVIEW_COUNT" -gt 0 ]; then
  echo "check_strings.sh: $REVIEW_COUNT entr(y/ies) still marked needs_review — drafted by"
  echo "  /translate and awaiting a human pass. Not a failure; review before shipping a locale."
fi

if [ "$FAIL" -ne 0 ]; then
  echo "" >&2
  echo "check_strings.sh: localization health check failed — see above." >&2
  exit 1
fi

if [ "$SKIPPED_COUNT" -gt 0 ]; then
  echo "check_strings.sh: $SKIPPED_COUNT module(s) skipped (not yet migrated to a String Catalog); the rest pass."
else
  echo "check_strings.sh: all modules pass parity and duplicate checks."
fi
