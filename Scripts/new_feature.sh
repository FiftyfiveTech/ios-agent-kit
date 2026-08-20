#!/usr/bin/env bash
# new_feature.sh [--module <M>] <Name>[/<Group/Path>] ["field:Type,field2:Type2,..."]
#
# Deterministic for four combos (§1.4): mvvm-swiftui-navigationstack (default),
# vip-swiftui-navigationstack, vip-uikit-coordinator, mvc-uikit-coordinator.
# Renders that combo's Scripts/templates/<combo>/feature/*.template into a flat
# Features/<Name>/ folder (or Features/<Group>/<Name>/ — §3.2), writes
# Models/<Name>Models.swift in the shared Models location, registers the screen
# with whichever navigation backbone the combo uses (Route/NavigationStack for
# the SwiftUI combos, a factory on AppCoordinator for the UIKit combos), and
# generates a real passing test against a fake dependency (§4.1).
#
# For any other architecture/UI/navigation combo, folder skeleton + Models file +
# test scaffold are still generated deterministically; the per-layer file BODIES
# are left as fatalError() TODO stubs for the agent to write from
# docs/ai/architecture.md's chosen-pattern description (§1.4, §3.3) — this script
# never guesses Presenter/Interactor/Controller logic.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

CONFIG="ios-skeleton.config.json"

if [ ! -f "$CONFIG" ]; then
  echo "new_feature.sh: no $CONFIG — run /start first." >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "new_feature.sh: this script requires 'jq' (brew install jq)." >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Arg parsing
# ---------------------------------------------------------------------------
MODULE_ARG=""
POSITIONAL=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --module) MODULE_ARG="$2"; shift 2 ;;
    -h|--help)
      echo "usage: new_feature.sh [--module <M>] <Name>[/<Group/Path>] [\"field:Type,...\"]"
      exit 0
      ;;
    *) POSITIONAL+=("$1"); shift ;;
  esac
done

if [ "${#POSITIONAL[@]}" -lt 1 ]; then
  echo "usage: new_feature.sh [--module <M>] <Name>[/<Group/Path>] [\"field:Type,...\"]" >&2
  exit 1
fi

NAME_PATH="${POSITIONAL[0]}"
FIELDS_RAW="${POSITIONAL[1]:-}"

FEATURE_NAME="$(basename "$NAME_PATH")"
GROUP_PATH="$(dirname "$NAME_PATH")"
[ "$GROUP_PATH" = "." ] && GROUP_PATH=""

first_upper() { printf '%s%s' "$(printf '%s' "${1:0:1}" | tr '[:lower:]' '[:upper:]')" "${1:1}"; }
first_lower() { printf '%s%s' "$(printf '%s' "${1:0:1}" | tr '[:upper:]' '[:lower:]')" "${1:1}"; }

FEATURE="$(first_upper "$FEATURE_NAME")"
FEATURE_LOWER="$(first_lower "$FEATURE_NAME")"

# ---------------------------------------------------------------------------
# Module / topology resolution (§4's topology branch)
# ---------------------------------------------------------------------------
TOPOLOGY="$(jq -r '.topology // ""' "$CONFIG")"
PERSISTENCE="$(jq -r '.persistence // "None"' "$CONFIG")"
case "$PERSISTENCE" in
  SwiftData) PERSISTENCE_DIR="Scripts/templates/persistence/swiftdata" ;;
  CoreData)  PERSISTENCE_DIR="Scripts/templates/persistence/coredata" ;;
  None|"")   PERSISTENCE="None"; PERSISTENCE_DIR="" ;;
  *)
    echo "new_feature.sh: unknown persistence '$PERSISTENCE' in $CONFIG (expected SwiftData|CoreData|None)." >&2
    exit 1
    ;;
esac
HAS_PERSISTENCE=0
[ "$PERSISTENCE" != "None" ] && HAS_PERSISTENCE=1

# Q7. `none` means an offline, local-only app: there is no RequestBuilder or
# APIClient in the composition root (/start drops the app shell's
# __IF_NETWORKING__ block), so this feature's data layer has no remote half.
NETWORKING="$(jq -r '.networking // "urlsession-async"' "$CONFIG")"
case "$NETWORKING" in
  none|None|NONE) HAS_NETWORKING=0 ;;
  *)              HAS_NETWORKING=1 ;;
esac

if [ "$HAS_NETWORKING" -eq 0 ] && [ "$HAS_PERSISTENCE" -eq 0 ]; then
  echo "new_feature.sh: config has networking='none' AND persistence='None' — this feature would have no data layer at all." >&2
  echo "new_feature.sh: that's a legitimate app shape (a calculator, a converter), but no template covers it — write the View/ViewModel by hand from docs/ai/architecture.md, or pick a persistence stack in ios-skeleton.config.json." >&2
  exit 1
fi

resolve_target_module() {
  if [ -n "$MODULE_ARG" ]; then echo "$MODULE_ARG"; return; fi
  local default
  default="$(jq -r '.defaultModule // ""' "$CONFIG")"
  if [ -n "$default" ]; then echo "$default"; return; fi
  local app_count
  app_count="$(jq '(.apps // []) | length' "$CONFIG")"
  if [ "$app_count" = "1" ]; then
    jq -r '.apps[0].name' "$CONFIG"
    return
  fi
  echo ""
}

TARGET_MODULE="$(resolve_target_module)"
if [ -z "$TARGET_MODULE" ]; then
  echo "new_feature.sh: more than one app/module candidate and no --module given — refusing to guess (§4). Pass --module <name>." >&2
  exit 1
fi
TARGET_MODULE_LOWER="$(echo "$TARGET_MODULE" | tr '[:upper:]' '[:lower:]')"

