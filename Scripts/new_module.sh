#!/usr/bin/env bash
# new_module.sh <Name> [--kind framework|package] [--deps A,B] [--ui]
#
# The deterministic half of /add-module (§4.7): creates a module's folders, spec
# (Package.swift or project.yml), test target, and — with --ui — its Localization/
# and Assets.xcassets plus a bundle-aware L10n.swift (§3.11). Generates one real
# compiling type and one passing test so the module is proven wired before anyone
# moves code into it.
#
# Wiring this module into each consumer's spec (§4.7's other half) is done by the
# /add-module Skill itself, one consumer at a time — which specs need editing is a
# judgment call this script doesn't make.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

NAME=""
KIND=""
DEPS=""
WANTS_UI=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --kind) KIND="$2"; shift 2 ;;
    --deps) DEPS="$2"; shift 2 ;;
    --ui) WANTS_UI=1; shift ;;
    *)
      if [ -z "$NAME" ]; then NAME="$1"; shift; else echo "new_module.sh: unexpected argument '$1'" >&2; exit 1; fi
      ;;
  esac
done

if [ -z "$NAME" ]; then
  echo "usage: new_module.sh <Name> [--kind framework|package] [--deps A,B] [--ui]" >&2
  exit 1
fi

if [ ! -f ios-skeleton.config.json ]; then
  echo "new_module.sh: no ios-skeleton.config.json — run /start first." >&2
  exit 1
fi

TOPOLOGY="$(sed -n 's/.*"topology"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' ios-skeleton.config.json | head -n1)"

if [ "$TOPOLOGY" = "T1" ]; then
  echo "new_module.sh: T1 has no module boundary — adding a module IS the T1→T2 migration (§3.10). Run that migration first, then re-run this." >&2
  exit 1
fi

if [ -z "$KIND" ]; then
  if [ "$TOPOLOGY" = "T3" ]; then KIND="framework"; else KIND="package"; fi
fi

if [ "$KIND" != "framework" ] && [ "$KIND" != "package" ]; then
  echo "new_module.sh: --kind must be 'framework' or 'package', got '$KIND'." >&2
  exit 1
fi

if [ "$KIND" = "package" ]; then
  MODULE_DIR="Packages/$NAME"
else
  MODULE_DIR="$NAME"
fi

if [ -e "$MODULE_DIR" ]; then
  echo "new_module.sh: $MODULE_DIR already exists — refusing to overwrite." >&2
  exit 1
fi

mkdir -p "$MODULE_DIR/Sources/$NAME" "$MODULE_DIR/Tests/${NAME}Tests"

# Dependency clause, shared by both kinds' generated placeholder type.
DEP_IMPORTS=""
if [ -n "$DEPS" ]; then
  IFS=',' read -r -a DEP_ARRAY <<< "$DEPS"
  for dep in "${DEP_ARRAY[@]}"; do
    DEP_IMPORTS="${DEP_IMPORTS}import ${dep}\n"
  done
fi

if [ "$KIND" = "package" ]; then
  PKG_DEPS=""
  TARGET_DEPS=""
  if [ -n "$DEPS" ]; then
    for dep in "${DEP_ARRAY[@]}"; do
      PKG_DEPS="${PKG_DEPS}        .package(path: \"../${dep}\"),\n"
      TARGET_DEPS="${TARGET_DEPS}                .product(name: \"${dep}\", package: \"${dep}\"),\n"
    done
  fi

  printf '// swift-tools-version:5.10\nimport PackageDescription\n\nlet package = Package(\n    name: "%s",\n    platforms: [.iOS(.v17)],\n    products: [\n        .library(name: "%s", targets: ["%s"]),\n    ],\n    dependencies: [\n%b    ],\n    targets: [\n        .target(\n            name: "%s",\n            dependencies: [\n%b            ]\n        ),\n        .testTarget(name: "%sTests", dependencies: ["%s"]),\n    ]\n)\n' \
    "$NAME" "$NAME" "$NAME" "$PKG_DEPS" "$NAME" "$TARGET_DEPS" "$NAME" "$NAME" > "$MODULE_DIR/Package.swift"
else
  DEP_YAML=""
  if [ -n "$DEPS" ]; then
    DEP_YAML="    dependencies:\n"
    for dep in "${DEP_ARRAY[@]}"; do
      DEP_YAML="${DEP_YAML}      - target: ${dep}\n"
    done
  fi

  printf 'name: %s\noptions:\n  deploymentTarget:\n    iOS: "17.0"\ntargets:\n  %s:\n    type: framework\n    platform: iOS\n    sources: [Sources]\n%b    scheme:\n      testTargets:\n        - %sTests\n  %sTests:\n    type: bundle.unit-test\n    platform: iOS\n    sources: [Tests]\n    dependencies:\n      - target: %s\n' \
    "$NAME" "$NAME" "$DEP_YAML" "$NAME" "$NAME" "$NAME" > "$MODULE_DIR/project.yml"
fi

printf '%b' "$DEP_IMPORTS" > "$MODULE_DIR/Sources/$NAME/${NAME}Info.swift.tmp"
{
  cat "$MODULE_DIR/Sources/$NAME/${NAME}Info.swift.tmp"
  cat <<EOF

/// Placeholder proving the module compiles and links — replace with real code.
public struct ${NAME}Info {
    public let version: String

    public init(version: String = "0.1.0") {
        self.version = version
    }
}
EOF
} > "$MODULE_DIR/Sources/$NAME/${NAME}Info.swift"
rm -f "$MODULE_DIR/Sources/$NAME/${NAME}Info.swift.tmp"

cat > "$MODULE_DIR/Tests/${NAME}Tests/${NAME}InfoTests.swift" <<EOF
import XCTest
@testable import ${NAME}

final class ${NAME}InfoTests: XCTestCase {
    func test_defaultVersion_isNotEmpty() {
        let info = ${NAME}Info()
        XCTAssertFalse(info.version.isEmpty)
    }
}
EOF

if [ "$WANTS_UI" -eq 1 ]; then
  mkdir -p "$MODULE_DIR/Resources/Localization" "$MODULE_DIR/Resources/Assets.xcassets"
  LOWER_NAME="$(echo "$NAME" | tr '[:upper:]' '[:lower:]')"
  python3 Scripts/lib/xcstrings.py add \
    "$MODULE_DIR/Resources/Localization/Localizable.xcstrings" \
    "${LOWER_NAME}.placeholder" "${NAME}" "Placeholder — replace with this module's first real string"
  cat > "$MODULE_DIR/Resources/Assets.xcassets/Contents.json" <<'EOF'
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF
  ./Scripts/generate_strings.sh "$NAME" || true
fi

echo "new_module.sh: created $KIND module '$NAME' at $MODULE_DIR."
echo "new_module.sh: next — wire it into each consumer's spec, then regenerate (and re-run generate_workspace.sh at T3)."
