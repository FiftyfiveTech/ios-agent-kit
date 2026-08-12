#!/usr/bin/env bash
# Wraps swiftlint for CI/pre-commit, across every module, against the ONE root .swiftlint.yml (§7).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

if ! command -v swiftlint >/dev/null 2>&1; then
  echo "lint.sh: swiftlint not found. See docs/ONBOARDING.md for the pinned install method." >&2
  exit 1
fi

swiftlint lint --strict --config "$REPO_ROOT/.swiftlint.yml"