app_path_for() {
  local name="$1" path
  path="$(jq -r --arg n "$name" '(.apps // [])[] | select(.name==$n) | .path' "$CONFIG" | head -n1)"
  [ -z "$path" ] && path="App"
  echo "$path"
}

APP_PATH="$(app_path_for "$TARGET_MODULE")"

case "$TOPOLOGY" in
  T1|T2)
    FEATURES_DIR="$APP_PATH/Features"
    TESTS_DIR="${TARGET_MODULE}Tests/Features"
    LOC_DIR="$APP_PATH/Localization"
    ;;
  T3)
    FEATURES_DIR="$APP_PATH/Sources/Features"
    TESTS_DIR="${APP_PATH}Tests/Features"
    LOC_DIR="$APP_PATH/Sources/App/Localization"
    ;;
  *)
    echo "new_feature.sh: unknown/missing topology '$TOPOLOGY' in $CONFIG." >&2
    exit 1
    ;;
esac

if [ -n "$GROUP_PATH" ]; then
  FEATURE_DIR="$FEATURES_DIR/$GROUP_PATH/$FEATURE"
  TEST_DIR="$TESTS_DIR/$GROUP_PATH/$FEATURE"
else
  FEATURE_DIR="$FEATURES_DIR/$FEATURE"
  TEST_DIR="$TESTS_DIR/$FEATURE"
fi

if [ -e "$FEATURE_DIR" ]; then
  echo "new_feature.sh: $FEATURE_DIR already exists — refusing to run (§4.1)." >&2
  exit 1
fi

resolve_role() {
  # args: role fallback_name -> prints "path name" (space-separated) or empty
  local role="$1"
  jq -r --arg r "$role" '
    (.modules // [])[] | select(.role == $r) | "\(.path) \(.name)"
  ' "$CONFIG" | head -n1
}

resolve_models_dir() {
  case "$TOPOLOGY" in
    T1) echo "$APP_PATH/Models" ;;
    T2)
      local found path name
      found="$(resolve_role models)"
      path="$(echo "$found" | awk '{print $1}')"
      name="$(echo "$found" | awk '{print $2}')"
      if [ -n "$path" ] && [ -n "$name" ]; then echo "$path/Sources/$name"; else echo "Packages/Models/Sources/Models"; fi
      ;;
    T3)
      local found path name shared
      found="$(resolve_role models)"
      path="$(echo "$found" | awk '{print $1}')"
      name="$(echo "$found" | awk '{print $2}')"
      if [ -n "$path" ] && [ -n "$name" ]; then
        echo "$path/Sources/$name"
      else
        shared="$(jq -r '.sharedModuleName // "Shared"' "$CONFIG")"
        echo "$shared/Sources/Models"
      fi
      ;;
  esac
}

resolve_role_import() {
  # args: role fallback_name
  local role="$1" fallback="$2"
  if [ "$TOPOLOGY" = "T1" ]; then echo ""; return; fi
  local found name
  found="$(resolve_role "$role")"
  name="$(echo "$found" | awk '{print $2}')"
  if [ -z "$name" ]; then
    if [ "$TOPOLOGY" = "T3" ]; then
      name="$(jq -r '.sharedModuleName // "Shared"' "$CONFIG")"
    else
      name="$fallback"
    fi
  fi
  echo "import $name"
}

MODELS_DIR="$(resolve_models_dir)"
IMPORT_MODELS="$(resolve_role_import models Models)"
IMPORT_NETWORKING="$(resolve_role_import networking Networking)"
IMPORT_DESIGNSYSTEM="$(resolve_role_import designsystem DesignSystem)"

dedup_imports() {
  local out=""
  for imp in "$@"; do
    [ -z "$imp" ] && continue
    case "$out" in
      *"$imp"*) ;;
      *) out="${out}${out:+$'\n'}${imp}" ;;
    esac
  done
  printf '%s' "$out"
}

IMPORTS_VIEW="$(dedup_imports "$IMPORT_MODELS" "$IMPORT_DESIGNSYSTEM")"
IMPORTS_LOGIC="$(dedup_imports "$IMPORT_MODELS")"
IMPORTS_SERVICE="$(dedup_imports "$IMPORT_MODELS" "$IMPORT_NETWORKING")"
IMPORTS_ALL="$(dedup_imports "$IMPORT_MODELS" "$IMPORT_NETWORKING" "$IMPORT_DESIGNSYSTEM")"

# Offline (Q7 = none): nothing generated here calls into Networking, so don't
# import it. An unused import is only a warning, but it's also a false signal
# about what this feature depends on — and at T2/T3 it's a link-graph claim.
if [ "$HAS_NETWORKING" -eq 0 ]; then
  IMPORTS_SERVICE="$IMPORTS_LOGIC"
  IMPORTS_ALL="$(dedup_imports "$IMPORT_MODELS" "$IMPORT_DESIGNSYSTEM")"
fi
TESTABLE_IMPORT="@testable import $TARGET_MODULE"
# With a local store in play, the VIP/MVC test files construct the Worker/Service
# themselves (RequestBuilder + a fake APIClient) to cover the read-through policy,
# so they need Networking too; without one they don't, and an unused import is
# noise. MVVM's read-through test fakes the Service protocol instead and needs
# nothing extra.
IMPORTS_TESTS="$IMPORTS_LOGIC"
[ "$HAS_PERSISTENCE" -eq 1 ] && IMPORTS_TESTS="$IMPORTS_SERVICE"

# ---------------------------------------------------------------------------
# Models collision check (§4.1) — refuse rather than silently overwrite/shadow.
# ---------------------------------------------------------------------------
MODELS_FILE="$MODELS_DIR/${FEATURE}Models.swift"
if [ -e "$MODELS_FILE" ]; then
  echo "new_feature.sh: $MODELS_FILE already exists — refusing to overwrite (§4.1)." >&2
  exit 1
fi

