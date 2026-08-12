---
name: start
description: First-run setup for a new iOS project from this template — asks the architecture questionnaire, validates the answers, and scaffolds a real, compiling app via XcodeGen/Tuist. Idempotent on re-run. This is the ONLY Skill that runs without ios-skeleton.config.json already present.
---

# /start

This is Phase B of the template (see the template repo's own `README.md`/§0 of
the build spec). Everything below runs inside a **real project** — either
cloned/copied from the template, or an existing repo being adopted (Path 3).

## 0. First move: check for `ios-skeleton.config.json`

- **Absent** → go to §1 (first-run flow).
- **Present** → go to §4 (idempotent re-run).

Never fall back to a guessed architecture or a "reasonable default" before real
answers are recorded — there is no such thing before this Skill has run once.

---

## 1. First-run flow

### 1.1 Detect Path 3 before anything else

If an `.xcworkspace` or `.xcodeproj` already exists on disk that no spec file
(`project.yml`/`Project.swift`) describes, this is **Path 3 — adoption**, not a
greenfield run. Do not scaffold as if the repo were empty. Detect the existing
project set, infer the topology tier from its shape (one project → T1/T2-ish;
workspace with several → T3), and confirm your inferred topology with the
developer before writing anything. Then follow the same steps below, but:

- Skip generating a spec file for anything that already has one.
- Never regenerate or overwrite a hand-maintained `.xcodeproj`/`.xcworkspace` —
  converting one to a generated spec is an explicit, separate migration the
  developer opts into, not something this run does silently.
- Write a `TODO.md` entry naming each existing project not yet described by a
  spec file.

### 1.2 Ask the Setup Questionnaire — one batched interaction

Ask all twelve questions together (via `AskUserQuestion` where the option shape
fits, or as one consolidated prompt otherwise) — never one question per turn.
Tell the developer they can say "use the recommended defaults" and you'll fill
in the rest.

| # | Question | Options | Recommended default |
|---|---|---|---|
| 1 | Project topology & modularization, and how many apps now/within a year | T1 single `.xcodeproj` / T2 `.xcodeproj` + local Swift packages / T3 `.xcworkspace` + N projects | T2 for one app; T3 the moment a second app, extension, or separately-versioned SDK is on the roadmap |
| 2 | Language | Swift / Swift + Objective-C interop | Swift-only |
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
- Objective-C interop + MV pattern → flag as unusual (MV leans on Swift-only
  `@Observable`), confirm intent.
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
  "language": "swift|swift-objc",
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
- Wire the pre-commit hook: `git config core.hooksPath .githooks`.

### 1.7 Materialize the folder tree

For each app (usually one), render the app-shell templates from
`Scripts/templates/mvvm-swiftui-navigationstack/app-shell/*.template` into
`<app.path>/` (or `<app.path>/Sources/App/` at T3), substituting:

- `__APP_NAME__` → the app's real name (from Q12/`apps[].name`).
- `__MODULE_IMPORTS__` → empty at T1; the resolved `import Models` /
  `import Networking` / `import DesignSystem` lines at T2/T3, per the same
  role-resolution logic `Scripts/new_feature.sh` uses (only `App.swift.template`
  needs `import Networking` for `RequestBuilder`/`APIClient`; the rest of the
  app-shell files are self-contained).

This is the **only** time these files are rendered from scratch — after this,
`Route.swift`/`App.swift`'s markers are owned by `Scripts/new_feature.sh`;
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
`Home` is just the recommended placeholder name.) This populates
`Route.swift`'s and `App.swift`'s insertion-point markers automatically.

Then do the **one** substitution that isn't marker-driven: in `App.swift`,
replace the placeholder root view —

```swift
// MARK: starter-feature-root-view-insertion-point
Text("Replace with the starter feature's root view — see /start")
```

— with a call to the factory `new_feature.sh` just generated
(`makeHomeView()`), and delete the marker comment (it only ever applies once).

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
template (which described the template system itself, not this app).

### 1.10 Report what's left

Write `TODO.md` with what can't be automated: the real API base URL (already
flagged inline in `App.swift`), opening the project once in Xcode, per-app
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
