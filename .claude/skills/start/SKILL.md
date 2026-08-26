---
name: start
description: First-run setup for a new iOS project from this template — asks the architecture questionnaire, validates the answers, and scaffolds a real, compiling app via XcodeGen/Tuist. Takes an optional target path and copies the template's own files into it automatically (merge-only, never overwriting anything already there) — no manual `cp -r` step. Idempotent on re-run. This is the ONLY Skill that runs without ios-skeleton.config.json already present.
model: opus
effort: high
---

# /start `[path]`

This is Phase B of the template (see the template repo's own `README.md`/§0 of
the build spec). Everything below runs inside a **real project** — either
cloned/copied from the template, or an existing repo being adopted (Path 3) —
resolved from an optional `path` argument instead of requiring a manual
`cp -r` first.

## 0. Resolve the target path and copy the template's files in

- **No `path` given** — the target is the current directory. There's nothing
  to copy (either this is a direct clone of the template, or its files were
  already copied in by hand) — go straight to the config check below.
- **`path` given** — resolve it relative to the current directory, creating
  the directory if it doesn't exist yet. Then copy this template's `.claude/`,
  `Scripts/`, `docs/`, `.swiftlint.yml`, `.githooks/`, `.gitignore`,
  `CLAUDE.md.template`, and `README.md` into it.
  - **This copy is a merge, never an overwrite.** Walk it file-by-file, not
    folder-by-folder: copy a file only if the destination doesn't already have
    one at that path; if it does, leave it untouched. This is what makes it
    safe to point `path` directly at a mature, already-shipping project —
    `docs/CODING_STANDARDS.md`, `CLAUDE.md.template`'s eventual render target,
    and `README.md` on an adopted repo are the developer's own history, not
    this template's boilerplate, and a folder-level `cp -r` would clobber
    them.
  - Every step from here on operates on this resolved target path, not
    necessarily the directory this Skill was invoked from.
- **Check for `ios-skeleton.config.json`** at the resolved path:
  - **Absent** → go to §1 (first-run flow).
  - **Present** → go to §4 (idempotent re-run).

Never fall back to a guessed architecture or a "reasonable default" before real
answers are recorded — there is no such thing before this Skill has run once.

---

## 1. First-run flow

### 1.1 Detect Path 3 before anything else

If an `.xcworkspace` or `.xcodeproj` already exists at the target path that no
spec file (`project.yml`/`Project.swift`) describes, this is **Path 3 —
adoption**, not a greenfield run — this applies exactly the same way whether
one bare `.xcodeproj` exists or a whole workspace does. Do not scaffold as if
the repo were empty. Detect the existing project set, infer the topology tier
from its shape (one `.xcodeproj` with no local packages → T1; one `.xcodeproj`
plus local Swift packages → T2; workspace with several projects → T3), and
confirm your inferred topology with the developer before writing anything.
Then follow the same steps below, but:

- Skip generating a spec file for anything that already has one.
- Never regenerate or overwrite a hand-maintained `.xcodeproj`/`.xcworkspace` —
  converting one to a generated spec is an explicit, separate migration the
  developer opts into, not something this run does silently.
- Record the deployment target actually set on the existing project's build
  settings as `minIOSVersion`, instead of asking §1.2's Q8 picklist (16/17/18)
  — an adopted project may already sit below that floor, and every §1.3
  validation rule involving SwiftData/`@Observable`/`NavigationStack` must
  check against the real number, not the picklist default.
- Detect the existing feature-folder convention (`Features/`, `Scenes/`,
  `Modules/`, ...) and record its name in the config instead of assuming
  `Features/`. `Scripts/new_feature.sh` must read this field rather than
  hardcode the name — otherwise adoption produces a second, inconsistent
  folder alongside the one already in use.