BUILTIN_TYPES="String Int Int32 Int64 Double Float CGFloat Bool Date UUID URL Data"
is_builtin_type() {
  local t="${1%\?}"
  for b in $BUILTIN_TYPES; do
    [ "$t" = "$b" ] && return 0
  done
  return 1
}

if [ -n "$FIELDS_RAW" ] && [ -d "$MODELS_DIR" ]; then
  IFS=',' read -r -a FIELD_PAIRS <<< "$FIELDS_RAW"
  for pair in "${FIELD_PAIRS[@]}"; do
    ftype="${pair#*:}"
    ftype="$(echo "$ftype" | sed 's/^ *//; s/ *$//')"
    if ! is_builtin_type "$ftype"; then
      HIT="$(grep -rl -E "(struct|class|enum) ${ftype}\b" "$MODELS_DIR" 2>/dev/null | head -n1 || true)"
      if [ -n "$HIT" ]; then
        echo "new_feature.sh: field type '$ftype' collides with an existing type in $HIT — rename the field's type or confirm reuse, then re-run (§4.1)." >&2
        exit 1
      fi
    fi
  done
fi

# ---------------------------------------------------------------------------
# Fake-value generation (§4.1) — sensible defaults by type; unrecognized types
# compile but fail loudly at test runtime via fatalErrorFakeValue().
# ---------------------------------------------------------------------------
NEEDS_FATAL_HELPER=0

fake_value_for_type() {
  local t="$1"
  case "$t" in
    *\?) echo "nil" ;;
    String) echo '"test"' ;;
    Int|Int32|Int64) echo "0" ;;
    Double|Float|CGFloat) echo "0.0" ;;
    Bool) echo "true" ;;
    Date) echo ".now" ;;
    UUID) echo "UUID()" ;;
    URL) echo 'URL(string: "https://example.com")!' ;;
    Data) echo "Data()" ;;
    *)
      NEEDS_FATAL_HELPER=1
      echo "fatalErrorFakeValue()"
      ;;
  esac
}

MODEL_PROPERTIES=""
MODEL_INIT_PARAMS=""
MODEL_INIT_BODY=""
FAKE_ARGS=""
# The SwiftData mirror of the same field list (§3.2) — only used when
# persistence != None; a "None" project never renders a record type at all.
RECORD_PROPERTIES=""
RECORD_INIT_ASSIGN=""
RECORD_TO_MODEL_ARGS=""

if [ -n "$FIELDS_RAW" ]; then
  IFS=',' read -r -a FIELD_PAIRS <<< "$FIELDS_RAW"
  FIRST=1
  for pair in "${FIELD_PAIRS[@]}"; do
    fname="${pair%%:*}"
    ftype="${pair#*:}"
    fname="$(echo "$fname" | sed 's/^ *//; s/ *$//')"
    ftype="$(echo "$ftype" | sed 's/^ *//; s/ *$//')"

    MODEL_PROPERTIES="${MODEL_PROPERTIES}    public let ${fname}: ${ftype}\n"
    MODEL_INIT_PARAMS="${MODEL_INIT_PARAMS}        ${fname}: ${ftype},\n"
    MODEL_INIT_BODY="${MODEL_INIT_BODY}        self.${fname} = ${fname}\n"

    RECORD_PROPERTIES="${RECORD_PROPERTIES}    public var ${fname}: ${ftype}\n"
    RECORD_INIT_ASSIGN="${RECORD_INIT_ASSIGN}        self.${fname} = model.${fname}\n"
    if [ -z "$RECORD_TO_MODEL_ARGS" ]; then
      RECORD_TO_MODEL_ARGS="${fname}: ${fname}"
    else
      RECORD_TO_MODEL_ARGS="${RECORD_TO_MODEL_ARGS}, ${fname}: ${fname}"
    fi

    fake="$(fake_value_for_type "$ftype")"
    if [ "$FIRST" -eq 1 ]; then
      FAKE_ARGS="${fname}: ${fake}"
      FIRST=0
    else
      FAKE_ARGS="${FAKE_ARGS}, ${fname}: ${fake}"
    fi
  done
  MODEL_INIT_PARAMS="${MODEL_INIT_PARAMS%,\\n}\n"
fi

FAKE_MODEL_LIST="[${FEATURE}Model(${FAKE_ARGS})]"

# ---------------------------------------------------------------------------
# Write Models/<Feature>Models.swift
# ---------------------------------------------------------------------------
mkdir -p "$MODELS_DIR"
{
  echo "import Foundation"
  [ "$PERSISTENCE" = "SwiftData" ] && echo "import SwiftData"
  echo ""
  echo "// Every model type this feature needs — request/response/entity structs alike —"
  echo "// lives here, never inside Features/${FEATURE}/ (§3.2)."
  echo "public struct ${FEATURE}Model: Hashable, Codable {"
  printf '%b' "$MODEL_PROPERTIES"
  echo ""
  echo "    public init("
  printf '%b' "$MODEL_INIT_PARAMS" | sed '$ s/,$//'
  echo "    ) {"
  printf '%b' "$MODEL_INIT_BODY"
  echo "    }"
  echo "}"
} > "$MODELS_FILE"

# ---------------------------------------------------------------------------
# Combo resolution (§1.4) — four fully-deterministic combos; everything else
# falls back to template-assisted layer-name stubs.
# ---------------------------------------------------------------------------
ARCHITECTURE="$(jq -r '.architecture // "MVVM"' "$CONFIG")"
UI_FRAMEWORK="$(jq -r '.uiFramework // "SwiftUI"' "$CONFIG")"
NAVIGATION="$(jq -r '.navigation // "navigationstack"' "$CONFIG")"

