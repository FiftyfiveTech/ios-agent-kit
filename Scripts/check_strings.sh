#!/usr/bin/env bash
# Localization health check, per module (§3.11, §8.5):
#   1. Key parity: every locale in a module's Localization/ has the same keys as the
#      base locale (en.lproj, or the module's Localizable.strings if there are no
#      .lproj subfolders yet — the T1/pre-locale-split shape).
#   2. Cross-module duplicate keys — keys are namespaced by module (`shared.*`,
#      `app.*`) so a duplicate is very likely a copy/paste mistake, not real sharing.
#
# This is the parity/duplicate check the template guarantees per §8.5 — it does not
# catch a wrong-bundle lookup at runtime (§3.11's documented limitation).
#
# Written against bash 3.2 (macOS's shipped /bin/bash) deliberately — no `mapfile`,
# no `declare -A`, so it runs without requiring a Homebrew bash.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

BASE_LOCALE="en"
FAIL=0
PAIRS_FILE="$(mktemp)"
trap 'rm -f "$PAIRS_FILE"' EXIT

extract_keys() {
  # Prints one localization key per line from a .strings file: "key" = "value";
  grep -oE '^[[:space:]]*"[^"]+"[[:space:]]*=' "$1" 2>/dev/null | sed -E 's/^[[:space:]]*"([^"]+)"[[:space:]]*=.*/\1/'
}

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
  echo "check_strings.sh: checking module '$MODULE' ($root)"

  BASE_FILE=""
  if [ -f "$root/$BASE_LOCALE.lproj/Localizable.strings" ]; then
    BASE_FILE="$root/$BASE_LOCALE.lproj/Localizable.strings"
  elif [ -f "$root/Localizable.strings" ]; then
    BASE_FILE="$root/Localizable.strings"
  fi

  if [ -z "$BASE_FILE" ]; then
    echo "  no base-locale Localizable.strings found — skipping parity check for this module."
    continue
  fi

  BASE_KEYS="$(extract_keys "$BASE_FILE" | sort -u)"
  while IFS= read -r key; do
    [ -z "$key" ] && continue
    printf '%s\t%s\n' "$key" "$MODULE" >> "$PAIRS_FILE"
  done <<< "$BASE_KEYS"

  # Compare every sibling .lproj against the base.
  while IFS= read -r -d '' locale_file; do
    [ "$locale_file" = "$BASE_FILE" ] && continue
    LOCALE_KEYS="$(extract_keys "$locale_file" | sort -u)"

    MISSING="$(comm -23 <(echo "$BASE_KEYS") <(echo "$LOCALE_KEYS"))"
    EXTRA="$(comm -13 <(echo "$BASE_KEYS") <(echo "$LOCALE_KEYS"))"

    if [ -n "$MISSING" ]; then
      echo "  MISSING in $locale_file:" >&2
      echo "$MISSING" | sed 's/^/    /' >&2
      FAIL=1
    fi
    if [ -n "$EXTRA" ]; then
      echo "  EXTRA (not in base) in $locale_file:" >&2
      echo "$EXTRA" | sed 's/^/    /' >&2
      FAIL=1
    fi
  done < <(find "$root" -name "Localizable.strings" -print0)
done

# Cross-module duplicate check: same key, base locale, owned by more than one module.
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

if [ "$FAIL" -ne 0 ]; then
  echo "" >&2
  echo "check_strings.sh: localization health check failed — see above." >&2
  exit 1
fi

echo "check_strings.sh: all modules pass parity and duplicate checks."
