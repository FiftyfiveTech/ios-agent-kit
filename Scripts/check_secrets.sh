#!/usr/bin/env bash
# Secrets/configuration health check (§8.3) — catches at commit time what the
# composition root would otherwise catch at launch time, in the simulator, with
# a preconditionFailure.
#
#   1. Every key declared in Secrets.xcconfig has a non-empty value. An empty
#      value is the failure this script exists for: $(KEY) expands to an empty
#      string in Info.plist, so the app crashes on launch instead of building
#      and running against a wrong-but-plausible default.
#   2. Key parity with Secrets.xcconfig.example, both directions — the invariant
#      docs/CODING_STANDARDS.md states ("if you add a key, add it to .example in
#      the same commit"). A key that exists only on your machine breaks CI. Keys
#      the example carries commented out are permitted but not required, which is
#      what makes the shipped API_KEY line a valid state rather than a failure.
#   3. API_BASE_URL, when declared, is an absolute URL with a scheme AND a host.
#      `//` starts a comment in xcconfig, so `https://host` written unescaped
#      arrives as the truncated `https:` — which URL(string:) parses happily and
#      RequestBuilder then fails every request against. This check applies the
#      same comment-stripping the build does, and expands both empty-substitution
#      escapes ($() and ${}), so it sees what Swift will see.
#
# Two states are a deliberate pass, not a skip-with-a-shrug:
#   - No Secrets.xcconfig at all. The file is gitignored, so this is the normal
#      state of a fresh clone (docs/ONBOARDING.md) and of any CI job that
#      injects configuration from the environment instead.
#   - No API_BASE_URL key. An offline (`networking: none`) project has it
#      stripped from both files by /start, and renders no reader to feed.
#
# Written against bash 3.2 (macOS's shipped /bin/bash) deliberately — no
# `mapfile`, no `declare -A`, so it runs without requiring a Homebrew bash.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

SECRETS="Secrets.xcconfig"
EXAMPLE="Secrets.xcconfig.example"
FAIL=0

if [ ! -f "$SECRETS" ]; then
  echo "check_secrets.sh: no $SECRETS at the repo root — nothing to check."
  echo "  This is the expected state of a fresh clone: the file is gitignored."
  echo "  Copy $EXAMPLE to $SECRETS and fill it in before the first build."
  exit 0
fi

# Prints "KEY<TAB>VALUE" per assignment. Mirrors the subset of xcconfig syntax
# this template uses: `KEY = value`, `//` comments (including trailing ones),
# blank lines, and `KEY[sdk=...]` conditional variants. It does not follow
# #include directives — a value inherited from an included file reads as absent
# here, which is why a missing key is never itself an error.
# `|| true` on the grep is required, not defensive: this script runs under
# `set -o pipefail`, and a file that declares no keys at all — an offline
# project's, once /start has stripped API_BASE_URL — makes grep exit 1 and would
# abort the whole run with no diagnostic.
extract_pairs() {
  sed -e 's|//.*||' "$1" \
    | { grep -E '^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*([[:space:]]*\[[^]]*\])?[[:space:]]*=' || true; } \
    | sed -E 's|^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)([[:space:]]*\[[^]]*\])?[[:space:]]*=[[:space:]]*(.*)$|\1\t\3|' \
    | sed -E 's|[[:space:]]+$||'
}

keys_of() { extract_pairs "$1" | cut -f1 | sort -u; }

# --- 1. Empty values ---------------------------------------------------------
while IFS="$(printf '\t')" read -r key value; do
  [ -n "$key" ] || continue
  if [ -z "$value" ]; then
    echo "$SECRETS: $key has no value." >&2
    echo "  \$($key) expands to an empty string in Info.plist, so the app fails at" >&2
    echo "  launch rather than at build. Give it a value or comment the line out." >&2
    FAIL=1
  fi
done <<EOF
$(extract_pairs "$SECRETS")
EOF

# --- 2. Key parity with the committed example --------------------------------
if [ -f "$EXAMPLE" ]; then
  # Two different sets, and conflating them is what makes a parity check annoying
  # enough to get deleted. A key the example *declares* is required — every
  # machine has to supply it. A key the example only carries commented out
  # (API_KEY ships that way) is merely *permitted*: it documents a key you may
  # add later, so its absence is correct and its presence is not a parity error.
  example_required="$(keys_of "$EXAMPLE")"
  example_commented="$({ grep -oE '^[[:space:]]*//[[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*=' "$EXAMPLE" || true; } \
    | sed -E 's|^[[:space:]]*//[[:space:]]*([A-Za-z_][A-Za-z0-9_]*).*$|\1|' | sort -u)"
  example_permitted="$(printf '%s\n%s\n' "$example_required" "$example_commented" | { grep -v '^$' || true; } | sort -u)"
  secrets_keys="$(keys_of "$SECRETS")"

  for key in $(comm -23 <(echo "$secrets_keys") <(echo "$example_permitted")); do
    echo "$SECRETS: $key is not recorded in $EXAMPLE." >&2
    echo "  Add it there in the same commit — $EXAMPLE is the only record of what" >&2
    echo "  a new machine or CI job has to supply." >&2
    FAIL=1
  done
  for key in $(comm -13 <(echo "$secrets_keys") <(echo "$example_required")); do
    echo "$SECRETS: $key is declared in $EXAMPLE but missing here." >&2
    echo "  Anything reading it gets an empty string at build time." >&2
    FAIL=1
  done
else
  echo "check_secrets.sh: $EXAMPLE is missing — it is meant to be committed (§8.3)." >&2
  FAIL=1
fi

# --- 3. API_BASE_URL shape ---------------------------------------------------
# Resolve the value the way the build does: the comment strip in extract_pairs
# already truncated an unescaped `https://host` to `https:`, and `$()` expands
# to nothing, so what is left here is exactly what Swift receives.
api_raw="$(extract_pairs "$SECRETS" | awk -F'\t' '$1 == "API_BASE_URL" { print $2; exit }')"
if [ -n "$api_raw" ]; then
  # Both empty-substitution spellings are valid xcconfig and both expand to
  # nothing — verified against `xcodebuild -showBuildSettings`. Stripping only
  # $() would fail a commit on a value the build resolves perfectly well.
  api_value="$(printf '%s' "$api_raw" | sed -e 's|\$()||g' -e 's|\${}||g')"
  if ! printf '%s' "$api_value" | grep -qE '^[A-Za-z][A-Za-z0-9+.-]*://[^/?#[:space:]]+'; then
    echo "$SECRETS: API_BASE_URL is not an absolute URL — resolves to \"$api_value\"." >&2
    echo "  It needs both a scheme and a host. If that looks truncated: \`//\` starts a" >&2
    echo "  comment in xcconfig, so write https:/\$()/host, not https://host." >&2
    FAIL=1
  fi
fi

if [ "$FAIL" -ne 0 ]; then
  echo "check_secrets.sh: FAILED — see docs/CODING_STANDARDS.md §Configuration and secrets." >&2
  exit 1
fi

echo "check_secrets.sh: OK"