COMBO_KEY="${ARCHITECTURE}:${UI_FRAMEWORK}:${NAVIGATION}"
COMBO=""
case "$COMBO_KEY" in
  "MVVM:SwiftUI:navigationstack") COMBO="mvvm-swiftui-navigationstack" ;;
  "VIP:SwiftUI:navigationstack")  COMBO="vip-swiftui-navigationstack" ;;
  "VIP:UIKit:coordinator")        COMBO="vip-uikit-coordinator" ;;
  "MVC:UIKit:coordinator")        COMBO="mvc-uikit-coordinator" ;;
esac

DETERMINISTIC=0
if [ -n "$COMBO" ]; then
  DETERMINISTIC=1
  TEMPLATE_DIR="Scripts/templates/$COMBO/feature"
fi

mkdir -p "$FEATURE_DIR" "$TEST_DIR"

# Whole-line markers only, matching __MODULE_IMPORTS__'s existing convention:
#   __IF_PERSISTENCE__ / __ELSE_PERSISTENCE__ / __END_PERSISTENCE__
# keep or drop a block depending on the project's Q4 answer, so one template file
# covers both a persistence: None project and one with a local store (§3.8).
render_template() {
  local src="$1" dest="$2" imports="$3"
  awk -v feature="$FEATURE" -v featureLower="$FEATURE_LOWER" -v moduleLower="$TARGET_MODULE_LOWER" \
      -v appName="$TARGET_MODULE" -v imports="$imports" -v testableImport="$TESTABLE_IMPORT" \
      -v fakeList="$FAKE_MODEL_LIST" -v hasPersistence="$HAS_PERSISTENCE" \
      -v hasNetworking="$HAS_NETWORKING" \
      -v recordProperties="$RECORD_PROPERTIES" -v recordInitAssign="$RECORD_INIT_ASSIGN" \
      -v recordToModelArgs="$RECORD_TO_MODEL_ARGS" '
  {
    line = $0

    if (line == "__IF_PERSISTENCE__")   { inBlock = 1; branch = 1; next }
    if (line == "__ELSE_PERSISTENCE__") { if (inBlock) { branch = 2; next } }
    if (line == "__END_PERSISTENCE__")  { inBlock = 0; branch = 0; next }
    if (inBlock) {
      if (branch == 1 && hasPersistence != "1") next
      if (branch == 2 && hasPersistence == "1") next
    }

    # Q7'"'"'s family, tracked in its own state so the two can nest in either order
    # (they are distinct tokens, so no stack is needed — a line survives only if
    # neither active family suppresses it).
    if (line == "__IF_NETWORKING__")   { inNet = 1; netBranch = 1; next }
    if (line == "__ELSE_NETWORKING__") { if (inNet) { netBranch = 2; next } }
    if (line == "__END_NETWORKING__")  { inNet = 0; netBranch = 0; next }
    if (inNet) {
      if (netBranch == 1 && hasNetworking != "1") next
      if (netBranch == 2 && hasNetworking == "1") next
    }

    gsub(/__FEATURE_LOWER__/, featureLower, line)
    gsub(/__FEATURE__/, feature, line)
    gsub(/__MODULE_LOWER__/, moduleLower, line)
    gsub(/__APP_NAME__/, appName, line)
    gsub(/__FAKE_MODEL_LIST__/, fakeList, line)
    gsub(/__RECORD_TO_MODEL_ARGS__/, recordToModelArgs, line)
    if (line == "__MODULE_IMPORTS__") { if (imports != "") print imports; next }
    if (line == "__TESTABLE_IMPORT__") { if (testableImport != "") print testableImport; next }
    if (line == "__RECORD_PROPERTIES__") { if (recordProperties != "") printf "%s", recordProperties; next }
    if (line == "__RECORD_INIT_ASSIGN__") { if (recordInitAssign != "") printf "%s", recordInitAssign; next }
    print line
  }
  ' "$src" > "$dest"
}

# On a `networking: none` project the data layer has no remote half, so the file
# that would implement it isn't rendered from the template — this emits a stub in
# its place, with the protocol declarations its neighbours need and a TODO(agent)
# body. Everything else about the feature stays deterministic: folder, Models,
# LocalStore, navigation registration, localization. That's the same posture the
# off-default combos already use (§1.4) — deterministic structure, agent-written
# body — scoped here to one file instead of the whole feature.
#
# The consumer's protocol is unchanged and still named for a capability rather
# than a transport (§8.2), which is exactly why a local-backed implementation can
# satisfy it without the layer above knowing anything changed.
emit_offline_data_layer_stub() {
  local dest="$1" type_name="$2" conforms_to="$3" imports="$4"
  cat > "$dest" <<EOF
import Foundation
${imports}

// ${FEATURE}LocalStoreProtocol is declared here because this type is its consumer
// (§8.2) — ${FEATURE}LocalStore in the persistence layer is only the implementation.
protocol ${FEATURE}LocalStoreProtocol {
    func loadCached${FEATURE}List() async throws -> [${FEATURE}Model]
    func cache${FEATURE}List(_ items: [${FEATURE}Model]) async throws
}

// TODO(agent): implement this against localStore, per docs/ai/architecture.md.
//
// This project answered Q7 = networking: none, so there is no RequestBuilder or
// APIClient to call and the local store is the SOURCE OF TRUTH here, not a
// fallback for a failed request — don't port the read-through policy the
// networked templates use. \`cache${FEATURE}List\` is on the protocol because a
// local-only feature still writes: it's how a create/edit path persists.
//
// Keep conforming to ${conforms_to} — the layer above depends on that protocol,
// and it names a capability, not a transport, so nothing above this file changes.
struct ${type_name}: ${conforms_to} {
    private let localStore: ${FEATURE}LocalStoreProtocol

    init(localStore: ${FEATURE}LocalStoreProtocol) {
        self.localStore = localStore
    }

    func fetch${FEATURE}List() async throws -> [${FEATURE}Model] {
        fatalError("TODO(agent): read ${FEATURE} from localStore — see the note above")
    }
}
EOF
}