- If the detected architecture/UI-framework/navigation combination isn't one
  of the four fully-templated combos (§1.7's table), say so plainly during
  this confirmation — don't let it surface for the first time only when
  `/new-feature` falls back mid-run.
- Before wiring `.githooks/pre-commit`/`commit-msg` (§1.6), run
  `Scripts/lint.sh`, `check_hardcoded_colors.sh`, `check_strings.sh`, and
  `check_secrets.sh` once against the adopted codebase as a dry run. If any fail, report the failures
  and ask whether to fix them first or wire the hooks in report-only mode
  instead — an adopted codebase has never been checked against these
  conventions, and a hard-blocking hook can lock the developer out of their
  very next commit.
- **Offer the String Catalog migration; never perform it unasked.** An adopted
  project very likely uses per-locale `<locale>.lproj/Localizable.strings`.
  `check_strings.sh` warns and skips such a module rather than failing, so
  nothing is blocked — but `/translate` and `generate_strings.sh` only operate on
  a catalog, so those Skills stay unavailable until it's migrated. Say that
  plainly and offer `Scripts/migrate_strings_to_catalog.sh [<module>]`, which
  preserves every existing translation and comment, then needs a regenerate. If
  the developer declines, record it in `TODO.md` and move on — a working
  localization setup is exactly the kind of thing adoption promises not to
  rewrite underneath someone.
- Before rendering `CLAUDE.md`/`README.md`/`docs/ONBOARDING.md` (§1.9), check
  whether each already exists with real content (no leftover `{{placeholder}}`
  tokens; predates this run's `ios-skeleton.config.json`). If so, do not
  overwrite it — write the rendered version to a side file, or skip it and
  note the gap in `TODO.md`, and ask the developer how to reconcile it
  manually. `docs/ai/architecture.md`/`modularization.md` are still safe to
  render fresh, since an adopted repo never had them before.
- An adopted repo may already keep product documentation (a PRD, an SRS, API
  contracts) somewhere. Never move, rewrite or absorb it. Either point
  `docs/product/README.md` at where it already lives, or leave it alone entirely
  and note the location in `docs/PROJECT_MAP.md` — §1.9's product-docs step is
  create-if-missing, never overwrite.
- Write a `TODO.md` entry naming each existing project not yet described by a
  spec file.

### 1.2 Ask the Setup Questionnaire — one batched interaction

Ask all eleven actual questions together (Q2/Language is fixed at Swift-only —
nothing to ask) via `AskUserQuestion` where the option shape fits, or as one
consolidated prompt otherwise — never one question per turn. Tell the
developer they can say "use the recommended defaults" and you'll fill in the
rest.

| # | Question | Options | Recommended default |
|---|---|---|---|
| 1 | Project topology & modularization, and how many apps now/within a year | T1 single `.xcodeproj` / T2 `.xcodeproj` + local Swift packages / T3 `.xcworkspace` + N projects | T2 for one app; T3 the moment a second app, extension, or separately-versioned SDK is on the roadmap |
| 2 | Language | Swift only — fixed, not asked (Objective-C interop was considered and dropped; nothing here scaffolds it) | Swift-only |
| 3 | UI framework | SwiftUI / UIKit / Hybrid | SwiftUI |
| 4 | Persistence | SwiftData / Core Data / None (no on-device copy) | SwiftData |

| 5 | Architecture pattern | MVVM / MVC / VIP (Clean Swift) / VIPER / MV (SwiftUI-native) | MVVM |
| 6 | Navigation | `UINavigationController` + Coordinator / SwiftUI `NavigationStack` + Router | Coordinator if any UIKit; either for SwiftUI-only |
| 7 | Networking & concurrency | URLSession+async/await / URLSession+Combine / Alamofire / **None (offline, local-only app)** | URLSession+async/await |
| 8 | Minimum iOS deployment target | 16 / 17 / 18 | 17 |
| 9 | Dependency injection | Manual initializer injection / lightweight container | Manual initializer injection |
| 10 | Testing framework | XCTest / Swift Testing | XCTest |
| 11 | Project generation tooling | XcodeGen / Tuist | XcodeGen at T1/T2; Tuist at T3 if the team will adopt it |
| 12 | Per-app identity | display name, bundle ID, org/team ID (T3 multi-app: ask once per app, plus the shared bundle-ID prefix) | no default — must ask |

Q4 is not a note in the config — it changes generated code. It is **not** an
online-vs-offline choice: the app talks to a remote service either way (that's
Q7). Q4 only decides whether a feature also keeps a copy on the device. Frame it
that way, and never describe either answer as "an offline app":

- **`SwiftData` / `Core Data`** — the remote service stays; each feature
  additionally gets a `<Feature>LocalStore` next to its remote dependency, and
  the app gets one `PersistenceController` (§1.7a). That local copy is what
  powers offline reads, caching and fast cold starts — a connected app that
  degrades gracefully, not a disconnected one. SwiftData generates the
  `LocalStore` bodies end to end; Core Data wires the seam but leaves the bodies
  as `TODO(agent)` and needs a `.xcdatamodeld` added by hand.
- **`None`** — no local copy: every feature reads straight from the network
  every time, so a screen has nothing to show when the connection drops. No
  `LocalStore` anywhere, no `PersistenceController`. (If networking is also
  `None`, features have no data layer at all — see §1.3.)

Say this when asking, because it's the one answer that's cheap now and a
per-feature edit later.

Answer Q1 **honestly, not aspirationally** — "one app, but we might extract an
SDK someday" is T2. Choosing T3 for one app with nothing concrete on the
roadmap buys a second file to keep in sync and nothing else.

### 1.3 Validate before scaffolding anything

Stop and re-ask on any of these rather than silently picking a fallback:

- SwiftData or MV (`@Observable`) chosen with deployment target < iOS 17.
- `NavigationStack` routing chosen with deployment target < iOS 16.
- UI framework = UIKit **and** navigation = `NavigationStack` → **invalid**,
  `NavigationStack` is SwiftUI-only. Ask the developer to pick Coordinator or
  switch the UI framework.
- UI framework = SwiftUI **and** navigation = Coordinator → **valid**, but
  document in the rendered `docs/ai/architecture.md` that every screen is
  hosted via `UIHostingController` and pushed through the Coordinator, never a
  SwiftUI `NavigationLink` in the same app.
- Networking = `None` **and** persistence = `None` → **stop and ask.** This isn't
  a contradiction — a calculator, a converter or a drawing app genuinely has
  neither, and its features are a View plus a ViewModel with no data layer at
  all. It's outside what the templates cover: every feature scaffold generates a
  data layer of some kind, so there'd be nothing for `/new-feature` to put in it.
  Say that plainly, and let the developer either pick a persistence stack or
  accept that features will be hand-written from `docs/ai/architecture.md`.
- Topology = T1 **and** more than one app declared → **invalid** — stop and
  re-ask; two apps need at least T2, realistically T3.
- Topology = T3 **and** one app **and** nothing concrete on the roadmap →
  flag as likely over-engineering, confirm intent. If a second app/SDK genuinely
  is on the roadmap, T3-with-one-app is correct — don't challenge it.
- Topology = T3 **and** tooling = XcodeGen → valid, but say plainly that the
  workspace file comes from `Scripts/generate_workspace.sh`, not XcodeGen
  itself, and that adding a project later means a spec edit **and** re-running
  that script.

### 1.4 Write `ios-skeleton.config.json`

Record every answer. This is the schema every Script and Skill in this
template reads — keep it exactly this shape:

```json
{
  "topology": "T1|T2|T3",
  "language": "swift",
  "uiFramework": "SwiftUI|UIKit|Hybrid",
  "persistence": "SwiftData|CoreData|None",
  "architecture": "MVVM|MVC|VIP|VIPER|MV",
  "navigation": "navigationstack|coordinator",
  "networking": "urlsession-async|urlsession-combine|alamofire|none",
  "minIOSVersion": "16|17|18",
  "di": "manual|container",
  "testing": "XCTest|SwiftTesting",
  "tooling": "xcodegen|tuist",
  "product": "<Product>",
  "defaultModule": "<AppName>",
  "sharedModuleName": "Shared",
  "apps": [
    { "name": "<AppName>", "path": "App", "bundleId": "...", "team": "..." }
  ],
  "modules": [
    { "name": "Models", "kind": "package|framework", "path": "Packages/Models", "role": "models" },
    { "name": "Networking", "kind": "package|framework", "path": "Packages/Networking", "role": "networking" },
    { "name": "DesignSystem", "kind": "package|framework", "path": "Packages/DesignSystem", "role": "designsystem" },
    { "name": "Core", "kind": "package|framework", "path": "Packages/Core", "role": "core" }

  ]
}
```

- At **T1**: omit `modules` entirely (or leave it empty) — there is no package
  boundary; `Models`/`Networking`/`DesignSystem`/`Core` are plain folders inside
  `apps[0].path` (conventionally `"App"`).
- At **T2**: `apps[0].path` is `"App"`; each module's `path` is
  `Packages/<Name>` (source lives at `<path>/Sources/<Name>`).
- At **T3**: `apps[].path` is the real per-app folder name (from Q12); modules
  with `role` set are separate projects/packages; if a role has no dedicated
  module entry, `Scripts/new_feature.sh` and `Scripts/generate_strings.sh` fall
  back to `sharedModuleName`'s `Sources/<Role>` — this is a documented
  best-effort at T3 for the default combo (§1.4/§10 of the build spec).
- `"role": "logging"` is legal but unused at first run: `/start` puts `Log.swift`
  in `Core` at every tier (§1.7b). It matters once a team runs
  `/add-module Logging` and moves the file — `resolve_role` then finds it there
  instead, with nothing else to change.
- `defaultModule` is required whenever there's more than one app/module
  candidate — every Skill refuses to guess without it (§4's topology branch).

### 1.5 Generate the spec file(s) and the real project

- T1/T2: one `project.yml` (or `Project.swift` for Tuist) at repo root.
- T3: one spec **per project** (app or framework), plus the workspace.
- Run `xcodegen generate` once per spec (or `tuist generate`). Any later step
  that adds a file or folder to disk needs another run before the build sees it
  — this is the rule `docs/ONBOARDING.md` documents for the developer, and it
  applies to this Skill's own remaining steps too.
- At T3, also run `Scripts/generate_workspace.sh` — XcodeGen has no
  workspace-generation flag; this template owns that file.
- **No manual Xcode step at any point.**

### 1.5a Wire configuration and secrets — always

Two files, at the resolved repo root:

- **Make the ignore rule true before creating anything ignorable.** §0's copy is
  skipped when the destination already has a `.gitignore` — which an adopted repo
  (Path 3) always does, and it won't mention `Secrets.xcconfig`. So: if a
  `.gitignore` exists at the target, **append** any missing entries from the
  build spec's §8.8 list (`xcuserdata/`, `.DS_Store`, build products,
  `Secrets.xcconfig`, compiled tool binaries) to it — appending is safe where a
  whole-file copy isn't. Say what you appended in §1.10's report.
- Copy `Scripts/templates/config/Secrets.xcconfig.example` to
  `Secrets.xcconfig.example` unconditionally — it's committed by design. Copy it
  to `Secrets.xcconfig` **only after** the ignore entry above is in place, and
  only if that file doesn't already exist. Creating a live secrets file in a repo
  that doesn't ignore it means the first developer to fill it in commits a
  secret; that ordering is the whole point of this step.
- In the spec file(s) from §1.5, point **each app target's** configurations at it
  (`configFiles:` in `project.yml`, `settings(configurations:)` in Tuist).
  `Secrets.xcconfig` is worth having on any project — environment-varying values
  aren't only URLs — so this half is unconditional.
- **`APIBaseURL` only when Q7 isn't `None`.** On a networked project, surface
  `API_BASE_URL` into each app target's `Info.plist` as `APIBaseURL` via
  `$(API_BASE_URL)`; this is not optional, because `AppEnvironment` (§1.7c) reads
  that key from `Bundle.main` and `preconditionFailure`s without it — a missing
  entry is a launch crash, not a silent fallback, and no `Service` ever holds a
  literal URL (§3.7). On a `networking: none` project, **don't add the key, and
  skip §1.7c**: the app shell's `__IF_NETWORKING__` block drops out entirely (see
  §1.7), so there's no `RequestBuilder` to feed. Strip
  `API_BASE_URL` from the rendered `Secrets.xcconfig`/`.example` too, rather than
  leaving a key nothing reads.

After both files exist, **run `Scripts/check_secrets.sh` once** and report the
result in §1.10. It is the commit-time counterpart to `AppEnvironment`'s
launch-time guard: it fails on an empty value, on key drift between
`Secrets.xcconfig` and `.example`, and on an `API_BASE_URL` without a scheme and
host — the last of which catches the `//`-comment truncation the `$()` escape
exists for. On a fresh `/start` it passes, because the file was just copied from
the example; a failure here means something else in this step went wrong. It also
passes by design on an offline project, where `API_BASE_URL` was stripped.

### 1.6 Git

- `git init` if `.git` doesn't exist.
- If this folder came from cloning the template directly, **offer** — don't
  silently do — to detach it from the template's own git history/remote
  (`rm -rf .git && git init`, or an orphan-branch approach) so the new app
  starts with clean history.
- Wire the hooks: `git config core.hooksPath .githooks` (covers both
  `pre-commit` and `commit-msg` — the latter mechanically checks
  `docs/GIT_CONVENTIONS.md`'s message format, §7/§10).

### 1.7 Materialize the folder tree

**Resolve the combo folder first, from Q3/Q5/Q6's answers (§1.4 of the build
spec):**

| Architecture (Q5) | UI framework (Q3) | Navigation (Q6) | Combo folder |
|---|---|---|---|
| MVVM | SwiftUI | NavigationStack | `mvvm-swiftui-navigationstack` |
| VIP | SwiftUI | NavigationStack | `vip-swiftui-navigationstack` |
| VIP | UIKit | Coordinator | `vip-uikit-coordinator` |
| MVC | UIKit | Coordinator | `mvc-uikit-coordinator` |
| *(anything else)* | — | — | no app-shell template exists — hand-write the composition root/navigation backbone yourself from `docs/ai/architecture.md`'s rendered description; `Scripts/new_feature.sh` will still fall back to template-assisted per feature (§1.4) |

For each app (usually one), render that combo's `app-shell/*.template` files
into the tree §1.7 materialized — **not all into one folder.** They are grouped
by role, and the destination is the folder that role owns:

| Template(s) | Destination |
|---|---|
| `App.swift` / `AppDelegate.swift` + `SceneDelegate.swift` | `<app.path>/` (or `<app.path>/Sources/App/` at T3) |
| `Route.swift`, `Router.swift`, `AppCoordinator.swift` | `<app.path>/Navigation/` |
| `ColorTokens.swift`, `Typography.swift` | `DesignSystem/Theme/` |
| `LoadingView.swift`, `ErrorView.swift`, `EmptyStateView.swift` | `DesignSystem/Views/` |
| `RequestBuilder.swift`, `APIClient.swift` | `Networking/` |
| `Debouncer.swift` | `Core/Utilities/` |

At T2/T3 the `DesignSystem`, `Networking` and `Core` destinations are the shared
modules of those names, so those files are `public` and the app imports them.

Substitute, in every file rendered above:

- `__APP_NAME__` → the app's real name (from Q12/`apps[].name`).
- `__MODULE_LOWER__` → the lowercased key namespace of the module that owns
  `DesignSystem/Views/` (the app's own namespace at T1, the shared DesignSystem
  module's from T2 onward). The three shared state view templates use it to
  reach `L10n.<module>.common.loading`/`.retry`; leaving it unresolved is a
  build failure, so grep for `__MODULE_LOWER__` across the rendered app before
  moving on, the same way you do for the marker families below.
- **`__IF_PERSISTENCE__` / `__ELSE_PERSISTENCE__` / `__END_PERSISTENCE__`** →
  whole-line block markers, exactly like the ones `Scripts/new_feature.sh`
  resolves in the feature templates — but nothing resolves them here, so **you**
  must. Q4 = SwiftData/Core Data → keep the `__IF_` branch, drop the `__ELSE_`
  branch. Q4 = None → the reverse. Delete all three marker lines either way. A
  rendered app-shell file containing a literal `__IF_PERSISTENCE__` is a broken
  run — grep for `PERSISTENCE__` across the app before moving on.
- **`__IF_NETWORKING__` / `__END_NETWORKING__`** → the same treatment for Q7.
  Not `None` → keep the block's contents. `None` → **delete the block and its
  contents**, which is what removes the `RequestBuilder`/`APIClient` properties
  from an offline app's composition root, and the `apiBaseURL` accessor from
  §1.7c's `AppEnvironment` (which an offline project doesn't get at all). Delete
  the marker lines either way and grep for `NETWORKING__` too — across
  `Core/Configuration/` as well as the app, since `AppEnvironment.swift.template`
  carries this family too. This family has no
  `__ELSE_` branch on purpose: an offline app's composition root needs *nothing*
  in place of the networking properties, and inventing a stub there would be the
  dead code this gate exists to avoid.
- With Q7 = `None`, the composition root no longer needs `import Networking` at
  T2/T3 — drop it rather than importing a module the app never calls into.
  `Networking/` itself still gets materialized (§1.7's tree is fixed): the types
  compile and sit unused, which is deliberate — a project that later adds a
  backend edits its composition root, not its module graph.
- `__MODULE_IMPORTS__` → empty at T1; the resolved `import Models` /
  `import Networking` / `import DesignSystem` lines at T2/T3, per the same
  role-resolution logic `Scripts/new_feature.sh` uses (only the composition-root
  file — `App.swift.template` for the SwiftUI combos, `SceneDelegate.swift.template`
  for the UIKit combos — needs `import Networking` for `RequestBuilder`/
  `APIClient`; the rest of the app-shell files are self-contained). At T2/T3 the
  composition root also needs `import Core` — §1.7a/§1.7b/§1.7c put
  `PersistenceController`, `Log` and `AppEnvironment` there, and the last of
  those is present on every networked project regardless of Q4 — and at T3 with UIKit, so does
  `AppCoordinator.swift`, since it holds the `PersistenceController` itself.

This is the **only** time these files are rendered from scratch — after this,
the insertion-point markers (`Route.swift`/`App.swift` for the SwiftUI combos;
`AppCoordinator.swift` for the UIKit combos) are owned by `Scripts/new_feature.sh`;
never re-render them on a later `/start` re-run (§4).

Seed each localization-owning module's `Localization/Localizable.xcstrings`
with at least the module's namespace placeholder, then run
`Scripts/generate_strings.sh` with no argument to regenerate every module's
`L10n.swift` — never leave the localization layer unwired, even before the first
feature exists.

A String Catalog is JSON; write a minimal valid one rather than an empty file:

```json
{
  "sourceLanguage" : "en",
  "strings" : {
    "<module>.common.loading" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Loading" } }
      }
    },
    "<module>.common.retry" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Retry" } }
      }
    },
    "<module>.home.title" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Home" } }
      }
    }
  },
  "version" : "1.0"
}
```

The two `common.*` keys are **required**, not decoration: the shared state views
reference `L10n.<module>.common.loading` and `.common.retry`, so the project
doesn't compile without them. Seed the module that owns `DesignSystem/Views/` — the app
at T1, the shared DesignSystem module from T2 onward.

One catalog per resource-owning module, holding every locale for that module —
never per-locale `.lproj/Localizable.strings` folders, which this template
migrated away from (build spec §8.5). `Scripts/lib/xcstrings.py` is the helper
every localization script goes through; use `python3 Scripts/lib/xcstrings.py set
<catalog> <locale> <key> "<value>"` rather than hand-editing JSON if you're
adding entries beyond the seed.

**Also render the shared state views for the project's UI framework** into
`DesignSystem/Views/` — `LoadingView`, `ErrorView` (message + retry) and
`EmptyStateView`. The SwiftUI combos take them from the combo's `app-shell/`
templates; the UIKit combos take the `UIView` subclasses from
`Scripts/templates/<combo>/app-shell/`. Both UI frameworks get all three, in the
same folder, and the starter feature consumes them rather than building its own
spinner (build spec §3.6). A generated project with an empty `DesignSystem/Views/` is a
failed run.

### 1.7a Render the persistence bootstrap — only when Q4 isn't `None`

Skip this whole step for a `persistence: None` project: it gets no
`PersistenceController`, no `LocalStore` in any feature, and no local-store
parameter in any composition root. That is a complete, supported answer, not a
degraded one.

Otherwise render `Scripts/templates/persistence/<swiftdata|coredata>/PersistenceController.swift.template`
into **Core**, at the tier-correct path:

| Tier | Destination |
|---|---|
| T1 | `<app.path>/Core/Persistence/PersistenceController.swift` |
| T2 | `Packages/Core/Sources/Core/Persistence/PersistenceController.swift` |
| T3 | the `role: "core"` module's `Sources/<Name>/Persistence/`, or `sharedModuleName`'s `Sources/Core/Persistence/` if no core module is declared |

- Substitute `__APP_NAME__`. Substitute nothing else.
- **Leave `// MARK: new-feature-model-insertion-point` exactly as it is** (SwiftData
  only) — `Scripts/new_feature.sh` owns that marker and registers one
  `<Feature>Record` per feature there. The schema list is legitimately empty
  between this step and §1.8; the app is never launched in that window.
- Core Data additionally needs two `TODO.md` entries, because a `.xcdatamodeld`
  can't be generated from text (§10): add the data model to the app target, and
  define one entity per feature before that feature's `LocalStore` can do
  anything. Until then the app builds, runs, and behaves exactly like a
  `persistence: None` project — the local reads simply return nothing.

### 1.7b Render the logging module — always, at every tier

Render `Scripts/templates/logging/Log.swift.template` into Core the same way
(`.../Core/Logging/Log.swift`), substituting `__APP_NAME__`.

This is not optional and has no questionnaire answer behind it:
`docs/CODING_STANDARDS.md` forbids `print()` and points at "the Logging module",
and `.swiftlint.yml`'s `no_print_statements` enforces it. Skipping this step
leaves both pointing at nothing on day one. It lives in Core rather than its own
project even at T3 — one file doesn't justify a spec, a workspace entry and a
scheme; a team that later wants independent versioning runs
`/add-module Logging` and moves it, which is why the config schema already
reserves the `logging` role.

### 1.7c Render `AppEnvironment` — the single reader for every key

On any project that has a key — i.e. every `networking` project, where
`API_BASE_URL` exists from day one — render
`Scripts/templates/config/AppEnvironment.swift.template` into **Core**, at the
tier-correct path (the same table §1.7a uses for `PersistenceController`):

| Tier | Destination |
|---|---|
| T1 | `<app.path>/Core/Configuration/AppEnvironment.swift` |
| T2 | `Packages/Core/Sources/Core/Configuration/AppEnvironment.swift` |
| T3 | the `role: "core"` module's `Sources/<Name>/Configuration/`, or `sharedModuleName`'s `Sources/Core/Configuration/` if no core module is declared |

Resolve its `__IF_NETWORKING__` block the way you resolve the app shell's: keep
the `apiBaseURL` accessor on a networked project. On a `networking: none`
project — no keys at all — **skip this step entirely** and let `/add-secret`
render the file on the first key, the way `docs/PERMISSIONS.md` appears on the
first `/add-permission`. Say which of the two happened in §1.10's report.

It goes in the shared module, not the app, so a feature in any module can read
configuration without the app threading it down: `Bundle.main` resolves to the
app bundle even from inside a package or framework. That same fact is why the
type takes an injectable lookup — a package's test bundle has no `APIBaseURL` of
its own.

**Nothing else in the app reads a configuration key.** The composition root
rendered in §1.7 uses `AppEnvironment.current.apiBaseURL` and carries no reader
of its own; `Bundle.main.object(forInfoDictionaryKey:)` appears in this one file
and nowhere else. If you find yourself writing a second reader, the accessor
belongs here instead.

### 1.8 Scaffold the starter feature

Run the same script `/new-feature` uses:

```
Scripts/new_feature.sh Home "title:String"
```

(Adjust the field list if the developer already described a real first screen;
`Home` is just the recommended placeholder name.) This populates the combo's
insertion-point markers automatically — `Route.swift`/`App.swift`'s for the
SwiftUI combos, `AppCoordinator.swift`'s factory marker for the UIKit combos.

**On a `networking: none` project this run does not end green, and that's
expected.** The script generates the starter feature's folder, models, local
store, factory, registration and localization as usual, but its data-layer read
is a `fatalError("TODO(agent): …")` body and its only test is a deliberate
`XCTFail` placeholder (§1.4). Don't paper over either one: don't implement the
read as a guess, and don't delete the failing test to make the suite green.
Report both in §1.10 as the first things the developer (or a follow-up
`/new-feature`-style pass) has to finish, and say plainly that `xcodebuild test`
will fail until then. The app still builds and launches.

Then do the **one** substitution that isn't marker-driven — which file and
what it looks like depends on the combo resolved in §1.7:

- **SwiftUI combos** (`mvvm-swiftui-navigationstack`, `vip-swiftui-navigationstack`):
  in `App.swift`, replace the placeholder root view —
  ```swift
  // MARK: starter-feature-root-view-insertion-point
  Text("Replace with the starter feature's root view — see /start")
  ```
  — with a call to the factory `new_feature.sh` just generated (`makeHomeView()`).
- **UIKit combos** (`vip-uikit-coordinator`, `mvc-uikit-coordinator`): in
  `AppCoordinator.swift`, replace the placeholder root screen inside `start()` —
  ```swift
  // MARK: starter-feature-root-screen-insertion-point
  navigationController.setViewControllers([PlaceholderRootViewController()], animated: false)
  ```
  — with `navigationController.setViewControllers([makeHomeViewController()], animated: false)`,
  and delete the now-unused `PlaceholderRootViewController` type.

Delete the marker comment either way — it only ever applies once.

At T3 with more than one app: repeat this for **each** app, and additionally
generate one shared base view in the shared UI module that every app's starter
feature consumes, so the sharing seam is exercised on day one.

Build and confirm the generated test actually passes — this is a real
`xcodebuild test`/`swift test` run, not an aspiration.

### 1.8b House style for anything you write by hand

Wherever this Skill hand-writes Swift (an off-default architecture combo's
composition root, a layer file with no template behind it), it follows the same
two rules the templates do:

- **Every type, protocol, property and function gets a `///` doc comment** saying
  what it is or does — one line is usually enough, two when it isn't.
- **Nothing in a source file refers to this template.** No spec section numbers,
  no `.template` filenames, no paragraph explaining why the template structures
  things a certain way. That rationale goes in `docs/ai/architecture.md`, which
  §1.9 renders for exactly this purpose. The one exception is a
  "generated — do not edit" banner on genuinely machine-generated output such as
  `L10n.swift`.

See `docs/CODING_STANDARDS.md`, which ships into the project and carries the
full rule.

### 1.9 Render the doc templates

Render `CLAUDE.md.template` → `CLAUDE.md`, `docs/ai/architecture.md.template` →
`docs/ai/architecture.md` (keeping only the section matching the chosen
architecture pattern and navigation approach — delete the others, don't just
comment them out), `docs/ai/modularization.md.template` →
`docs/ai/modularization.md` (keeping only the matching topology section, and
filling in the real module graph table). Every `{{placeholder}}` must be
resolved — an agent reading the rendered file should never see one. Two of
`CLAUDE.md.template`'s placeholders come from Q11 (tooling) rather than from a
questionnaire answer directly: `{{TOOLING_SPEC_FILE}}` is `project.yml` for
XcodeGen and `Project.swift` for Tuist, and `{{TOOLING_GENERATE_COMMAND}}` is
`xcodegen generate` or `tuist generate` to match.

Seed `docs/PROJECT_MAP.md` in the same step — `CLAUDE.md` links to it, so it
must exist before that link is live. There's no `.template` for it; write it
fresh with the three sections the build spec's §5 names, each with its real
day-one content and a one-line note on what appends to it later: any
file/folder not covered by the feature-first convention, the module list with
each module's kind and consumers (empty at T1 — say so rather than omitting the
section), and which architecture combos are template-backed vs. agent-assisted
for the chosen pattern — and, if Q4 chose Core Data, that its per-feature
`LocalStore` is a wired seam with `TODO(agent)` bodies while SwiftData's is
generated end to end (§10). `/add-module` and `/translate` append to this file, so
it must be a real seeded document, not a stub they create on first use.

Also write a fresh `docs/ONBOARDING.md` and `README.md` for **this project**
(not the template) — day-to-day prompting guidance, tech stack, structure,
getting-started, troubleshooting — overwriting the copies that came from the
template (which described the template system itself, not this app). On Path
3 (§1.1), skip this overwrite for any of the three that already existed with
real content before this run — see §1.1's carve-out.

Finally, make sure `docs/product/` exists with the template's own
`docs/product/README.md` in it — the slot every PRD, SRS and API contract lands
in later. Three rules, and they are the opposite of everything else in this
step:

- **Nothing here is rendered.** No `.template`, no placeholder substitution, no
  generated content. Create the folder and the README, stop.
- **Create-if-missing, never overwrite** — on a fresh run, a re-run, and
  especially on Path 3, where the developer may already have product docs.
- **Never summarize its contents into `CLAUDE.md`.** `CLAUDE.md.template` carries
  a pointer row on purpose: these documents change constantly, and a digest of a
  living document is wrong within weeks.

Tell the developer, in your closing message, that requirements go in
`docs/product/` and that `/new-feature` reads them.

### 1.10 Report what's left

Write `TODO.md` with what can't be automated. On a networked project that
starts with the real API base URL — set `API_BASE_URL` in the gitignored
`Secrets.xcconfig` created in §1.5a, not in Swift; `AppEnvironment` (§1.7c) traps
at launch until it resolves, and leaving the key blank fails the same way a
missing key does rather than falling back to anything. Tell the developer to run
`Scripts/check_secrets.sh` after editing it, and to write the URL as
`https:/$()/host` — `//` starts a comment in xcconfig, so the unescaped form
truncates to `https:` and fails the launch guard's host check. On a `networking: none` project there is no base
URL, and the first two entries are instead **the starter feature's data-layer
`TODO(agent)` body and its failing placeholder test** (§1.8) — state that
`xcodebuild test` fails until both are done, so nobody reads the red suite as a
broken scaffold. Either way, also list any `.gitignore` entries you appended in
§1.5a, opening the project once in Xcode, per-app signing, App Store Connect record, push certs, `PrivacyInfo.xcprivacy`, plus
§1.7a's Core Data entries if that was the Q4 answer. Not
just a message that scrolls off-screen — a durable checklist.

In the closing message (not `TODO.md` — it isn't a follow-up, it's how the
project works), point the developer at `/add-secret` for every key after
`API_BASE_URL`: it appends the key to `Secrets.xcconfig` and the committed
example, adds the `$(KEY)` entry to each app's `Info.plist`, and writes the typed
accessor into the `AppEnvironment` §1.7c rendered — so no other file ever reads
`Bundle.main` for configuration.

Add one **optional** entry, phrased as an offer rather than a completed step —
it changes machine-level configuration outside this repo, so never run it as
part of `/start`:

> Optional — let Claude Code use Xcode's own tools (build, test, project
> actions) instead of reconstructing `xcodebuild` invocations. Enable
> **Xcode ▸ Settings ▸ Intelligence ▸ Model Context Protocol ▸ "Allow external
> agents to use Xcode tools"**, then run
> `claude mcp add --transport stdio xcode -- xcrun mcpbridge` once. The project
> must be open in Xcode when an external agent connects.

