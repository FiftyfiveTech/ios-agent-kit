---
name: start
description: First-run setup for a new iOS project from this template — asks the architecture questionnaire, validates the answers, and scaffolds a real, compiling app via XcodeGen/Tuist. Takes an optional target path and copies the template's own files into it automatically (merge-only, never overwriting anything already there) — no manual `cp -r` step. Idempotent on re-run. This is the ONLY Skill that runs without ios-skeleton.config.json already present.
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
  `Scripts/`, `docs/`, `.swiftlint.yml`, `.githooks/`, `CLAUDE.md.template`,
  and `README.md` into it.
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
  `Scripts/lint.sh`, `check_hardcoded_colors.sh`, and `check_strings.sh` once
  against the adopted codebase as a dry run. If any fail, report the failures
  and ask whether to fix them first or wire the hooks in report-only mode
  instead — an adopted codebase has never been checked against these
  conventions, and a hard-blocking hook can lock the developer out of their
  very next commit.
- Before rendering `CLAUDE.md`/`README.md`/`docs/ONBOARDING.md` (§1.9), check
  whether each already exists with real content (no leftover `{{placeholder}}`
  tokens; predates this run's `ios-skeleton.config.json`). If so, do not
  overwrite it — write the rendered version to a side file, or skip it and
  note the gap in `TODO.md`, and ask the developer how to reconcile it
  manually. `docs/ai/architecture.md`/`modularization.md` are still safe to
  render fresh, since an adopted repo never had them before.
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
| 4 | Persistence | SwiftData / Core Data / None | SwiftData |
| 5 | Architecture pattern | MVVM / MVC / VIP (Clean Swift) / VIPER / MV (SwiftUI-native) | MVVM |
| 6 | Navigation | `UINavigationController` + Coordinator / SwiftUI `NavigationStack` + Router | Coordinator if any UIKit; either for SwiftUI-only |
| 7 | Networking & concurrency | URLSession+async/await / URLSession+Combine / Alamofire | URLSession+async/await |
| 8 | Minimum iOS deployment target | 16 / 17 / 18 | 17 |
| 9 | Dependency injection | Manual initializer injection / lightweight container | Manual initializer injection |
| 10 | Testing framework | XCTest / Swift Testing | XCTest |
| 11 | Project generation tooling | XcodeGen / Tuist | XcodeGen at T1/T2; Tuist at T3 if the team will adopt it |
| 12 | Per-app identity | display name, bundle ID, org/team ID (T3 multi-app: ask once per app, plus the shared bundle-ID prefix) | no default — must ask |

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
  "networking": "urlsession-async|urlsession-combine|alamofire",
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
- `defaultModule` is required whenever there's more than one app/module
  candidate — every Skill refuses to guess without it (§4's topology branch).

### 1.5 Generate the spec file(s) and the real project

- T1/T2: one `project.yml` (or `Project.swift` for Tuist) at repo root.
- T3: one spec **per project** (app or framework), plus the workspace.
- Run `xcodegen generate` once per spec (or `tuist generate`).
- At T3, also run `Scripts/generate_workspace.sh` — XcodeGen has no
  workspace-generation flag; this template owns that file.
- **No manual Xcode step at any point.**

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
into `<app.path>/` (or `<app.path>/Sources/App/` at T3), substituting:

- `__APP_NAME__` → the app's real name (from Q12/`apps[].name`).
- `__MODULE_IMPORTS__` → empty at T1; the resolved `import Models` /
  `import Networking` / `import DesignSystem` lines at T2/T3, per the same
  role-resolution logic `Scripts/new_feature.sh` uses (only the composition-root
  file — `App.swift.template` for the SwiftUI combos, `SceneDelegate.swift.template`
  for the UIKit combos — needs `import Networking` for `RequestBuilder`/
  `APIClient`; the rest of the app-shell files are self-contained).

This is the **only** time these files are rendered from scratch — after this,
the insertion-point markers (`Route.swift`/`App.swift` for the SwiftUI combos;
`AppCoordinator.swift` for the UIKit combos) are owned by `Scripts/new_feature.sh`;
never re-render them on a later `/start` re-run (§4).

Seed each localization-owning module's `Localizable.strings` with at least the
module's namespace placeholder, then run `Scripts/generate_strings.sh` with no
argument to regenerate every module's `L10n.swift` — never leave the
localization layer unwired, even before the first feature exists.

### 1.8 Scaffold the starter feature

Run the same script `/new-feature` uses:

```
Scripts/new_feature.sh Home "title:String"
```

(Adjust the field list if the developer already described a real first screen;
`Home` is just the recommended placeholder name.) This populates the combo's
insertion-point markers automatically — `Route.swift`/`App.swift`'s for the
SwiftUI combos, `AppCoordinator.swift`'s factory marker for the UIKit combos.

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

### 1.9 Render the doc templates

Render `CLAUDE.md.template` → `CLAUDE.md`, `docs/ai/architecture.md.template` →
`docs/ai/architecture.md` (keeping only the section matching the chosen
architecture pattern and navigation approach — delete the others, don't just
comment them out), `docs/ai/modularization.md.template` →
`docs/ai/modularization.md` (keeping only the matching topology section, and
filling in the real module graph table). Every `{{placeholder}}` must be
resolved — an agent reading the rendered file should never see one.

Also write a fresh `docs/ONBOARDING.md` and `README.md` for **this project**
(not the template) — day-to-day prompting guidance, tech stack, structure,
getting-started, troubleshooting — overwriting the copies that came from the
template (which described the template system itself, not this app). On Path
3 (§1.1), skip this overwrite for any of the three that already existed with
real content before this run — see §1.1's carve-out.

### 1.10 Report what's left

Write `TODO.md` with what can't be automated: the real API base URL (already
flagged inline in `App.swift`/`SceneDelegate.swift`), opening the project once in Xcode, per-app
signing, App Store Connect record, push certs, `PrivacyInfo.xcprivacy`. Not
just a message that scrolls off-screen — a durable checklist.

---

## 4. Idempotent re-run

If `ios-skeleton.config.json` already exists:

1. Print the currently recorded answers first, before asking anything.
2. For each of §1.5–§1.9's steps: skip whatever's already present and correct;
   recreate anything missing (e.g. a docs file someone deleted by accident).
3. If a new answer would change an already-locked decision (e.g. switching
   architecture after real features exist under `Features/`) — **stop and warn
   explicitly**: name what's at risk (existing features won't be retroactively
   migrated), and require explicit confirmation before applying the change.
   Never apply a conflicting change silently.
4. **Changing topology (`topology` in the config) is a migration, not an answer
   edit**, and bigger than an architecture change — it moves files between
   targets, rewrites every affected `import`, relocates strings and
   `Package.resolved`, and invalidates existing schemes. Refuse to do it as a
   side effect of a re-run. Instead print the relevant migration path
   (T1→T2, T2→T3, …) from the build spec's cost table, list the concrete moves
   for *this* repo, and tell the developer to run it as a deliberate, reviewable
   change — ideally its own branch, with `/add-module`/`/add-app` doing the
   additive parts.
5. If nothing has changed and nothing is missing, report **"already configured,
   nothing to do"** rather than re-touching files.