# The templated combos' test files exercise the remote/cache read-through policy,
# which doesn't exist offline. Emit a failing placeholder instead of a passing
# test that asserts semantics this feature doesn't have — the same choice the
# assisted branch below makes, and for the same reason (§4.1).
emit_offline_placeholder_test() {
  local dest="$1"
  cat > "$dest" <<EOF
import XCTest
${TESTABLE_IMPORT}

final class ${FEATURE}PlaceholderTests: XCTestCase {
    func test_todo() {
        // TODO(agent): write a real test against a fake ${FEATURE}LocalStoreProtocol
        // once the local-only data layer above is implemented (§4.1, §8.2). The
        // networked templates' read-through tests were deliberately NOT generated:
        // this project has no remote half for them to assert against.
        XCTFail("TODO: implement ${FEATURE}'s local-only data layer and this test")
    }
}
EOF
}

if [ "$DETERMINISTIC" -eq 1 ]; then
  HAS_ROUTE_NAV=0
  TEST_FILE=""
  FACTORY_SNIPPET=""

  case "$COMBO" in
    mvvm-swiftui-navigationstack)
      render_template "$TEMPLATE_DIR/View.swift.template"        "$FEATURE_DIR/${FEATURE}View.swift"        "$IMPORTS_VIEW"
      render_template "$TEMPLATE_DIR/ViewModel.swift.template"    "$FEATURE_DIR/${FEATURE}ViewModel.swift"    "$IMPORTS_LOGIC"
      TEST_FILE="$TEST_DIR/${FEATURE}ViewModelTests.swift"
      if [ "$HAS_NETWORKING" -eq 0 ]; then
        # No remote half: Repository is local-only and Service doesn't exist at all.
        emit_offline_data_layer_stub "$FEATURE_DIR/${FEATURE}Repository.swift" \
          "${FEATURE}Repository" "${FEATURE}RepositoryProtocol" "$IMPORTS_LOGIC"
        emit_offline_placeholder_test "$TEST_FILE"
      else
        render_template "$TEMPLATE_DIR/Repository.swift.template"  "$FEATURE_DIR/${FEATURE}Repository.swift"  "$IMPORTS_LOGIC"
        render_template "$TEMPLATE_DIR/Service.swift.template"      "$FEATURE_DIR/${FEATURE}Service.swift"      "$IMPORTS_SERVICE"
        render_template "$TEMPLATE_DIR/Tests.swift.template" "$TEST_FILE" "$IMPORTS_LOGIC"
      fi

      HAS_ROUTE_NAV=1
      if [ "$HAS_NETWORKING" -eq 0 ]; then
        FACTORY_SNIPPET="    @MainActor private func make${FEATURE}View() -> ${FEATURE}View {\\
        let repository = ${FEATURE}Repository(localStore: ${FEATURE}LocalStore(context: persistence.context))\\
        return ${FEATURE}View(viewModel: ${FEATURE}ViewModel(repository: repository))\\
    }\\
    \/\/ MARK: new-feature-factory-insertion-point"
      elif [ "$HAS_PERSISTENCE" -eq 1 ]; then
        # @MainActor because the local store is (PersistenceController.context is
        # main-actor-isolated); the composition root already calls this from the
        # main actor.
        FACTORY_SNIPPET="    @MainActor private func make${FEATURE}View() -> ${FEATURE}View {\\
        let repository = ${FEATURE}Repository(\\
            service: ${FEATURE}Service(requestBuilder: requestBuilder, apiClient: apiClient),\\
            localStore: ${FEATURE}LocalStore(context: persistence.context)\\
        )\\
        return ${FEATURE}View(viewModel: ${FEATURE}ViewModel(repository: repository))\\
    }\\
    \/\/ MARK: new-feature-factory-insertion-point"
      else
        FACTORY_SNIPPET="    private func make${FEATURE}View() -> ${FEATURE}View {\\
        ${FEATURE}View(\\
            viewModel: ${FEATURE}ViewModel(\\
                repository: ${FEATURE}Repository(\\
                    service: ${FEATURE}Service(requestBuilder: requestBuilder, apiClient: apiClient)\\
                )\\
            )\\
        )\\
    }\\
    \/\/ MARK: new-feature-factory-insertion-point"
      fi
      ;;

    vip-swiftui-navigationstack)
      render_template "$TEMPLATE_DIR/View.swift.template"       "$FEATURE_DIR/${FEATURE}View.swift"       "$IMPORTS_VIEW"
      render_template "$TEMPLATE_DIR/ViewModel.swift.template"   "$FEATURE_DIR/${FEATURE}ViewModel.swift"   "$IMPORTS_LOGIC"
      render_template "$TEMPLATE_DIR/Interactor.swift.template"  "$FEATURE_DIR/${FEATURE}Interactor.swift"  "$IMPORTS_LOGIC"
      render_template "$TEMPLATE_DIR/Presenter.swift.template"   "$FEATURE_DIR/${FEATURE}Presenter.swift"   "$IMPORTS_LOGIC"
      render_template "$TEMPLATE_DIR/Router.swift.template"      "$FEATURE_DIR/${FEATURE}Router.swift"      ""
      TEST_FILE="$TEST_DIR/${FEATURE}InteractorTests.swift"
      if [ "$HAS_NETWORKING" -eq 0 ]; then
        emit_offline_data_layer_stub "$FEATURE_DIR/${FEATURE}Worker.swift" \
          "${FEATURE}Worker" "${FEATURE}WorkerProtocol" "$IMPORTS_LOGIC"
        emit_offline_placeholder_test "$TEST_FILE"
      else
        render_template "$TEMPLATE_DIR/Worker.swift.template"      "$FEATURE_DIR/${FEATURE}Worker.swift"      "$IMPORTS_SERVICE"
        render_template "$TEMPLATE_DIR/Tests.swift.template" "$TEST_FILE" "$IMPORTS_TESTS"
      fi

      HAS_ROUTE_NAV=1
      if [ "$HAS_NETWORKING" -eq 0 ]; then
        FACTORY_SNIPPET="    @MainActor private func make${FEATURE}View() -> ${FEATURE}View {\\
        let presenter = ${FEATURE}Presenter()\\
        let worker = ${FEATURE}Worker(localStore: ${FEATURE}LocalStore(context: persistence.context))\\
        let interactor = ${FEATURE}Interactor(presenter: presenter, worker: worker)\\
        let viewModel = ${FEATURE}ViewModel(interactor: interactor)\\
        presenter.displayLogic = viewModel\\
        return ${FEATURE}View(viewModel: viewModel)\\
    }\\
    \/\/ MARK: new-feature-factory-insertion-point"
      elif [ "$HAS_PERSISTENCE" -eq 1 ]; then
        FACTORY_SNIPPET="    @MainActor private func make${FEATURE}View() -> ${FEATURE}View {\\
        let presenter = ${FEATURE}Presenter()\\
        let worker = ${FEATURE}Worker(\\
            requestBuilder: requestBuilder,\\
            apiClient: apiClient,\\
            localStore: ${FEATURE}LocalStore(context: persistence.context)\\
        )\\
        let interactor = ${FEATURE}Interactor(presenter: presenter, worker: worker)\\
        let viewModel = ${FEATURE}ViewModel(interactor: interactor)\\
        presenter.displayLogic = viewModel\\
        return ${FEATURE}View(viewModel: viewModel)\\
    }\\
    \/\/ MARK: new-feature-factory-insertion-point"
      else
        FACTORY_SNIPPET="    private func make${FEATURE}View() -> ${FEATURE}View {\\
        let presenter = ${FEATURE}Presenter()\\
        let worker = ${FEATURE}Worker(requestBuilder: requestBuilder, apiClient: apiClient)\\
        let interactor = ${FEATURE}Interactor(presenter: presenter, worker: worker)\\
        let viewModel = ${FEATURE}ViewModel(interactor: interactor)\\
        presenter.displayLogic = viewModel\\
        return ${FEATURE}View(viewModel: viewModel)\\
    }\\
    \/\/ MARK: new-feature-factory-insertion-point"
      fi
      ;;

    vip-uikit-coordinator)
      render_template "$TEMPLATE_DIR/ViewController.swift.template" "$FEATURE_DIR/${FEATURE}ViewController.swift" "$IMPORTS_LOGIC"
      render_template "$TEMPLATE_DIR/Interactor.swift.template"      "$FEATURE_DIR/${FEATURE}Interactor.swift"      "$IMPORTS_LOGIC"
      render_template "$TEMPLATE_DIR/Presenter.swift.template"       "$FEATURE_DIR/${FEATURE}Presenter.swift"       "$IMPORTS_LOGIC"
      render_template "$TEMPLATE_DIR/Router.swift.template"          "$FEATURE_DIR/${FEATURE}Router.swift"          ""
      TEST_FILE="$TEST_DIR/${FEATURE}InteractorTests.swift"
      if [ "$HAS_NETWORKING" -eq 0 ]; then
        emit_offline_data_layer_stub "$FEATURE_DIR/${FEATURE}Worker.swift" \
          "${FEATURE}Worker" "${FEATURE}WorkerProtocol" "$IMPORTS_LOGIC"
        emit_offline_placeholder_test "$TEST_FILE"
      else
        render_template "$TEMPLATE_DIR/Worker.swift.template"          "$FEATURE_DIR/${FEATURE}Worker.swift"          "$IMPORTS_SERVICE"
        render_template "$TEMPLATE_DIR/Tests.swift.template" "$TEST_FILE" "$IMPORTS_TESTS"
      fi

      HAS_ROUTE_NAV=0
      if [ "$HAS_NETWORKING" -eq 0 ]; then
        FACTORY_SNIPPET="    private func make${FEATURE}ViewController() -> ${FEATURE}ViewController {\\
        let presenter = ${FEATURE}Presenter()\\
        let worker = ${FEATURE}Worker(localStore: ${FEATURE}LocalStore(context: persistence.context))\\
        let interactor = ${FEATURE}Interactor(presenter: presenter, worker: worker)\\
        let viewController = ${FEATURE}ViewController(interactor: interactor)\\
        presenter.displayLogic = viewController\\
        return viewController\\
    }\\
    \/\/ MARK: new-feature-factory-insertion-point"
      elif [ "$HAS_PERSISTENCE" -eq 1 ]; then
        FACTORY_SNIPPET="    private func make${FEATURE}ViewController() -> ${FEATURE}ViewController {\\
        let presenter = ${FEATURE}Presenter()\\
        let worker = ${FEATURE}Worker(\\
            requestBuilder: requestBuilder,\\
            apiClient: apiClient,\\
            localStore: ${FEATURE}LocalStore(context: persistence.context)\\
        )\\
        let interactor = ${FEATURE}Interactor(presenter: presenter, worker: worker)\\
        let viewController = ${FEATURE}ViewController(interactor: interactor)\\
        presenter.displayLogic = viewController\\
        return viewController\\
    }\\
    \/\/ MARK: new-feature-factory-insertion-point"
      else
        FACTORY_SNIPPET="    private func make${FEATURE}ViewController() -> ${FEATURE}ViewController {\\
        let presenter = ${FEATURE}Presenter()\\
        let interactor = ${FEATURE}Interactor(\\
            presenter: presenter,\\
            worker: ${FEATURE}Worker(requestBuilder: requestBuilder, apiClient: apiClient)\\
        )\\
        let viewController = ${FEATURE}ViewController(interactor: interactor)\\
        presenter.displayLogic = viewController\\
        return viewController\\
    }\\
    \/\/ MARK: new-feature-factory-insertion-point"
      fi
      ;;

    mvc-uikit-coordinator)
      # MVC keeps its Service in the same file as the ViewController, so this one
      # combo can't use the skip-and-stub path — the template carries an
      # __IF_NETWORKING__ branch instead, and the TODO(agent) body lands there.
      render_template "$TEMPLATE_DIR/ViewController.swift.template" "$FEATURE_DIR/${FEATURE}ViewController.swift" "$IMPORTS_ALL"
      TEST_FILE="$TEST_DIR/${FEATURE}ViewControllerTests.swift"
      if [ "$HAS_NETWORKING" -eq 0 ]; then
        emit_offline_placeholder_test "$TEST_FILE"
      else
        render_template "$TEMPLATE_DIR/Tests.swift.template" "$TEST_FILE" "$IMPORTS_TESTS"
      fi

      HAS_ROUTE_NAV=0
      if [ "$HAS_NETWORKING" -eq 0 ]; then
        FACTORY_SNIPPET="    private func make${FEATURE}ViewController() -> ${FEATURE}ViewController {\\
        ${FEATURE}ViewController(\\
            service: ${FEATURE}Service(localStore: ${FEATURE}LocalStore(context: persistence.context))\\
        )\\
    }\\
    \/\/ MARK: new-feature-factory-insertion-point"
      elif [ "$HAS_PERSISTENCE" -eq 1 ]; then
        FACTORY_SNIPPET="    private func make${FEATURE}ViewController() -> ${FEATURE}ViewController {\\
        let service = ${FEATURE}Service(\\
            requestBuilder: requestBuilder,\\
            apiClient: apiClient,\\
            localStore: ${FEATURE}LocalStore(context: persistence.context)\\
        )\\
        return ${FEATURE}ViewController(service: service)\\
    }\\
    \/\/ MARK: new-feature-factory-insertion-point"
      else
        FACTORY_SNIPPET="    private func make${FEATURE}ViewController() -> ${FEATURE}ViewController {\\
        ${FEATURE}ViewController(\\
            service: ${FEATURE}Service(requestBuilder: requestBuilder, apiClient: apiClient)\\
        )\\
    }\\
    \/\/ MARK: new-feature-factory-insertion-point"
      fi
      ;;
  esac

  if [ "$NEEDS_FATAL_HELPER" -eq 1 ] && [ "$HAS_NETWORKING" -eq 1 ]; then
    cat >> "$TEST_FILE" <<EOF