At T3, add a second entry: Xcode's in-editor agent looks for `CLAUDE.md`
beside the `.xcodeproj`, which is not the repo root once each project sits in
its own folder — decide per project whether to symlink or duplicate a pointer
file.

---

## 4. Idempotent re-run

If `ios-skeleton.config.json` already exists:

1. Print the currently recorded answers first, before asking anything.
2. For each of §1.5–§1.9's steps: skip whatever's already present and correct;
   recreate anything missing (e.g. a docs file someone deleted by accident).
   **`docs/product/` is exempt from "correct":** its contents are hand-authored,
   perpetually incomplete by design, and never regenerated — create the folder
   and `README.md` only if they're missing entirely, and never touch anything
   else in there.
3. If a new answer would change an already-locked decision (e.g. switching
   architecture after real features exist under `Features/`) — **stop and warn
   explicitly**: name what's at risk (existing features won't be retroactively
   migrated), and require explicit confirmation before applying the change.
   Never apply a conflicting change silently.
4. **Changing persistence (Q4) after features exist is the same class of conflict
   as changing architecture** — warn the same way. Switching `None` →
   SwiftData/Core Data does not retrofit a `LocalStore` onto features that
   already exist; it only affects features generated from that point on, and the
   existing ones need the local half added by hand (protocol, store, factory
   argument). Switching the other way leaves orphaned stores and record types
   behind. Name that explicitly and require confirmation; if the developer
   confirms, also render §1.7a's bootstrap if it isn't there yet.
5. **Changing topology (`topology` in the config) is a migration, not an answer
   edit**, and bigger than an architecture change — it moves files between
   targets, rewrites every affected `import`, relocates strings and
   `Package.resolved`, and invalidates existing schemes. Refuse to do it as a
   side effect of a re-run. Instead print the relevant migration path
   (T1→T2, T2→T3, …) from the build spec's cost table, list the concrete moves
   for *this* repo, and tell the developer to run it as a deliberate, reviewable
   change — ideally its own branch, with `/add-module`/`/add-app` doing the
   additive parts.
6. If nothing has changed and nothing is missing, report **"already configured,
   nothing to do"** rather than re-touching files.
