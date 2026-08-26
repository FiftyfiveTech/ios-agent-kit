#!/usr/bin/env bash
# Adds one or more configuration keys to Secrets.xcconfig and Secrets.xcconfig.example
# (§8.3). The deterministic half of /add-secret — the two files this script owns are
# the two that check_secrets.sh checks on every commit, so getting them out of sync
# is the failure this script exists to prevent.
#
#   Scripts/add_secret.sh KEY=value [KEY=value ...]
#   Scripts/add_secret.sh --no-value KEY [KEY ...]
#
# What it writes, per key:
#   - Secrets.xcconfig (gitignored) — the real value
#   - Secrets.xcconfig.example (committed) — the KEY with a placeholder value, never
#     the real one. The example is a record of which keys exist, not of what they are.
#
# What it will NOT write, and this is deliberate: a value that looks like a live
# credential. /add-secret is normally driven by an AI agent, which means the value
# reaches a model, a transcript and a log on its way here. Those keys get written
# COMMENTED OUT in both files — the state the shipped API_KEY line already
# demonstrates and check_secrets.sh already treats as permitted-but-not-required —
# and the developer uncomments the line in Secrets.xcconfig and pastes the value in
# by hand, out of band. `--no-value` asks for that treatment explicitly.
#
# It also applies the `$()` comment escape to any value containing `//` (§8.3):
# `//` starts a comment in xcconfig, so an un-escaped URL truncates at the scheme.
# check_secrets.sh only shape-checks API_BASE_URL, so for every other key this
# rewrite is the only thing standing between a pasted URL and a silent truncation.
#
# Info.plist wiring and the AppEnvironment accessor are NOT this script's job — a
# key in Secrets.xcconfig is invisible to Swift until both exist. /add-secret does
# those two steps; this script prints the reminder so a direct invocation doesn't
# quietly leave a key that nothing can read.
#
# bash 3.2 (macOS's shipped /bin/bash) — no mapfile, no declare -A.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

SECRETS="Secrets.xcconfig"
EXAMPLE="Secrets.xcconfig.example"
PLACEHOLDER="replace-me"
NO_VALUE=0

usage() {
  echo "usage: Scripts/add_secret.sh KEY=value [KEY=value ...]" >&2
  echo "       Scripts/add_secret.sh --no-value KEY [KEY ...]" >&2
  exit 2
}

[ "$#" -gt 0 ] || usage

ARGS=""
for arg in "$@"; do
  case "$arg" in
    --no-value) NO_VALUE=1 ;;
    -h|--help) usage ;;
    -*) echo "add_secret.sh: unknown option $arg" >&2; usage ;;
    *) ARGS="$ARGS
$arg" ;;
  esac
done
ARGS="$(printf '%s' "$ARGS" | { grep -v '^$' || true; })"
[ -n "$ARGS" ] || usage

if [ ! -f "$EXAMPLE" ]; then
  echo "add_secret.sh: $EXAMPLE is missing — it is meant to be committed (§8.3)." >&2
  echo "  Run /start, or copy it from Scripts/templates/config/." >&2
  exit 1
fi
if [ ! -f "$SECRETS" ]; then
  echo "add_secret.sh: no $SECRETS at the repo root." >&2
  echo "  It is gitignored, so a fresh clone has none. Create it first:" >&2
  echo "    cp $EXAMPLE $SECRETS" >&2
  echo "  Writing a key into a file that does not exist yet would leave $EXAMPLE" >&2
  echo "  declaring a key no machine supplies, which fails the next commit." >&2
  exit 1
fi

# Declared (uncommented) keys in a file — the same subset of xcconfig syntax
# check_secrets.sh parses, so the two scripts agree on what "declared" means.
declared_keys() {
  sed -e 's|//.*||' "$1" \
    | { grep -E '^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*([[:space:]]*\[[^]]*\])?[[:space:]]*=' || true; } \
    | sed -E 's|^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*).*$|\1|' | sort -u
}

# Keys the file carries commented out. Permitted-but-not-required in the example;
# here it matters because re-adding one would produce a duplicate line.
commented_keys() {
  { grep -oE '^[[:space:]]*//[[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*=' "$1" || true; } \
    | sed -E 's|^[[:space:]]*//[[:space:]]*([A-Za-z_][A-Za-z0-9_]*).*$|\1|' | sort -u
}