private func fatalErrorFakeValue<T>(_ type: T.Type = T.self) -> T {
    fatalError("TODO: provide a fake value for \\(type)")
}
EOF
  fi

  # VIP's transport-struct namespace (§3.3, §8.2) — appended immediately after
  # the flat entity struct written above, never split across locations.
  if [ -f "$TEMPLATE_DIR/ModelsExtra.swift.template" ]; then
    render_template "$TEMPLATE_DIR/ModelsExtra.swift.template" "$MODELS_FILE.extra" ""
    cat "$MODELS_FILE.extra" >> "$MODELS_FILE"
    rm -f "$MODELS_FILE.extra"
  fi

  # ---------------------------------------------------------------------------
  # Local persistence (§3.8) — the OPTIONAL half of the data layer. The remote
  # path above is generated identically either way; everything below exists only
  # when the project answered Q4 with a real persistence stack. A
  # persistence: None project gets no LocalStore file, no record type, and no
  # localStore parameter anywhere (the templates' __IF_PERSISTENCE__ blocks are
  # dropped by render_template).
  # ---------------------------------------------------------------------------
  if [ "$HAS_PERSISTENCE" -eq 1 ]; then
    render_template "$PERSISTENCE_DIR/LocalStore.swift.template" \
      "$FEATURE_DIR/${FEATURE}LocalStore.swift" "$IMPORTS_LOGIC"

    # The SwiftData record mirroring <Feature>Model — a data shape, so it lands in
    # Models/ with everything else (§3.2), never in the feature folder. Core Data
    # has no equivalent: its entity lives in a .xcdatamodeld the template can't
    # generate (§10).
    if [ -f "$PERSISTENCE_DIR/ModelsExtra.swift.template" ]; then
      render_template "$PERSISTENCE_DIR/ModelsExtra.swift.template" "$MODELS_FILE.persist" ""
      cat "$MODELS_FILE.persist" >> "$MODELS_FILE"
      rm -f "$MODELS_FILE.persist"

      SCHEMA_FILE="$(grep -rl "new-feature-model-insertion-point" . \
        --exclude-dir=.git --exclude-dir=Scripts 2>/dev/null | head -n1 || true)"
      if [ -n "$SCHEMA_FILE" ]; then
        sed -i.bak "s/            \/\/ MARK: new-feature-model-insertion-point/            ${FEATURE}Record.self,\\
            \/\/ MARK: new-feature-model-insertion-point/" "$SCHEMA_FILE"
        rm -f "${SCHEMA_FILE}.bak"
      else
        echo "new_feature.sh: no SwiftData schema marker found — register ${FEATURE}Record with the ModelContainer manually." >&2
      fi
    fi
  fi

  # Composition registration — insert at the marker left in the app-shell files by
  # /start; never a second navigation path (§3.4). Every combo has a factory
  # marker; only the SwiftUI+NavigationStack combos also have a Route enum and a
  # destination switch (the UIKit combos push directly from AppCoordinator).
  FACTORY_FILE="$(grep -rl "new-feature-factory-insertion-point" "$APP_PATH" 2>/dev/null | head -n1 || true)"
  if [ -n "$FACTORY_FILE" ]; then
    sed -i.bak "s/    \/\/ MARK: new-feature-factory-insertion-point/${FACTORY_SNIPPET}/" "$FACTORY_FILE"
    rm -f "${FACTORY_FILE}.bak"
  else
    echo "new_feature.sh: no factory insertion marker found under $APP_PATH — wire '$FEATURE_LOWER' into the composition root manually." >&2
  fi

  if [ "$HAS_ROUTE_NAV" -eq 1 ]; then
    ROUTE_FILE="$(grep -rl "new-feature-route-insertion-point" "$APP_PATH" 2>/dev/null | head -n1 || true)"
    if [ -n "$ROUTE_FILE" ]; then
      sed -i.bak "s/    \/\/ MARK: new-feature-route-insertion-point/    case ${FEATURE_LOWER}\\
    \/\/ MARK: new-feature-route-insertion-point/" "$ROUTE_FILE"
      rm -f "${ROUTE_FILE}.bak"
    else
      echo "new_feature.sh: no Route insertion marker found under $APP_PATH — register '$FEATURE_LOWER' with the navigation backbone manually." >&2
    fi

    DEST_FILE="$(grep -rl "new-feature-destination-insertion-point" "$APP_PATH" 2>/dev/null | head -n1 || true)"
    if [ -n "$DEST_FILE" ]; then
      sed -i.bak "s/        \/\/ MARK: new-feature-destination-insertion-point/        case .${FEATURE_LOWER}:\\
            make${FEATURE}View()\\
        \/\/ MARK: new-feature-destination-insertion-point/" "$DEST_FILE"
      rm -f "${DEST_FILE}.bak"
    else
      echo "new_feature.sh: no destination insertion marker found under $APP_PATH — wire '$FEATURE_LOWER' into the NavigationStack manually." >&2
    fi
  fi
