#!/usr/bin/env bash
# generate_strings.sh [<module>]
#
# Regenerates one module's bundle-aware L10n.swift from its Localizable.xcstrings (§3.7).
# With no argument, regenerates every module listed in ios-skeleton.config.json (§3.7).
#
# String Catalogs are the source of truth (§8.5) — one .xcstrings per resource-owning
# module holding every locale, not a tree of per-locale .lproj/Localizable.strings.
#
# Bundle strategy (§3.11 — never Bundle.main from inside a shared module):
#   - module directory contains Package.swift            -> Bundle.module
#   - otherwise (app target or framework project)         -> Bundle(for: a private token type)
#     which resolves to that module's own compiled bundle, not Bundle.main.
#
# This generates L10n rather than relying on Xcode's own String Catalog symbol
# generation precisely because of that bundle rule: the accessor has to resolve
# through the owning module's bundle at every tier, and that is the one property
# a shared module cannot afford to get wrong at runtime (§3.11).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

if ! command -v python3 >/dev/null 2>&1; then
  echo "generate_strings.sh: python3 is required to read String Catalogs (.xcstrings is JSON)." >&2
  exit 1
fi

generate_for_module_dir() {
  local module_dir="$1"
  local module_name
  module_name="$(basename "$module_dir")"

  local loc_dir=""
  if [ -d "$module_dir/Localization" ]; then
    loc_dir="$module_dir/Localization"
  elif [ -d "$module_dir/Resources/Localization" ]; then
    loc_dir="$module_dir/Resources/Localization"
  else
    echo "generate_strings.sh: no Localization/ under $module_dir — skipping."
    return 0
  fi

  local catalog="$loc_dir/Localizable.xcstrings"
  if [ ! -f "$catalog" ]; then
    echo "generate_strings.sh: no Localizable.xcstrings under $loc_dir — skipping."
    return 0
  fi

  local bundle_strategy="token"
  if find "$module_dir" -maxdepth 2 -name "Package.swift" | grep -q .; then
    bundle_strategy="module"
  fi

  echo "generate_strings.sh: generating $loc_dir/L10n.swift for module '$module_name' (bundle: $bundle_strategy)"

  python3 Scripts/lib/xcstrings.py l10n "$catalog" "$module_name" "$bundle_strategy" > "$loc_dir/L10n.swift"
}

resolve_module_dir() {
  # A module/app's folder name doesn't always match its config "name" (e.g. the
  # app target folder is conventionally "App" at T1/T2 regardless of the app's
  # real name — §3.1). Prefer the config's recorded path; fall back to searching
  # by literal directory name for the T2 Packages/<Name> convention.
  local name="$1"
  if [ -f ios-skeleton.config.json ] && command -v jq >/dev/null 2>&1; then
    local path
    path="$(jq -r --arg n "$name" '
      [((.apps // [])[] | select(.name == $n) | .path),
       ((.modules // [])[] | select(.name == $n) | .path)] | .[0] // ""
    ' ios-skeleton.config.json 2>/dev/null)"
    if [ -n "$path" ] && [ -d "$path" ]; then
      echo "$path"
      return 0
    fi
  fi
  for candidate in "Packages/$name" "$name"; do
    if [ -d "$candidate" ]; then
      echo "$candidate"
      return 0
    fi
  done
  find . -maxdepth 3 -type d -name "$name" -not -path "*/.build/*" | head -n1
}

if [ "$#" -ge 1 ]; then
  MODULE_DIR="$(resolve_module_dir "$1")"
  if [ -z "$MODULE_DIR" ]; then
    echo "generate_strings.sh: could not find module '$1'." >&2
    exit 1
  fi
  generate_for_module_dir "$MODULE_DIR"
else
  if [ ! -f ios-skeleton.config.json ]; then
    echo "generate_strings.sh: no module given and no ios-skeleton.config.json to enumerate modules from." >&2
    exit 1
  fi
  MODULE_NAMES="$(grep -oE '"name"[[:space:]]*:[[:space:]]*"[^"]+"' ios-skeleton.config.json | sed -E 's/.*"([^"]+)"$/\1/')"
  while IFS= read -r name; do
    [ -z "$name" ] && continue
    MODULE_DIR="$(resolve_module_dir "$name")"
    [ -n "$MODULE_DIR" ] && generate_for_module_dir "$MODULE_DIR"
  done <<< "$MODULE_NAMES"
fi