has_key() { echo "$2" | grep -qx "$1"; }

# --- Credential shape --------------------------------------------------------
# Two independent signals, either of which is enough. False positives cost a
# developer one manual paste; a false negative puts a live credential in a model's
# context window and a shell history. The asymmetry is the whole design.
looks_like_credential() {
  local key="$1" value="$2"

  # 1. Vendor-recognisable secret formats.
  case "$value" in
    sk-*|sk_live_*|sk_test_*|rk_live_*|pk_live_*) return 0 ;;
    ghp_*|gho_*|ghu_*|ghs_*|ghr_*|github_pat_*) return 0 ;;
    xoxb-*|xoxp-*|xoxa-*|xoxr-*|xoxs-*) return 0 ;;
    AKIA*|ASIA*|AIza*|ya29.*|eyJ*) return 0 ;;
    -----BEGIN*) return 0 ;;
    glpat-*|npm_*|dop_v1_*|shpat_*|SG.*) return 0 ;;
  esac

  # 2. A secret-ish key name with anything other than an obvious placeholder in it.
  #    API_KEY = replace-me is a developer scaffolding a key; API_KEY = <40 chars>
  #    is a developer pasting one.
  if printf '%s' "$key" | grep -qE '(^|_)(KEY|SECRET|TOKEN|PASSWORD|PASSWD|CREDENTIAL|CREDENTIALS|PRIVATE|CERT|SIGNING|DSN|AUTH|APIKEY|PAT)($|_)'; then
    case "$(printf '%s' "$value" | tr '[:upper:]' '[:lower:]')" in
      "$PLACEHOLDER"|replace-me|replaceme|changeme|change-me|todo|tbd|placeholder|xxx|""|"<"*) return 1 ;;
      *) return 0 ;;
    esac
  fi

  # 3. High-entropy-looking opaque blob under any key name: long, no spaces,
  #    mixed case and digits, and made only of the characters secrets are made of.
  if [ "${#value}" -ge 24 ] \
    && printf '%s' "$value" | grep -qE '^[A-Za-z0-9_+/=.~-]+$' \
    && printf '%s' "$value" | grep -q '[a-z]' \
    && printf '%s' "$value" | grep -q '[A-Z]' \
    && printf '%s' "$value" | grep -q '[0-9]' \
    && ! printf '%s' "$value" | grep -qE '^[A-Za-z][A-Za-z0-9+.-]*:'; then
    return 0
  fi

  # 4. A long pure-hex string — an API key as often as not, and never a URL.
  if printf '%s' "$value" | grep -qE '^[0-9a-fA-F]{32,}$'; then
    return 0
  fi

  return 1
}

# `//` starts a comment in xcconfig and there is no escape character; `$()`
# expands to nothing at build time, so splitting the slashes with it is the only
# form that survives both passes (docs/CODING_STANDARDS.md carries the mechanism).
escape_value() { printf '%s' "$1" | sed -e 's|//|/$()/|g'; }

SECRETS_DECLARED="$(declared_keys "$SECRETS")"
SECRETS_COMMENTED="$(commented_keys "$SECRETS")"
EXAMPLE_DECLARED="$(declared_keys "$EXAMPLE")"
EXAMPLE_COMMENTED="$(commented_keys "$EXAMPLE")"

WROTE=0
HELD_BACK=""