else
  echo "new_feature.sh: architecture='$ARCHITECTURE' ui='$UI_FRAMEWORK' nav='$NAVIGATION' is not the fully-templated combo (§1.4)."
  echo "new_feature.sh: generating folder skeleton + Models + test scaffold; layer BODIES are TODO stubs for the agent to write from docs/ai/architecture.md."
  if [ "$HAS_PERSISTENCE" -eq 1 ] && [ "$HAS_NETWORKING" -eq 1 ]; then
    echo "new_feature.sh: persistence='$PERSISTENCE' — also give this feature's data layer a <Feature>LocalStoreProtocol dependency alongside its remote one, following Scripts/templates/persistence/ (§3.8)."
  elif [ "$HAS_PERSISTENCE" -eq 1 ]; then
    echo "new_feature.sh: networking='none' — this feature's data layer has NO remote half. <Feature>LocalStore is the source of truth, not a cache; don't write a read-through policy (§3.8)."
  fi

  # One stub file per layer name for the CHOSEN architecture (§3.3) — the folder
  # skeleton is deterministic regardless of pattern; only the bodies fall back.
  case "$ARCHITECTURE" in
    MVC)   LAYERS="ViewController" ;;
    VIP)   LAYERS="View Interactor Presenter Router Worker" ;;
    VIPER) LAYERS="View Interactor Presenter Router" ;;
    MV)    LAYERS="View Model" ;;
    *)     LAYERS="View" ;;
  esac

  for layer in $LAYERS; do
    cat > "$FEATURE_DIR/${FEATURE}${layer}.swift" <<EOF
