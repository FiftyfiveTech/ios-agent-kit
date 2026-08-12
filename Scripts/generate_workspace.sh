#!/usr/bin/env bash
# generate_workspace.sh
#
# XcodeGen generates one .xcodeproj per spec and has no workspace-generation flag
# (§3.9, verified) — so at T3 the template owns the workspace file itself. Reads the
# project list from ios-skeleton.config.json and emits <Product>.xcworkspace's
# contents.xcworkspacedata: ~10 lines of <FileRef> XML, deterministic and diffable.
# Re-run on every project add (/add-module, /add-app).
#
# Expected config shape:
#   {
#     "topology": "T3",
#     "product": "<Product>",
#     "apps":    [ { "name": "AppOne", "path": "AppOne" }, ... ],
#     "modules": [ { "name": "Shared", "kind": "framework", "path": "Shared" },
#                  { "name": "DesignSystem", "kind": "package", "path": "Packages/DesignSystem" } ]
#   }
# Only "app" and "framework" entries own a .xcodeproj and get a workspace FileRef —
# local Swift packages don't (§3.9's framework-vs-package comparison table).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

CONFIG="ios-skeleton.config.json"

if [ ! -f "$CONFIG" ]; then
  echo "generate_workspace.sh: no $CONFIG — run /start first." >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "generate_workspace.sh: this script requires 'jq' to parse $CONFIG (brew install jq)." >&2
  exit 1
fi

TOPOLOGY="$(jq -r '.topology // ""' "$CONFIG")"

if [ "$TOPOLOGY" != "T3" ]; then
  echo "generate_workspace.sh: topology is '$TOPOLOGY', not T3 — no workspace needed. Nothing to do."
  exit 0
fi

PRODUCT="$(jq -r '.product // "Product"' "$CONFIG")"
WORKSPACE_DIR="${PRODUCT}.xcworkspace"

FILE_REFS="$(jq -r '
  (.apps // [])[] | "\(.path)/\(.name).xcodeproj"
' "$CONFIG")"
FILE_REFS="$FILE_REFS
$(jq -r '
  (.modules // [])[] | select(.kind == "framework") | "\(.path)/\(.name).xcodeproj"
' "$CONFIG")"

FILE_REFS="$(echo "$FILE_REFS" | sed '/^$/d' | sort -u)"

if [ -z "$FILE_REFS" ]; then
  echo "generate_workspace.sh: no apps or framework modules recorded in $CONFIG yet — nothing to reference."
fi

mkdir -p "$WORKSPACE_DIR/xcshareddata/swiftpm"

{
  echo '<?xml version="1.0" encoding="UTF-8"?>'
  echo '<Workspace'
  echo '   version = "1.0">'
  while IFS= read -r ref; do
    [ -z "$ref" ] && continue
    echo "   <FileRef"
    echo "      location = \"group:${ref}\">"
    echo "   </FileRef>"
  done <<< "$FILE_REFS"
  echo '</Workspace>'
} > "$WORKSPACE_DIR/contents.xcworkspacedata"

echo "generate_workspace.sh: wrote $WORKSPACE_DIR/contents.xcworkspacedata with $(echo "$FILE_REFS" | sed '/^$/d' | wc -l | tr -d ' ') project(s)."
echo "generate_workspace.sh: Package.resolved belongs at $WORKSPACE_DIR/xcshareddata/swiftpm/ once you resolve (§3.10 step 3)."