# Validate every key before writing any of them: a run that appends two keys and
# then rejects the third leaves the developer reasoning about a half-applied edit.
# SEEN accumulates as we go, so a key repeated *within one invocation* is caught by
# the same check as one already in the file — the snapshots above were taken before
# this loop and can't see it.
SEEN=""
while IFS= read -r pair; do
  case "$pair" in *=*) key="${pair%%=*}" ;; *) key="$pair" ;; esac
  key="$(printf '%s' "$key" | sed -E 's|^[[:space:]]+||; s|[[:space:]]+$||')"
  if ! printf '%s' "$key" | grep -qE '^[A-Za-z_][A-Za-z0-9_]*$'; then
    echo "add_secret.sh: \"$key\" is not a valid xcconfig key name." >&2
    echo "  Use SCREAMING_SNAKE_CASE: letters, digits and underscores only." >&2
    exit 1
  fi
  if has_key "$key" "$SEEN"; then
    echo "add_secret.sh: $key was given twice in this invocation." >&2
    echo "  A duplicate assignment is legal xcconfig and the last one silently wins," >&2
    echo "  so pass each key once with the value you actually want." >&2
    exit 1
  fi
  SEEN="$(printf '%s\n%s' "$SEEN" "$key")"
  if has_key "$key" "$SECRETS_DECLARED" || has_key "$key" "$EXAMPLE_DECLARED" \
    || has_key "$key" "$SECRETS_COMMENTED" || has_key "$key" "$EXAMPLE_COMMENTED"; then
    echo "add_secret.sh: $key already appears in $SECRETS or $EXAMPLE." >&2
    echo "  Edit the existing line rather than appending a second one — a duplicate" >&2
    echo "  assignment is legal xcconfig and the last one silently wins." >&2
    exit 1
  fi
  if [ "$NO_VALUE" -eq 0 ] && ! printf '%s' "$pair" | grep -q '='; then
    echo "add_secret.sh: \"$pair\" has no value. Write KEY=value, or pass --no-value." >&2
    exit 1
  fi
done <<EOF
$ARGS
EOF

while IFS= read -r pair; do
  case "$pair" in
    *=*) key="${pair%%=*}"; value="${pair#*=}" ;;
    *)   key="$pair"; value="" ;;
  esac
  key="$(printf '%s' "$key" | sed -E 's|^[[:space:]]+||; s|[[:space:]]+$||')"
  value="$(printf '%s' "$value" | sed -E 's|^[[:space:]]+||; s|[[:space:]]+$||')"

  escaped="$(escape_value "$value")"
  if [ "$escaped" != "$value" ]; then
    echo "add_secret.sh: $key contains \`//\`, which starts a comment in xcconfig —"
    echo "  written as \"$escaped\" so the build sees the value you meant."
  fi

  if [ "$NO_VALUE" -eq 1 ] || [ -z "$value" ] || looks_like_credential "$key" "$value"; then
    # Commented out in BOTH files. In the example that is the permitted-but-not-
    # required state check_secrets.sh already understands; in Secrets.xcconfig it
    # keeps the two in parity while the value is still missing, so the commit that
    # adds the key does not fail on an empty value.
    printf '\n// %s — paste the real value here yourself and uncomment. Gitignored.\n// Never through an AI agent: the prompt outlives the key.\n// %s =\n' \
      "$key" "$key" >> "$SECRETS"
    printf '\n// %s — required. Uncomment and fill in in your own Secrets.xcconfig.\n// %s =\n' \
      "$key" "$key" >> "$EXAMPLE"
    HELD_BACK="$HELD_BACK $key"
  else
    printf '\n%s = %s\n' "$key" "$escaped" >> "$SECRETS"
    printf '\n%s = %s\n' "$key" "$PLACEHOLDER" >> "$EXAMPLE"
    echo "add_secret.sh: $key written to $SECRETS, placeholder recorded in $EXAMPLE."
  fi
  WROTE=$((WROTE + 1))
done <<EOF
$ARGS
EOF

if [ -n "$HELD_BACK" ]; then
  echo
  echo "add_secret.sh: held back the value for:$HELD_BACK"
  echo "  Each one looks like a live credential, or was requested with --no-value."
  echo "  The key is declared — commented out — in both files. Open $SECRETS,"
  echo "  uncomment the line and paste the value in yourself. Do not send it through"
  echo "  an AI agent: a value typed into a prompt lives in that transcript, and in"
  echo "  every log along the way, long after you rotate it."
fi

echo
echo "add_secret.sh: $WROTE key(s) recorded. Two steps remain, and the key is"
echo "  unreadable from Swift until both are done:"
echo "    1. Surface each key in every app target's Info.plist as \$(KEY)."
echo "    2. Add an accessor to AppEnvironment, then regenerate the project."
echo "  /add-secret does both. Run Scripts/check_secrets.sh to verify the pair."