import Foundation

// TODO(agent): implement this ${layer} per docs/ai/architecture.md's ${ARCHITECTURE}
// layer description (§3.3). Depend on the layer below's protocol, not its
// implementation (§8.2) — new_feature.sh only generates the deterministic parts
// (folder, Models, nav registration, test) for non-default combos (§1.4).
struct ${FEATURE}${layer} {
}
EOF
  done
  cat > "$TEST_DIR/${FEATURE}Tests.swift" <<EOF
import XCTest
${TESTABLE_IMPORT}

final class ${FEATURE}PlaceholderTests: XCTestCase {
    func test_todo() {
        // TODO(agent): write a real test against a fake dependency once the
        // ${ARCHITECTURE} layer files above are implemented (§4.1, §8.2).
        XCTFail("TODO: implement ${FEATURE}'s ${ARCHITECTURE} layers and this test")
    }
}
EOF
fi

# ---------------------------------------------------------------------------
# Localization (§3.7, §3.11) — never a hardcoded string literal.
# ---------------------------------------------------------------------------
if [ "$DETERMINISTIC" -eq 1 ]; then
  mkdir -p "$LOC_DIR/en.lproj"
  STRINGS_FILE="$LOC_DIR/en.lproj/Localizable.strings"
  [ -f "$STRINGS_FILE" ] || touch "$STRINGS_FILE"
  {
    echo "\"${TARGET_MODULE_LOWER}.${FEATURE_LOWER}.title\" = \"${FEATURE}\";"
    echo "\"${TARGET_MODULE_LOWER}.${FEATURE_LOWER}.empty\" = \"Nothing here yet.\";"
  } >> "$STRINGS_FILE"
  ./Scripts/generate_strings.sh "$TARGET_MODULE" || true
fi

echo "new_feature.sh: created $FEATURE_DIR (module: $TARGET_MODULE, topology: $TOPOLOGY)."
if [ "$HAS_NETWORKING" -eq 0 ]; then
  echo "new_feature.sh: networking='none' — the data layer's BODY is a TODO(agent) stub and its test is a failing placeholder (§1.4). Everything else (folder, Models, LocalStore, registration, localization) is generated. Implement the local-only read, then replace the placeholder test."
fi
if [ -n "$GROUP_PATH" ]; then
  echo "new_feature.sh: nested under group '$GROUP_PATH' (§3.2)."
fi
