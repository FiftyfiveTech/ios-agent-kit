# iOS AI-Optimized Skeleton — Template Build Prompt

**Audience:** an AI coding agent operating in a repo (Claude Code, Codex, etc.), starting in **Plan Mode**.
**Goal:** build a reusable **template repository** — tooling only, no app yet — that any future iOS project can clone or copy from. The template's own `/start` Skill is what later asks the architecture questions and scaffolds an actual, compiling app from scratch. This mirrors an existing Android AI-optimized skeleton's philosophy (deterministic scaffolding, auto-loaded meta-files, enforced lint/style, Skills for routine work).

---

## 0. Two-phase model — read this before doing anything

**Phase A (now, this execution):** build the template repo. It contains Skills, scripts, doc templates, lint config — nothing app-specific. **No Xcode project exists yet. No architecture has been chosen. This execution never asks the Setup Questionnaire itself.**

**Phase B (later, per real project):** the `/start` Skill — shipped inside Phase A's output — asks the Setup Questionnaire and builds a real, compiling app from scratch via XcodeGen/Tuist, no manual Xcode step. It can run in a completely different session, months later, against a project that started life either by cloning the template repo directly or by copying its files into an existing folder.

`/start` takes one optional argument, a target path, and does its own copying — there is no manual `cp -r` step:

```
/start [path]
```

- **No `path`** — operate on the current directory, exactly as it always has. This is what running `/start` from inside a direct clone of the template repo looks like (`git clone <template-repo-url> MyNewApp && cd MyNewApp && /start`), and it's still what happens if someone copied the template's files in by hand before invoking it.
- **A `path`** — `/start` resolves it (creating the directory if it doesn't exist yet), inspects what's there, copies the template's own files into it itself (§2.1's resolve-and-copy step, merge-only — it never overwrites a file already at the destination), and then continues exactly as a no-argument run would, from inside that directory:
  - **Missing, or exists but is effectively empty** (nothing there besides maybe `.git`) → fresh start.
  - **Already contains an `.xcodeproj`/`.xcworkspace`** that no spec file describes → adoption (§2.1 step 13) — this covers a single already-shipping `.xcodeproj` exactly as much as a multi-project workspace; the trigger is "a project already exists that no spec file describes," not "more than one project exists" (§3.9 infers the tier from what's actually found).
  - **Already has `ios-skeleton.config.json`** → already initialized; skip straight to the idempotent re-run (§2.4).

This single command replaces what used to be three separate manual recipes (clone-as-root / copy-into-an-empty-folder / copy-into-an-existing-project) — the underlying scenarios are unchanged, only the manual file-copying step goes away. Adoption still matters for the same reason it always did: the realistic destination for this template is not always a greenfield app — see §8, whose baseline is drawn from how long-lived production apps are actually structured. `/start` records what already exists into `ios-skeleton.config.json` and generates only what's missing; it never rewrites a hand-maintained `.xcodeproj` it didn't create (§2.3, §3.10), and — because an adopted repo's `CLAUDE.md`/`README.md`/`docs/` are almost always hand-authored project history rather than template boilerplate — the copy step and the doc-rendering step both refuse to overwrite anything already there without asking first (§2.1's resolve-and-copy step and step 13's carve-out).

**What this means concretely for this execution:** stay in Plan Mode, produce the plan for §1's tree only, do not write `project.yml`, do not create `App/`/`Features/`, do not ask about topology/Swift/SwiftUI/architecture/etc. — all of that is Phase B's job, specified in §2 for you to build *into* the `/start` Skill, not to perform now.

---

## 1. Phase A Deliverable: the Template Repo

### 1.1 Folder tree (what this execution actually creates)

```
ios-ai-skeleton/                      # rename per team convention — this IS Phase A's deliverable
├── .claude/skills/
│   ├── start/                        # §2 — asks questions, scaffolds a real app from scratch
│   ├── new-feature/                  # §4.1 — guarded, see §1.3
│   ├── add-assets/                   # §4.2
│   ├── update-app-icon/              # §4.3
│   ├── add-permission/               # §4.4
│   ├── update-theme/                 # §4.5
│   ├── status/                       # §4.6
│   ├── add-module/                   # §4.7 — new shared package/framework, wired into every consumer
│   ├── add-app/                      # §4.8 — second app in the same workspace, reusing shared modules
│   ├── translate/                    # §4.9 — drafts target-locale .strings entries for human review
│   └── add-secret/                   # §4.10 — config key → Secrets.xcconfig + Info.plist + AppEnvironment; refuses live credentials
├── Scripts/
│   ├── new_feature.sh                # deterministic for the default stack, template-assisted otherwise — §1.4
│   ├── new_module.sh                 # §4.7 — creates a module's spec + folders, deterministic at every tier
│   ├── generate_workspace.sh         # §3.9 — emits <Name>.xcworkspace/contents.xcworkspacedata from config
│   ├── templates/                    # per-architecture file templates new_feature.sh selects from
│   │   ├── mvvm-swiftui-navigationstack/   # fully-authored, deterministic — see §1.4
│   │   ├── vip-swiftui-navigationstack/    # fully-authored, deterministic — ViewModel bridge (§1.4)
│   │   ├── vip-uikit-coordinator/          # fully-authored, deterministic — classic Clean Swift (§1.4)
│   │   ├── mvc-uikit-coordinator/          # fully-authored, deterministic — ViewController only (§1.4)
│   │   ├── persistence/                    # §3.8 — the OPTIONAL local half of the data layer
│   │   │   ├── swiftdata/                  # PersistenceController + per-feature LocalStore + @Model record
│   │   │   └── coredata/                   # PersistenceController + a LocalStore seam (§10)
│   │   ├── logging/                        # §8.6 — Log.swift, rendered into Core at every tier
│   │   └── config/                         # §8.3 — Secrets.xcconfig.example, rendered to repo root
│   ├── check_hardcoded_colors.sh     # §7 — theming enforcement
│   ├── check_strings.sh              # §8.5 — missing/untranslated/duplicate keys across locales and modules
│   ├── check_secrets.sh              # §8.3 — empty values, key parity, API_BASE_URL shape
│   ├── generate_strings.sh           # §3.7 — regenerates each module's L10n.swift from its Localizable.xcstrings
│   ├── migrate_strings_to_catalog.sh # §8.5 — one-way .strings → String Catalog migration, for adopted projects
│   ├── lib/xcstrings.py              # §8.5 — the one place that knows the .xcstrings format
│   └── lint.sh                       # §7 — swiftlint wrapper
├── .swiftlint.yml
├── .gitignore                            # §8.8's always-ignore list, incl. Secrets.xcconfig — /start copies it in
├── .githooks/
│   ├── pre-commit
│   └── commit-msg                    # §7 — enforces docs/GIT_CONVENTIONS.md's message format
├── docs/
│   ├── ONBOARDING.md                 # how to use *this template* — §1.2
│   ├── CODING_STANDARDS.md
│   ├── GIT_CONVENTIONS.md
│   ├── product/
│   │   └── README.md                 # §5.2 — the domain slot: PRD/SRS/API land here later
│   └── ai/
│       ├── architecture.md.template  # generic multi-pattern reference — /start renders the one chosen pattern
│       ├── modularization.md.template # §3.9–§3.11 — /start renders the chosen tier's module graph + ownership rules
│       ├── theming_rules.md
│       ├── ui_rules.md
│       └── permissions_rules.md
├── CLAUDE.md.template                # /start renders this into a real CLAUDE.md with locked-in decisions
└── README.md                         # describes the template system, not any one app
```

Deliberately absent at this stage: `project.yml`, any `.xcworkspace`, `App/`, `Core/`, `Networking/`, `DesignSystem/`, `Features/`, `ios-skeleton.config.json`. None of these exist until `/start` runs — see §2 and §3.

### 1.2 What the template's own `README.md`/`docs/ONBOARDING.md` must say

The `/start [path]` invocation from §0 and its three detected scenarios (fresh/empty, adoption, already-initialized), spelled out for a human reading this repo for the first time, plus: what `/start` does, that it's idempotent (§2.4), the three topology tiers and the honest cost of moving between them (§3.9–§3.10), and a pointer to `docs/ai/architecture.md.template` explaining that the real architecture doc doesn't exist until `/start` renders it. State the adoption scenario's scope plainly rather than letting it read as workspace-only: a single mature `.xcodeproj` with its own hand-written `CLAUDE.md`/`README.md` and years of history is exactly what it's for, not just a multi-project workspace. Also state where the *domain* goes: this template describes how an app is built, never what it's for, and `docs/product/` (§5.2) is the slot a PRD/SRS/API contract lands in later — a living, never-final set of documents nothing here generates or overwrites.

### 1.3 Shared precondition for every Skill except `/start`

Every Skill other than `/start` checks for `ios-skeleton.config.json` at repo root before doing anything. Missing → refuse with a message like *"This project hasn't been initialized yet — run `/start` first."* Never falls back to a guessed architecture or a "reasonable default" — there is no such thing before `/start` has recorded real answers.

### 1.4 Deterministic vs. template-assisted feature generation — an honest scoping call

Authoring a literal, byte-for-byte code template for every architecture × UI-framework × navigation-approach combination in §3 is a real, ongoing cost — don't pretend one prompt makes all of them free. Scope Phase A's authoring effort like this:

- **Fully deterministic, zero LLM tokens — four combinations:**
  - **MVVM + SwiftUI + `NavigationStack` + SwiftData** (the recommended default). `Scripts/templates/mvvm-swiftui-navigationstack/` — View, ViewModel, Repository, Service (§3.8; no `UseCase` — see §3.8's note).
  - **VIP + SwiftUI + `NavigationStack`.** `Scripts/templates/vip-swiftui-navigationstack/` — View, **ViewModel**, Interactor, Presenter, Router, Worker. SwiftUI Views are value types and cannot hold a weak reference, so classic VIP's `weak var displayLogic` sits on a thin `@Observable` ViewModel bridge instead of the View directly — the Presenter still never calls back into the Interactor, and the ViewModel still contains no formatting or business logic, exactly as in the UIKit variant below. (This shape is evidence-based, not invented for this template — see the production reference in §8's baseline note.)
  - **VIP + UIKit + Coordinator.** `Scripts/templates/vip-uikit-coordinator/` — classic Clean Swift: View(Controller), Interactor, Presenter, Router, Worker. The ViewController conforms to `XDisplayLogic` directly (it's already a reference type), so no ViewModel bridge is needed here. Per-scene `Router.swift` (VIP's own navigation object — see the naming note below) hands off the actual push to the app-wide `Coordinator` (§3.4) rather than owning a `UINavigationController` itself.
  - **MVC + UIKit + Coordinator.** `Scripts/templates/mvc-uikit-coordinator/` — `<Name>ViewController.swift` only (§3.3). No SwiftUI variant: a "SwiftUI MVC" has no real controller layer to template and would just duplicate the MV pattern (§3.3's MV row already covers that shape).
  - **VIPER is deliberately not given its own template.** It differs from VIP only by removing VIP's `weak` ViewController/ViewModel reference and Router taking over full navigation ownership — close enough to the VIP templates above that a dedicated VIPER template would be near-duplicate authoring effort for a pattern §3.3 already calls "heaviest boilerplate." VIPER stays template-assisted.
  - **Naming note — two different "Router" concepts, don't conflate them.** VIP's per-scene `<Name>Router.swift` (one of its five layer files, §3.3) decides *where* to go from inside that specific scene; §3.4's `Coordinator`/`Router` is the *app-wide* navigation-approach choice that actually owns the `UINavigationController`/`NavigationPath`. VIP's scene-level Router calls into whichever app-wide mechanism §3.4 selected — it doesn't replace it.
- **Template-assisted for every other combination:** `new_feature.sh` still generates the folder skeleton, DI wiring, navigation registration, and test scaffold deterministically regardless of architecture — but the body of Presenter/Interactor/Controller files falls back to Claude writing them from the §3 layer description, since that's genuinely custom per combination, not something worth hand-templating on faith before it's been used. This now covers: MVC+SwiftUI, MV (either UI framework), VIPER (either), and any architecture paired with the non-default navigation approach for its UI framework (e.g. MVVM+UIKit+Coordinator).
- **Topology is orthogonal to this split.** The parts that vary by tier — where the files land, which spec gets the new dependency, whether a type needs `public` — are deterministic at all three tiers, because they're driven by `ios-skeleton.config.json` rather than by the architecture templates (§3.9). Only file *bodies* fall back to the agent.
- As more combinations prove common in real use, add their template folder under `Scripts/templates/` and drop them from the template-assisted set. Track which combinations are fully templated vs. agent-assisted in `docs/PROJECT_MAP.md` — a project team should know which path their `/new-feature` calls take.

---

## 2. The `/start` Skill — spec for `.claude/skills/start/SKILL.md`

Everything in this section is what you're building *into* the Skill file, to run later, not what you do now.

### 2.1 First-run flow

0. **Resolve the target path and copy the template's own files into it.** `/start` takes one optional argument, a path (§0).
   - No path → the target is the current directory; nothing to copy (it's either already the template's own clone, or the developer copied the files in by hand already).
   - A path → resolve it relative to the current directory, creating the directory if it doesn't exist. Then copy this template's `.claude/`, `Scripts/`, `docs/`, `.swiftlint.yml`, `.githooks/`, `CLAUDE.md.template`, and `README.md` into it. **This copy is a merge, never an overwrite:** walk file-by-file (not folder-by-folder) — if a destination file doesn't exist, copy it; if it does, leave it exactly as it is and don't even log noise for the common case (a fresh/empty target has nothing to skip). This one rule is what makes an adoption target safe to point at directly: an adopted repo's `docs/CODING_STANDARDS.md`, `CLAUDE.md.template`'s eventual render target, and `README.md` are the developer's own history, not this template's boilerplate, and a folder-level `cp -r` would clobber them.
   - Every step from here on operates on the resolved target path, not necessarily the directory `/start` was invoked from.
1. Check for `ios-skeleton.config.json` at the resolved path. Absent → continue below. Present → jump to §2.4 (idempotent re-run) instead.
2. Ask the Setup Questionnaire (§2.2) in one batched interaction, not one question per turn.
3. Validate the answers (§2.3) — stop and re-ask on any invalid combination rather than silently picking a fallback.
4. Write `ios-skeleton.config.json` recording every answer, **including the topology tier and the full module list** — `{ "topology": "T3", "apps": [...], "modules": [...] }`. Every other Skill reads its "which module?" branch from here (§4).
5. Generate the spec file(s) per the tooling answer and the tier (§3.9): one `project.yml`/`Project.swift` at T1/T2; one spec **per project** at T3, plus the workspace.
6. Run `xcodegen generate` (once per spec) or `tuist generate` to produce the real `.xcodeproj`(s). At T3 with XcodeGen, also run `Scripts/generate_workspace.sh` — XcodeGen generates projects, not workspaces, so the template emits `<Name>.xcworkspace/contents.xcworkspacedata` itself from the config's project list (§3.9). **No manual Xcode step, ever, at any point in this flow.**
7. `git init` if no `.git` exists yet. If this folder came from cloning the template repo directly, **offer** — don't silently do — to detach it from the template's own git history/remote so the new app starts with clean history.
8. Wire `.githooks/pre-commit` and `.githooks/commit-msg` via `core.hooksPath` — on Path 3 (step 13), only after that step's adoption dry-run passes, or the developer explicitly accepts report-only mode.
9. Materialize the folder tree from §3 for the chosen architecture **and tier**: `App/`, `Core/` (Utilities + Configuration + Localization), `Networking/`, `Models/`, `DesignSystem/` (Theme + Views), `Features/` — as folders in one target at T1, as local packages at T2, as separate framework projects at T3 (§3.9). Render two things into `Core` that every tier gets and neither depends on the architecture combo: **`Logging/Log.swift`** from `Scripts/templates/logging/` — always, at every tier, because `docs/CODING_STANDARDS.md` and `.swiftlint.yml`'s `no_print_statements` both point at it and would otherwise be dead references on day one (§8.6) — **`Configuration/AppEnvironment.swift`** from `Scripts/templates/config/` on any project that has a configuration key — i.e. every networked one, where `API_BASE_URL` exists on day one — because it is the app's single reader for everything arriving from `Secrets.xcconfig` and the composition root passes `AppEnvironment.current.apiBaseURL` into `RequestBuilder` rather than parsing the plist itself (§8.3); and, **only when Q4 isn't `None`**, `Persistence/PersistenceController.swift` from `Scripts/templates/persistence/<swiftdata|coredata>/` (§3.8). Neither becomes its own module at any tier: one file doesn't justify a spec, a workspace entry and a scheme, and `/add-module Logging` is there for a team that later wants independent versioning. Seed **each localization-owning module's** `Localization/Localizable.xcstrings` with its first few real strings and run `Scripts/generate_strings.sh` once per module to produce its bundle-aware `L10n.swift` (§3.11) — never leave the localization layer unwired even before the first feature exists.
10. Scaffold one starter feature (e.g. "Home") **in each app** using the same logic §4.1 describes for `/new-feature` — proving the whole stack actually compiles and its one generated test actually passes, not aspirationally. At T3 with more than one app, also generate one shared base view in the shared UI module that both apps' Home screens consume, so the sharing seam is exercised on day one rather than discovered later (§3.9).
11. Render `CLAUDE.md`, `docs/ai/architecture.md` and `docs/ai/modularization.md` from their `.template` counterparts, **write `README.md` and `docs/ONBOARDING.md` fresh for this project** (there is deliberately no `.template` for either: the copies that arrived with the template describe the template system itself, per §1.2, and are overwritten rather than substituted), **and seed `docs/PROJECT_MAP.md`** with the three sections §5 names (there is no `.template` for it — it's written fresh, and `CLAUDE.md` links to it, so it can't be left for `/add-module` to create on first append), replacing every placeholder with the real, locked-in decisions — a project that chose VIPER should never see MVVM's diagram in its own `docs/ai/architecture.md`, and a T1 project should never see a workspace diagram in its `modularization.md`. On Path 3 (step 13), never run this unmodified against a `CLAUDE.md`/`README.md`/`docs/ONBOARDING.md` that already existed before this run — see step 13's carve-out.

    Then create `docs/product/` with the template's own `README.md` in it, and stop there (§5.2). This step is the exception to everything else in step 11: nothing in that folder is rendered, substituted or regenerated, on a first run or a re-run — it's create-if-missing only, because its contents are hand-authored requirements that change constantly and are never this template's to write.
12. Report exactly what's left to do by hand (fill in `Secrets.xcconfig`'s `API_BASE_URL` — §8.3; open the project once in Xcode; per-app signing) as `TODO.md` entries — not just a message that scrolls off-screen. Include the optional Xcode MCP bridge step from §5.1 as an *offer*, never as something this run performed.
13. **Path 3 (§0) variant — adopting an existing repo:** skip steps 5–6 for anything already present.
    - **Infer the tier from what's actually there — don't assume workspace means Path 3 and a bare project doesn't.** One `.xcodeproj` with no local packages → T1. One `.xcodeproj` plus local Swift packages → T2. `.xcworkspace` + N projects → T3. State the inferred tier and confirm it with the developer before writing `ios-skeleton.config.json`, exactly the same way whether one project exists or several.
    - **Record the deployment target actually set on the existing project's build settings** as `minIOSVersion`, instead of asking Q8's greenfield picklist (iOS 16/17/18) — an adopted project may already sit below that floor, and every §2.3 validation rule (SwiftData/`@Observable`/`NavigationStack` gating) must check against the real number, not the picklist default.
    - **Detect the existing feature-folder convention** (e.g. `Features/`, `Scenes/`, `Modules/`) and record its name in the config instead of assuming the literal `Features/`. `new_feature.sh` and `/new-feature` must read this field rather than hardcode the name — otherwise adoption produces a second, inconsistent folder alongside the one already in use (§3.2).
    - **Surface an untemplated combo immediately, during this confirmation, not later.** If the detected architecture/UI-framework/navigation combination isn't one of §1.4's four fully-templated ones (e.g. any Hybrid UI-framework project), say so plainly here — don't let the developer discover it only when `/new-feature` first falls back mid-run.
    - **Product docs belong to the developer.** An adopted repo may already keep a PRD/SRS/API contract somewhere. Never move, rewrite or absorb it — either point `docs/product/README.md` at where it lives or leave the folder uncreated, and record the location in `docs/PROJECT_MAP.md`.
    - **Never silently overwrite hand-authored project docs.** Before step 11 renders `CLAUDE.md`/`README.md`/`docs/ONBOARDING.md`, check whether each already exists with real content (no leftover `{{placeholder}}` tokens; predates this run's `ios-skeleton.config.json`). If so, do not overwrite it — render the new version to a side file (or simply skip it and note the gap in `TODO.md`) and ask the developer how to reconcile it manually. `docs/ai/architecture.md`/`modularization.md` are still safe to render fresh, since an adopted repo never had them before.
    - **Never wire hooks blind.** Before step 8, run `Scripts/lint.sh`, `check_hardcoded_colors.sh`, `check_strings.sh`, and `check_secrets.sh` once against the adopted codebase as a dry run. If any fail, report the failures and ask whether to fix them first or wire the hooks in report-only mode instead — an adopted codebase has never been checked against this template's conventions, and a hard-blocking hook can lock the developer out of their very next commit.
    - Detect the existing `.xcworkspace`/`.xcodeproj` set, record it as the topology, and write a `TODO.md` entry naming each project not yet described by a spec file. Never regenerate or overwrite a hand-maintained `.xcodeproj` — converting one to a generated spec is an explicit, separate migration the developer opts into (§3.10).

### 2.2 Setup Questionnaire

Q1 is asked and answered **first**, and its answer gates most of what follows: which spec files exist, whether a workspace file exists at all, where `Package.resolved` and `.swiftlint.yml` live, where localized strings live, and which module `/new-feature` writes into. Everything below is numbered in ask-order.

| # | Question | Options | Recommended default | Why it matters |
|---|---|---|---|---|
| 1 | **Project topology & modularization** | **T1** single `.xcodeproj`, one app target / **T2** single `.xcodeproj` + local Swift packages (`Core`, `DesignSystem`, `Networking`, `Models`, `Features/*`) / **T3** `.xcworkspace` + N projects (1..N apps + shared framework projects) | T2 for one app; T3 the moment a second app, app-extension, or separately-versioned SDK is on the roadmap | Gates the whole tree (§3.9), the location of lint/strings/`Package.resolved`, and every Skill's "which module?" branch. Also asks: **how many apps now?** — see Q12 |
| 2 | Language | Swift only *(no Objective-C option — decided against; see §10)* | Swift-only | Every generated file is Swift. A project with legacy Objective-C to bridge in still can — add a bridging header manually — but this template generates nothing for it. |
| 3 | UI framework | SwiftUI / UIKit / Hybrid (UIKit shell hosting SwiftUI screens) | SwiftUI | Changes the shape of the presentation layer |
| 4 | Persistence | SwiftData / Core Data / None (network + in-memory only) | SwiftData | **Changes generated code, not just the config.** `None` → every feature's data layer is remote-only. SwiftData/Core Data → each feature additionally gets a `<Name>LocalStore` beside its remote dependency, and the app gets one `PersistenceController` (§3.8). SwiftData requires iOS 17+ — validate against Q8 |
| 5 | Architecture pattern | MVVM / MVC / VIP (Clean Swift) / VIPER / MV (SwiftUI-native, `@Observable`, no separate ViewModel) | MVVM | Determines the layer set every feature scaffold generates — see §3 |
| 6 | Navigation implementation | UIKit `UINavigationController` + Coordinator (more mature) / SwiftUI `NavigationStack` + Router object (native, less glue code) | `UINavigationController` + Coordinator if Q3 includes any UIKit; either for SwiftUI-only | **Independent of Q3** — a SwiftUI app can still run its nav backbone on `UINavigationController` via `UIHostingController`; a pure-UIKit app cannot use `NavigationStack` at all — see §2.3 |
| 7 | Networking & concurrency | URLSession + async/await / URLSession + Combine / Alamofire / **None (offline, local-only)** | URLSession + async/await | Affects the generated `Service`/`Repository` signatures. **`None` changes generated code, like Q4 does:** the app shell's networking block and the `APIBaseURL` reader drop out entirely, and the feature data layer has no remote half. `None` + Q4 `None` leaves nothing for a feature's data layer at all — see §2.3's validation rule, which asks rather than refuses, because an app with no data layer (a calculator, a converter) is a legitimate shape that simply sits outside template coverage |
| 8 | Minimum iOS deployment target | iOS 16 / 17 / 18 | 17 | Gates SwiftData, `@Observable`, `NavigationStack` availability. **Path 3 (§2.1 step 13):** not asked from this picklist — recorded from the existing project's actual build setting, which may be below 16. |
| 9 | Dependency injection | Manual initializer injection / lightweight container (e.g. Factory) | Manual initializer injection | Manual keeps the app dependency-free; a container is an explicit upgrade |
| 10 | Testing framework | XCTest / Swift Testing | XCTest | Swift Testing needs Xcode 16+/iOS 17+ toolchains |
| 11 | Project generation tooling | XcodeGen (one `project.yml` per project) / Tuist (`Project.swift` + `Workspace.swift`) | XcodeGen at T1/T2; **Tuist at T3** if the team is willing to adopt it — see §3.9's tooling note | Both are deterministic/diffable — hand-maintaining `.xcodeproj` isn't offered here since §2.1 step 6 requires generating the project from scratch |
| 12 | App identity — **per app** | Display name, bundle identifier, org/team ID, and (T3, multi-app) the shared bundle-ID prefix | — no sane default, must ask | Needed to generate the spec at all. At T3 with 2 apps, ask twice — two identities, two schemes, two entitlement files (§8.1) |

Ask it like this:

> "Before I scaffold your app, I need a few decisions — answer inline or say 'use the recommended defaults' and I'll fill in the rest:
> 1. Topology — one Xcode project (T1), one project plus local Swift packages (T2), or a workspace with several projects because you'll ship more than one app / a reusable framework (T3)? And how many apps do you expect in this repo — now, and within a year?
> 2. (Language is fixed at Swift only — this template doesn't scaffold Objective-C interop.)
> 3. SwiftUI, UIKit, or a hybrid?
> 4. SwiftData, Core Data, or no local persistence? (This one changes what every feature generates — "None" means remote-only screens, and adding a local store later is a per-feature edit.)
> 5. Architecture: MVVM, MVC, VIP (Clean Swift), VIPER, or MV (SwiftUI-native)?
> 6. Navigation: SwiftUI `NavigationStack`, or a `UINavigationController` + Coordinator backbone (more mature, works even if the screens themselves are SwiftUI)?
> 7. Networking: URLSession+async/await, URLSession+Combine, or Alamofire?
> 8. Minimum iOS version?
> 9. Manual dependency injection, or a lightweight DI container?
> 10. XCTest or the new Swift Testing framework?
> 11. XcodeGen or Tuist for project generation?
> 12. For each app: display name, bundle identifier, and team ID?"

Answer Q1 honestly rather than aspirationally. "One app, but we might extract an SDK someday" is **T2** — §3.10 exists precisely so that T2 → T3 is a bounded, scripted move rather than a rewrite. Choosing T3 for one app buys nothing but a second file to keep in sync.

### 2.3 Validation rules (reject/flag before scaffolding)

- SwiftData or the MV (`@Observable`) pattern selected but deployment target < iOS 17 → stop, ask the user to raise the target or pick Core Data / MVVM instead.
- `NavigationStack`-based routing selected but deployment target < iOS 16 → same treatment.
- UI framework (Q3) = UIKit **and** navigation (Q6) = `NavigationStack` → invalid, `NavigationStack` is SwiftUI-only; stop and ask the developer to pick the Coordinator/`UINavigationController` route or switch Q3.
- UI framework (Q3) = SwiftUI **and** navigation (Q6) = `UINavigationController` + Coordinator → valid, but document in the rendered `docs/ai/architecture.md` that every screen is hosted via `UIHostingController` and pushed/popped through the Coordinator, not a SwiftUI `NavigationLink` — mixing both mechanisms in one app is what actually breaks.
- Topology (Q1) = T1 **and** more than one app declared (Q12) → invalid; two apps need at least T2 with a shared package, realistically T3. Stop and re-ask.
- Topology (Q1) = T3 **and** one app declared **and** nothing on the roadmap answer (no second app, no extension, no externally-consumed SDK) → flag as likely over-engineering and confirm intent; T2 is the cheaper start and §3.10 makes the move real. If a second app or SDK *is* on the roadmap, T3 with one app is the recommended answer per Q1 — do not challenge it, and do not cite §3.10, whose cost table says retrofitting is the expensive path.
- Topology (Q1) = T3 **and** tooling (Q11) = XcodeGen → valid, but state plainly that the workspace file is emitted by `Scripts/generate_workspace.sh`, not by XcodeGen (verified: XcodeGen generates one `.xcodeproj` per spec and has no workspace-generation flag), and that adding a project later means adding a spec **and** re-running that script.
- An `.xcworkspace` or `.xcodeproj` already exists on disk that no spec file describes → do not proceed as if greenfield; switch to §2.1 step 13's adoption path and confirm the detected topology with the developer before writing anything.

### 2.4 Idempotent re-run behavior

- Re-running `/start` once `ios-skeleton.config.json` exists must never silently regenerate or delete anything already built.
- Show the currently recorded answers first, before asking anything.
- For each step in §2.1 (5–11), skip whatever's already present and correct; recreate anything missing (e.g. a docs file someone deleted by accident).
- If a new answer would change an already-locked decision — e.g. switching architecture after real features exist under `Features/` — **stop and warn explicitly**: name what's at risk (existing features won't be retroactively migrated to the new pattern), and require an explicit confirmation before applying the change. Never apply a conflicting change silently.
- **Changing topology (Q1) on a re-run is not an answer edit — it is a migration**, and a larger one than changing architecture: it moves files between targets, rewrites every affected `import`, relocates strings and `Package.resolved`, and invalidates existing schemes. `/start` must refuse to do it as a side effect of a re-run. Instead: print the §3.10 migration path for the specific direction requested (T1→T2, T2→T3, …), list the concrete moves for *this* repo, and tell the developer to run it as a deliberate, reviewable change — ideally on its own branch, with `/add-module` or `/add-app` doing the additive parts.
- If nothing has changed and nothing is missing, report "already configured, nothing to do" rather than re-touching files.

---

## 3. App Folder Tree & Architecture (what `/start` produces inside a real project)

**Read §3.9 before §3.1.** The tree below is the T2 shape (one project, local packages). Topology (Q1) decides how the same layer set is physically arranged: folders in one target (T1), local Swift packages (T2), or separate framework projects inside a workspace (T3). The layer *names and responsibilities* are identical at all three tiers — only their packaging changes, which is what makes §3.10's migration path tractable.

### 3.1 Folder tree — T2, the default tier (T1 and T3 in §3.9)

This is the **T2** layout: one app project plus local Swift packages. At **T1**, every `Packages/<M>/Sources/<M>/` folder below collapses to a plain `<M>/` folder inside the app target — same layer names, no `Package.swift`, no module boundary, and a single app-level `Localization/`. At **T3**, the same packages become framework projects inside a workspace (§3.9).

```
<AppName>/                            # created by /start — this is a real, separate project, not the template repo
├── project.yml                       # or Tuist Project.swift
├── ios-skeleton.config.json          # the locked-in Q1–Q12 answers — §1.3's shared precondition checks this
├── .swiftlint.yml
├── .githooks/
│   ├── pre-commit
│   └── commit-msg
├── CLAUDE.md                         # rendered from CLAUDE.md.template — real decisions, not placeholders
├── CLAUDE.md.template                # retained, inert after §1.9's render — the source /start's re-run (§2.1) recreates a deleted doc from
├── README.md
├── docs/
│   ├── ONBOARDING.md
│   ├── CODING_STANDARDS.md
│   ├── GIT_CONVENTIONS.md
│   ├── PERMISSIONS.md                # created on first use of /add-permission
│   ├── PROJECT_MAP.md
│   ├── product/                      # §5.2 — PRD/SRS/API contracts, hand-authored and never generated
│   └── ai/
│       ├── architecture.md           # rendered with the ONE chosen pattern's layers
│       ├── architecture.md.template  # retained render source — still carries ALL patterns; grep `docs/` hits the ones this repo didn't choose
│       ├── modularization.md         # rendered with THIS repo's tier + module graph — §3.9–§3.11
│       ├── modularization.md.template
│       ├── theming_rules.md
│       ├── ui_rules.md
│       └── permissions_rules.md
├── .claude/skills/                   # copied over as-is from the template
├── Scripts/                          # copied over as-is from the template
│   ├── lint.sh
│   ├── check_hardcoded_colors.sh
│   ├── check_strings.sh              # key parity across locales, per module — §8.5
│   ├── check_secrets.sh              # Secrets.xcconfig health — §8.3
│   ├── add_secret.sh                 # §4.10 — appends a key to Secrets.xcconfig + .example, escapes `//`, holds back credential-shaped values
│   ├── generate_strings.sh           # <module> → that module's L10n.swift from its Localizable.xcstrings
│   ├── new_module.sh
│   ├── new_feature.sh
│   └── templates/                    # NOT one-time input — new_feature.sh, /add-app and /add-secret read these on every call (§1.4, §4.10); deleting them breaks feature generation in this project
├── App/                              # the app target: composition root, identity, app-specific features
│   ├── <AppName>App.swift            # or AppDelegate/SceneDelegate for UIKit
│   ├── Navigation/                   # Route.swift + Router.swift, or AppCoordinator.swift for the UIKit combos (§3.4)
│   ├── Theme/                        # app-level token overrides only — base tokens live in DesignSystem (§3.11)
│   ├── Localization/
│   │   ├── Localizable.xcstrings     # String Catalog: every locale in one file, keys namespaced `app.*`
│   │   └── L10n.swift                # generated, bundle-aware accessor — L10n.home.title, never a raw literal
│   ├── Features/
│   │   └── Home/                     # the starter feature /start scaffolds — proves the stack compiles
│   └── Resources/
│       ├── Assets.xcassets           # brand art + AppIcon — app-target-only (§3.11)
│       └── Info.plist, <AppName>.entitlements
├── Packages/                         # local Swift packages — the T2 module boundary
│   ├── Core/
│   │   ├── Package.swift
│   │   └── Sources/Core/
│   │       ├── Utilities/Debouncer.swift    # shared debounce helper for search-as-you-type interactors
│   │       ├── Logging/Log.swift            # §8.6 — always generated, at every tier
│   │       ├── Configuration/               # the ONE reader for Secrets.xcconfig values — §8.3
│   │       │   └── AppEnvironment.swift     # rendered by /start on any project with a key
│   │       └── Persistence/                 # ONLY when Q4 named a stack (§3.8)
│   │           └── PersistenceController.swift
│   ├── Networking/
│   │   └── Sources/Networking/
│   │       ├── RequestBuilder.swift  # base URL, headers, API-key injection, query params — one place
│   │       └── APIClient.swift       # executes requests, decodes responses, maps errors/failures/empty
│   ├── Models/                       # THE one shared home for every model type — see §3.2
│   │   └── Sources/Models/
│   │       ├── HomeModels.swift      # <Name>Models.swift per feature — request/response/entity structs
│   │       └── ...                   # e.g. Movie.swift, TVShow.swift — types used by more than one feature
│   └── DesignSystem/
│       ├── Sources/DesignSystem/
│       │   ├── Theme/                # BASE tokens — ColorTokens.swift, Typography.swift, Spacing.swift (§10: optional)
│       │   │                         # splits into Color/, Font/, Size/ per family as it grows; ComponentStyles/ holds per-component styling (§3.11)
│       │   └── Views/                # reusable views — LoadingView, ErrorView (message + optional retry), EmptyStateView, and every component a second screen needs (§3.6)
│       ├── Resources/
│       │   ├── Assets.xcassets       # shared iconography
│       │   └── Localization/         # this package's own strings + bundle-aware L10n (§3.11)
│       └── Tests/
└── TODO.md                           # created on first use — manual follow-ups per feature
```

Package boundaries are only worth their cost if they're directed: `App` → `DesignSystem`/`Networking` → `Models`/`Core`, never the reverse (§3.9). Anything the app touches from a package is `public` with an explicit `public init`.

### 3.2 Leaf feature folders are flat; models always live in the shared `Models/` package

Two fixed rules, applied regardless of architecture pattern:

- **A leaf feature's folder is flat.** `Features/Home/` contains every layer file for that screen directly — `HomeView.swift`, `HomeInteractor.swift`, `HomePresenter.swift`, and so on — named `<Feature><Layer>.swift`. No `Presentation/`/`Domain/`/`Data/` subfolders inside a feature. **Grouping folders one level above a leaf feature are allowed** — `Features/Settings/Profile/`, `Features/Settings/Notifications/` — when a flow genuinely contains several screens; what's banned is layer-named subfolders *inside* a screen's folder, not thematic grouping between `Features/` and the screen. (Shipped apps of this size nest exactly this way, two levels deep — see §8; a strictly flat `Features/` stops scaling somewhere around 30 screens.) `/new-feature` accepts a path — `/new-feature Settings/Profile` — and creates the intermediate group without inventing layer subfolders. A grouping level does not have to be empty: a screen folder may hold **child-screen folders beside its own layer files** — `Features/Home/` carrying `HomeView.swift` and a `Features/Home/HomeDetail/` holding that screen's layer set — so `Home/` is both a leaf and a group. Name the child screen so it is unique app-wide (`HomeDetail`, not `Detail`): its generated types and its `Models/<Name>Models.swift` entry live in the shared `Models/` namespace, which nesting does not scope. A grouping folder may also hold **flow-level files beside its child screens** — the flow's coordinator, a state object several of its screens share — the way a shipped app's `Authentication/` holds `AuthorizationCoordinator.swift` next to `Authentication/Login/` and `Authentication/About/` (§8.1a). The ban is narrower than "one level of nesting": it is *layer-named* subfolders inside a screen's folder, at any depth.
- **A view used by one screen stays with that screen; only a second consumer makes it shared.** Three shapes, in order, and a view moves up only when it earns it:
  1. **In the screen's own file.** A small, stateless presentation helper — a header, a row, a footer — is a `private` view type at the bottom of `HomeView.swift`. This is the default, and most subviews never leave it. A separate file per subview is how a feature folder ends up with fifteen files and no clearer structure.
  2. **Its own file in the same feature folder** — `Features/Home/HomeHeaderView.swift` — once it stops being a small helper: it owns state, it handles its own loading/error, or a second file *inside the feature* needs it.
  3. **Its own child-screen folder** — `Features/Home/HomeDetail/` with that screen's full layer set, generated by `/new-feature Home/HomeDetail` — once it is a second *screen* rather than a component: it has its own data source, its own navigation entry, or its own tests.
  The moment a **second screen** needs it, none of the three apply and it moves to `DesignSystem/Views/` (§3.6) — that rule outranks all of this, because promotion-on-second-use is what keeps the design system real.
- **Models never live inside a feature folder, ever.** Every model type — a domain model shared across screens (`Movie`, `TVShow`) and a single feature's own Request/Response/Entity/ViewModel structs alike — lives in the top-level `Models/` package instead. This is a deliberate simplicity choice: one place to look for any data shape in the app, at the cost of `Models/` growing large and needing file-per-feature discipline (`Models/HomeModels.swift`, `Models/SearchModels.swift`) rather than one shared file for everything — see §10 for the naming-collision trade-off this creates. At T2/T3 `Models/` is one module, shared by every consumer; a model needed by only one app still lives there unless it is genuinely app-private, in which case it may stay in that app's own `Models/`.
- **Exception — MV's `Model` is not a data model.** In the MV (SwiftUI-native) pattern, `<Name>Model.swift` is an `@Observable` class holding view state and calling services — it's presentation-layer plumbing, analogous to a ViewModel, and stays in `Features/<Name>/` like every other layer file. Don't confuse it with the data models in `Models/`.

Applied consistently by both `/start`'s starter feature and every feature `/new-feature` generates afterward. On an adopted project (Path 3, §2.1 step 13), the folder named `Features/` throughout this section is whatever name `/start` detected on disk (e.g. `Scenes/`, `Modules/`) and recorded in the config — everything else here applies unchanged once that substitution is made; `new_feature.sh` reads the name from config rather than hardcoding it.

### 3.3 Architecture Pattern Reference

| Pattern | Files directly inside `Features/<Name>/` (flat) | Notes | Fully templated? (§1.4) |
|---|---|---|---|
| **MVC** | `<Name>ViewController.swift` (layout in code — see the storyboard note below) | Models live in `Models/`, never here. Simplest, most Massive-View-Controller risk — reasonable only for very small apps. | UIKit: yes (`mvc-uikit-coordinator`). SwiftUI: template-assisted — see the MV row instead. |
| **MVVM** *(default)* | `<Name>View.swift`, `<Name>ViewModel.swift`, `<Name>Repository.swift`, `<Name>Service.swift` | View binds to an `ObservableObject`/`@Observable` `ViewModel`; `ViewModel` depends on the Repository's protocol directly — no separate business-logic layer between them. If a feature needs to orchestrate more than one repository/service, or apply a rule that belongs in neither the ViewModel nor the Repository, add an `<Name>Interactor.swift` (the native-iOS name for that layer, already used by VIP/VIPER below) rather than a `UseCase` — see §8.2's "don't abstract on speculation." | SwiftUI + `NavigationStack`: yes. UIKit/Coordinator: template-assisted. |
| **VIP (Clean Swift)** | `<Name>View.swift` (SwiftUI: **+ `<Name>ViewModel.swift`**), `<Name>Interactor.swift`, `<Name>Presenter.swift`, `<Name>Router.swift`, `<Name>Worker.swift` | Request/Response/ViewModel structs live in `Models/<Name>Models.swift`, not here. Strict unidirectional flow: View → Interactor → Presenter → View. SwiftUI needs the extra `ViewModel` as a bridge, since a SwiftUI View can't hold `weak var displayLogic` itself (§1.4) — UIKit's `ViewController` holds it directly, no bridge needed. | Yes, both variants: `vip-swiftui-navigationstack` and `vip-uikit-coordinator`. |
| **VIPER** | `<Name>View.swift`, `<Name>Interactor.swift`, `<Name>Presenter.swift`, `<Name>Router.swift` | Entity structs live in `Models/<Name>Models.swift`. Full separation, heaviest boilerplate. Differs from VIP only by dropping the `weak` reference and giving Router full navigation ownership — close enough to VIP that it's deliberately not given its own template (§1.4). | Template-assisted. |
| **MV (SwiftUI-native)** | `<Name>View.swift`, `<Name>Model.swift` | `<Name>Model` is presentation state, not a data model — see the exception in §3.2. Fewest layers, least isolatable for unit testing. | Template-assisted. |

**Storyboards and XIBs: generated UIKit screens lay themselves out in code, deliberately.** This was investigated rather than assumed, and the premise that motivates the question is correct — a storyboard *is* XML, and a minimally valid one is short enough to emit from a template. Generating them is not blocked by difficulty. It's declined for four reasons that hold specifically for a template driven by an agent and reviewed in diffs:

- **The file is not stable text.** Xcode rewrites a storyboard on open — reordering elements, restamping the `toolsVersion`/`systemVersion` header, adding a `resources` section — so a file the template emits and a file a developer opened once differ without anyone having changed the design. Every such rewrite is a diff to review and a merge conflict waiting for the second developer.
- **Its identifiers are opaque.** Views, constraints and segues are keyed by generated IDs (`Xy2-3z-Abc`). A conflict inside a storyboard is resolved by reading ID soup, not by reading layout, and an agent editing one has no readable anchor to edit *at* — the exact property that makes code templates safe to modify mechanically is absent.
- **It moves wiring out of the compiler's reach.** `@IBOutlet`/`@IBAction` connections and storyboard identifiers fail at runtime, not at build time. That directly contradicts the discipline the rest of this template is built on — typed color tokens over Asset Catalog lookups (§6), a generated `L10n` over raw keys (§3.7), protocol boundaries over string-keyed indirection (§8.2). A storyboard reintroduces exactly the failure mode those choices exist to eliminate.
- **Autolayout in XML is verbose out of proportion to what it expresses.** A constraint set that is six readable lines of `NSLayoutConstraint.activate` is dozens of lines of nested XML, which is what the agent must then keep correct.

What this template does instead: every generated `UIViewController` builds its subviews and activates its constraints in code, and the app is launched programmatically from `SceneDelegate` with no `Main.storyboard` and no `UIMainStoryboardFile` key. The one storyboard-shaped thing that stays is the launch screen, and Q1's generated `Info.plist` uses the modern `UILaunchScreen` dictionary rather than a `LaunchScreen.storyboard` file — same result, no XML.

**This is a decision about what the template generates, not a house rule about your app.** A team that wants storyboards or XIBs for hand-authored screens can add them freely; nothing here breaks, and a `.xib` added to a target's source folder is picked up on the next regenerate (§3.12). What won't happen is a Skill generating one, or an agent being asked to edit one — if a project standardizes on Interface Builder, the honest expectation is that those screens are built by a human in Xcode and the agent works on the code around them.

### 3.4 Navigation approaches (independent of the architecture pattern above and of Q3's UI framework)

| Approach | How a screen gets pushed | Notes |
|---|---|---|
| **`UINavigationController` + Coordinator** | Coordinator holds the `UINavigationController` and calls `pushViewController`; SwiftUI screens wrapped in `UIHostingController` before pushing | More mature — precise stack control, reliable interactive-pop, easier custom transitions. Works regardless of whether individual screens are UIKit or SwiftUI. |
| **SwiftUI `NavigationStack` + Router** | A `Router` holds a `NavigationPath`/typed path array; Views append/remove from it, `.navigationDestination` maps a route to a screen | Less glue code, fully declarative — only available when the hosting screen is SwiftUI. |

Whichever is chosen (Q6) is the **one** navigation mechanism for the whole app — `/new-feature` always wires into it, never introduces a second path. At T3 with more than one app, each app owns its own navigation root, but both must use the *same* mechanism — a shared framework can only vend pushable screens if it can assume one navigation contract (§3.9).

**Don't confuse this `Router` with VIP's per-scene `Router.swift` (§3.3, §1.4).** This section's `Router`/`Coordinator` is the one app-wide mechanism that actually owns the `NavigationPath`/`UINavigationController`. VIP's own `<Name>Router.swift` is a per-scene layer file that decides *where* a given scene should go next and hands that decision to whichever app-wide mechanism is in force here — it never owns navigation state itself.

### 3.5 Tab-based apps: independent navigation per tab

If the app has a tab bar, **each tab owns its own navigation stack** — never a single shared one: one `Coordinator` (and its own `UINavigationController`) per tab, or one `NavigationStack`/`Router` per tab. Pushing a detail screen from one tab must never affect another tab's back stack. This belongs in `/start`'s app-shell template, not left for the first multi-tab feature to improvise.

### 3.6 Shared loading / error / empty states — and shared views generally

Every list or detail screen needs the same three states. Generate them once in `DesignSystem/Views/` and have every feature consume them rather than re-inventing a spinner/error text per feature. `ErrorView` takes a message and an optional retry closure wired to redispatch the same load action.

**This applies to every combination, not only the SwiftUI ones.** A UIKit project gets `LoadingView`/`ErrorView`/`EmptyStateView` as plain `UIView` subclasses in the same `DesignSystem/Views/` folder, generated by `/start` alongside the app shell, and its ViewControllers consume those instead of building a spinner and an error label inline. Same rule, same location, different concrete type — a per-feature reimplementation is the thing being prevented, and that failure mode is if anything *more* common in UIKit, where a `UIActivityIndicatorView` plus two constraints is easy enough to retype that it gets retyped in every screen.

The general rule this is the first instance of: **a view used by more than one screen belongs in `DesignSystem/Views/`, at every tier and in both UI frameworks.** When `/new-feature` generates a screen that needs a component another screen already has — a styled primary button, a labelled row, a card container — it consumes the shared one or promotes the existing one into `DesignSystem/Views/`; it does not copy it into the new feature folder. This is deliberately a stronger stance than §8.2's "don't abstract on speculation," and the two do not conflict: §8.2 governs *protocol* boundaries invented ahead of a second conformance, whereas a second screen rendering the same component is the second use case already having arrived. From T2 onward these views live in the shared module and are `public`; per-app visual differences go through the theme override layer (§3.11), never through a forked copy of the view.

**Inside `DesignSystem/Views/`, group by component and never by layer.** A component is a loose file while it is one file — `LoadingView.swift`, `ErrorView.swift` — and gets its own folder the moment it acquires a companion: its view model, its style, a subcomponent only it uses (`CommonLabel/CommonLabel.swift` + `LabelViewModel.swift`, `Buttons/`, `Dropdown/`). Thematic families (`Molecules/Cards/`) are allowed once several components share one. This is drawn from the shipped app in §8.1a, whose shared `Views/` holds ~20 loose files beside ~15 component folders; the banned shape is the same one banned in a feature folder — a subfolder named after a layer rather than a component.

### 3.7 Shared utilities — never duplicated per feature

These five live in exactly one place each, referenced by every feature that needs them — never re-implemented locally:

| Utility | Location | What it does |
|---|---|---|
| Request builder | `Networking/RequestBuilder.swift` | Base URL, headers, API-key injection, query params — one place every `Service` calls through |
| API caller | `Networking/APIClient.swift` | Executes the built request via URLSession (or Alamofire per Q7), decodes the response, maps errors/failures/empty responses |
| Models | `Models/` | Every model type in the app, per §3.2 — domain models and per-feature Request/Response/Entity structs alike |
| Localization | `<module>/Localization/` | One String Catalog (`Localizable.xcstrings`) **per resource-owning module**, not one per repo, with a bundle-aware `L10n` per module — §3.11 |
| Theming | `DesignSystem/Theme/` (base) + `App/Theme/` (overrides) | Colors and typography as Swift values — see §6 and §3.11 |
| Configuration | `Core/Configuration/AppEnvironment.swift` | The one reader for every `Secrets.xcconfig` value, `API_BASE_URL` included — typed accessors over generic `string`/`url`/`bool`/`int` readers that trap at launch on a missing or malformed value. Rendered by `/start` whenever the project has a key; nothing else in the app touches `Bundle.main` for configuration (§8.3) |
| Logging | `Core/Logging/Log.swift` | A `Logging` protocol + an `OSLog`-backed default. The referent for the no-`print()` rule (§8.6) — rendered by `/start` at every tier, never left as a doc reference with no file behind it |
| Local persistence | `Core/Persistence/PersistenceController.swift` + per-feature `<Name>LocalStore.swift` | One container for the app, injected from the composition root. Exists only when Q4 named a stack — see §3.8 |

`Scripts/generate_strings.sh <module>` regenerates that module's `L10n.swift` from its `Localizable.xcstrings` whenever the latter changes — run by `/start` once per module at setup and by `/add-permission`/`/new-feature` whenever they add a new user-facing string, the same "typed accessor over a magic string" pattern already used for colors (§6) and assets (§4.2). Run with no argument it does every module in the config.

### 3.8 MVVM data/event flow (the default — rendered into `docs/ai/architecture.md` when MVVM is chosen)

```
┌────────────────────┐
│   SwiftUI View      │
└─────────┬───────────┘
          │ user action
          ▼
┌────────────────────┐
│     ViewModel        │  @Observable / ObservableObject
│  published UI state  │
└─────────┬───────────┘
          │
          ▼
┌────────────────────┐
│     Repository        │
└────┬────────────┬────┘
     ▼            ▼
 Remote        Local
 (Service)    (SwiftData/CoreData)
     └────┬───────┘
          ▼
   Models/ (shared)
```

State flows back up the same chain via `@Published`/`@Observable` — no second call path, no layer-skipping.

**The local branch is optional, and Q4 is what decides it — never the feature author.** The diagram's `Local` box exists in generated code only when Q4 named a persistence stack. Concretely:

| Q4 | What every feature gets |
|---|---|
| `None` | Remote only. One dependency (`Service`/`Worker`), one protocol, one fake in the test. No local store, no record type, no `PersistenceController`. A complete answer, not a degraded one — plenty of apps are a view onto a server. |
| `SwiftData` / `Core Data` | The same remote path, unchanged, **plus** a `<Name>LocalStore` injected alongside it. The consuming layer declares both protocols (§8.2): Repository for MVVM, Worker for VIP/VIPER, Service for MVC — whichever type the screen actually depends on. |
| `networking: none` (Q7) + any persistence stack | The mirror image: **no remote path at all**, and the `LocalStore` is the source of truth rather than a fallback. `/new-feature` still generates the folder, `Models/`, the store, the composition-root factory (built with `localStore:` only), navigation registration and localization deterministically — but the data-layer type's **body** is a `TODO(agent)` stub and its test is a *failing* placeholder, because the templated read-through tests assert remote-vs-cache semantics an offline feature doesn't have and a green test proving nothing is worse than an honest red one. This is the existing template-assisted posture (§1.4) narrowed from a whole feature to one file. `networking: none` + `persistence: None` is refused with an explanation, not scaffolded — see §2.3. |

The generated read-through policy is deliberately the simplest one that is correct for a whole-list fetch: **remote is the source of truth; the cache is written on success and read only when the remote call actually failed, and an empty cache rethrows that error rather than reporting an empty screen as success.** A feature that pages, syncs deltas or must read local-first replaces that one method — the template gives it a wired seam, not a caching strategy it has to live with.

Two structural rules follow from §3.2 and §8.2 and are worth stating outright, because they're where a local layer usually goes wrong:

- **A SwiftData `@Model` record is a model.** `<Name>Record` lives in `Models/`, appended to `Models/<Name>Models.swift` beside the struct it mirrors — never in the feature folder, and never instead of the plain struct the rest of the app passes around. The record is a storage shape; the struct is the domain shape; the store maps between them.
- **The local store is behind a protocol its consumer owns**, exactly like the remote one, which is what keeps the generated test a two-fake test rather than a test that needs a real container.

One container per app, constructed in the composition root and injected — nothing below the composition root reaches for `PersistenceController.shared`.

There is deliberately no `UseCase` layer between `ViewModel` and `Repository`. A
layer that only forwards one call to the one below it (`execute() { try await
repository.fetch() }`) is ceremony, not abstraction — it fails §8.2's "second
real conformance" test just as badly as a one-implementation protocol does.
`UseCase` is a Clean-Architecture/Android/Flutter convention; native iOS's name
for the same concept, when a feature actually needs it (multiple
repositories/services to orchestrate, or a rule that belongs in neither the
ViewModel nor the Repository), is `Interactor` — already used by the VIP and
VIPER rows in §3.3. Add one per feature only when that need is real, never as
a default scaffold layer.

### 3.9 Project topology: one project, one project + packages, or a workspace (Q1)

Same layers, three packagings. Pick the smallest one that fits, because §3.10 makes moving up cheap and nothing makes moving down cheap.

| | **T1 — single project** | **T2 — project + local packages** *(default)* | **T3 — workspace + N projects** |
|---|---|---|---|
| Xcode entry point | `App.xcodeproj` | `App.xcodeproj` | `Product.xcworkspace` |
| Spec files | one `project.yml` | one `project.yml` + `Package.swift` per package | one `project.yml` **per project** + workspace file |
| Shared code lives in | folders in the app target | local Swift packages under `Packages/` | separate framework projects (and/or packages) |
| Apps supported | 1 | 1 (+ extensions) | 1..N |
| `Package.resolved` | `App.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/` | same | **`Product.xcworkspace/xcshareddata/swiftpm/`** — it moves |
| `.swiftlint.yml` | repo root | repo root | repo root, one config for every project |
| Compile-time enforcement of layering | none — everything can see everything | real: a package can't import the app | real, plus separate build products and independent versioning |
| Build cost | lowest | low | highest — more targets, more link steps |
| Good for | prototypes, <10 screens | one shipping app of any size | two apps sharing a spine, or a framework you ship to others |

**T3 tree** — the shape a multi-app product converges on (consistent with §8's production baseline):

```
<Product>/                                  # repo root
├── <Product>.xcworkspace/
│   ├── contents.xcworkspacedata            # emitted by Scripts/generate_workspace.sh — see the tooling note below
│   └── xcshareddata/swiftpm/Package.resolved   # SPM pins live HERE once a workspace exists
├── ios-skeleton.config.json                # records topology + every project and its role
├── .swiftlint.yml                          # ONE config at repo root; every project's lint phase points at it
├── Scripts/  .githooks/  docs/  CLAUDE.md
├── <AppOne>/
│   ├── project.yml
│   ├── <AppOne>.xcodeproj                  # generated by XcodeGen/Tuist, committed (§8.8)
│   ├── Sources/{App,Features,Navigation,Theme}     # app-specific screens + brand theme overrides
│   └── Resources/{Assets.xcassets, Localization/Localizable.xcstrings, Info.plist, <AppOne>.entitlements}
├── <AppTwo>/                               # same shape — different identity, theme, feature set
├── Shared/                                 # framework: the spine both apps import
│   ├── project.yml
│   ├── Sources/{Api,Models,Theme,Views,Utilities,Localization}
│   ├── Resources/{Assets.xcassets, Localization/…} # frameworks own their own resources
│   └── Tests/
├── DesignSystem/                           # optional: split out once Shared/Views gets big
└── Logging/                                # leaf framework — depends on nothing in this repo
```

Names are placeholders — `/start` uses whatever the team answers at Q12. What's prescriptive is the *shape*: apps are thin and interchangeable in structure, the spine is a framework, and leaves depend on nothing.

**Dependency rule, enforced by review and by `/add-module`:** apps → shared frameworks → leaf frameworks. Never framework → app. Never app → app. A shared framework that needs app-specific behaviour takes it as a protocol or closure injected by the app at launch — that inversion is the single most load-bearing convention at T3, and it's what makes "base views each app extends" work instead of degenerating into `if currentApp == .x` branches inside shared code. §8.2 covers the abstraction discipline this depends on.

**Framework project vs. local Swift package at T3.** Both are legitimate; don't mix arbitrarily.

| | Framework `.xcodeproj` | Local Swift package |
|---|---|---|
| Resources (assets, String Catalogs, fonts) | first-class, plain bundle | works, but via `Bundle.module` and `resources:` declarations |
| Mixed Obj-C/Swift | straightforward | painful (separate targets) |
| Consumed outside this repo | needs distribution work | trivial (`.package(url:)`) |
| Xcode-independent build/test | needs `xcodebuild` | `swift build`/`swift test` |
| Spec churn | one more `project.yml` + workspace entry | one `Package.swift`, no workspace entry |

Rule of thumb the template encodes: **resource-heavy UI/feature modules → framework projects; pure-logic leaf modules (logging, parsing, networking primitives) → packages.** Record which is which in `ios-skeleton.config.json` so `/add-module` and `/new-feature` don't have to guess.

**Tooling note (verified, not assumed).** XcodeGen generates one `.xcodeproj` per spec and has no workspace-generation flag — the only `.xcworkspace` it writes is the one *inside* a generated project. So at T3 the template owns the workspace file itself: `Scripts/generate_workspace.sh` reads the project list from `ios-skeleton.config.json` and emits `contents.xcworkspacedata`, which is ~10 lines of `<FileRef location = "group:Foo/Foo.xcodeproj">` XML — deterministic, diffable, and re-run on every project add. Tuist models workspaces natively via `Workspace.swift`, which is why Q11 recommends it at T3 for teams willing to adopt it. Either way, **no one hand-edits a `.xcodeproj` or `.xcworkspace` in Xcode's UI** — that's the property the whole template depends on.

### 3.10 Extending to a workspace later — the honest migration cost

This is the question worth answering before choosing Q1: *if we start simple, how bad is it to grow?* The template is built so the answer is "bounded and scripted", not "free".

**Why it's cheaper here than in a hand-maintained project.** Adding a project or package is an edit to a text spec plus a regenerate — never `pbxproj` surgery, never a merge conflict in a 6,000-line XML file, never "it works on my machine because my Xcode wrote different group UUIDs". That single property is most of the value of Q11 and the reason growing topology is a normal change rather than a project-wide event.

**T1 → T2** — small, mostly mechanical, `/add-module` does the bulk:
1. `/add-module Core` creates `Packages/Core/` with its `Package.swift` and test target.
2. Move the layer's files in; add `public` to the types the app uses (the only genuinely tedious step — a package boundary makes `internal` mean something for the first time).
3. Add the package as a dependency in `project.yml`; regenerate.
4. Add `import Core` where needed. Build, run lint, run tests.

**T2 → T3** — larger, but additive rather than destructive:
1. `/add-module Shared --kind framework` creates the framework project + spec, and adds it to the workspace list in the config.
2. `Scripts/generate_workspace.sh` emits the `.xcworkspace`; the existing app project joins it unchanged.
3. **Move `Package.resolved` to the workspace** (`Product.xcworkspace/xcshareddata/swiftpm/`) and re-resolve once — miss this and each project resolves its own copy, which is how two projects end up on two versions of the same dependency.
4. Move shared code from packages/folders into the framework — or leave packages exactly where they are; T3 doesn't require abandoning T2's packages, and mature repos usually run both.
5. Repoint the lint build phase at the root `.swiftlint.yml` in the new project.
6. Re-share schemes: workspace-level scheme visibility is per-project `xcshareddata/xcschemes/`, so an unshared scheme silently disappears from teammates' workspaces and from CI.

**Making one app importable as a framework** (the "turn app A into something app B can consume" case) — additive on paper, and the one migration that reliably costs more than it looks:
1. `/add-app` for the new app, then `/add-module <ExistingApp>Core --kind framework`.
2. Move everything except `@main`, `AppDelegate`/`SceneDelegate`, `Info.plist`, entitlements and the asset catalog's app icon into the framework. The remaining app target becomes a thin shell — composition root, identity, signing.
3. Then pay these, none of which a script can do for you:
   - **Access control:** every type the shell or the second app touches needs `public`, and every initializer needs an explicit `public init` — Swift doesn't synthesize one across a module boundary. This is the bulk of the diff.
   - **Bundle lookups:** `Bundle.main` no longer points at the code's own bundle. Strings, images, nibs and storyboards need `Bundle(for: Type.self)` (framework) or `.module` (package) — and this fails *at runtime*, not at build time, which is why §3.11 makes bundle-aware `L10n` the default from day one rather than a migration chore.
   - **App-only APIs** (`UIApplication.shared`, `openURL`, app lifecycle, some entitlement-gated capabilities) must be inverted into protocols the shell injects.
   - **Info.plist/entitlement keys** stay with the app target; a framework can't declare a permission (§4.4).
4. Verify by building the *second* app against the framework, not the original one — the original keeps compiling long after the extraction is actually incomplete.

**Cost summary, stated plainly:**

| Cheap | Moderate | Expensive |
|---|---|---|
| Adding a project/package (spec edit + regenerate) | Splitting shared code out of an app | Access-control pass across an extracted module |
| Workspace file regeneration | Scheme re-sharing + CI matrix growth | Localization/bundle rewiring if `L10n` wasn't bundle-aware |
| Root lint config — unchanged at every tier | `Package.resolved` relocation | Theme token split into base + per-app overrides |
| Adding a second app *from the start* | Per-app Info.plist/entitlements duplication | Adding a second app *after* two years of app-coupled code |

The last row is the actual decision: at T3 from day one, a second app is a weekend. Retrofitted onto a single-target app with no module boundaries, it's a quarter. Q1's recommendation ("T3 the moment a second app is on the roadmap") is that asymmetry, not a preference for ceremony.

### 3.11 Ownership rules once there is more than one module or app

Multi-module breaks three rules that read as absolutes earlier in this document. These are the corrected versions, and they apply from T2 onward — including under Q1's default answer.

- **Localization is per resource-owning module, not per repo.** `NSLocalizedString` resolves against a bundle: a framework that ships user-facing views must carry its own locales, or its strings silently fall back to the key at runtime in the consuming app. So every module that has UI owns one `Localization/Localizable.xcstrings` — a String Catalog holding every locale for that module in a single file (§8.5) — and its generated `L10n.swift` is **bundle-aware**: the accessor resolves through that module's own bundle, never `Bundle.main`. This is also why `L10n.swift` is generated at all rather than deferring to Xcode's own String Catalog symbol generation — bundle resolution across a framework boundary is the one property a shared module cannot afford to get wrong at runtime, and generating the accessor is what makes it explicit. Keys are namespaced by module (`shared.error.retry`, `app.settings.title`) so two modules can't collide, and `Scripts/check_strings.sh` verifies key parity across locales *within* each module and flags cross-module duplicates (§8.5). At T1 — and only at T1 — there is one module, so this collapses to one app-level `Localization/`.
- **Theme is base + override, not one file.** Base tokens (the full palette, type scale, spacing) live in the shared module's `Theme/`. Each app owns a thin `Theme/` of its own that overrides only what actually differs — brand color, maybe a font family — and adds nothing else. `/update-theme` must ask which layer a token belongs in and refuse to write an app-specific value into the shared module (§4.5). Two apps that each redefine the whole palette are not sharing a design system, they're maintaining two. **Both layers start flat and split by token family, never by file count**: `ColorTokens.swift` + `Typography.swift` on day one, and a `Font/`, `Color/` or `Size/` folder only once that family outgrows one file — a shipped app (§8.1a) reaches four files of type handling alone (family, scale, Dynamic Type helper) before it needs one. Subfolders cost nothing mechanically: `check_hardcoded_colors.sh` skips any path containing `Theme/` at any depth. The per-app override stays a single `Theme.<App>.swift`; an app whose overrides need a folder is redefining the palette rather than overriding it.
- **Per-component styling is a theme token, not part of the view.** A component's fills, insets and per-variant typography live in `Theme/ComponentStyles/<Component>.swift` and the component in `DesignSystem/Views/` reads them — that is what keeps a per-app restyle inside the override layer instead of forking the view (§3.6). Observed in production as `Theme/Views/Buttons.swift` (§8.1a); **this template names it `ComponentStyles/`**, because a second folder called `Views` — one holding views, one holding styles — is precisely how a real view ends up in the theme layer.
- **Assets, icons, permissions and identity are per app, always.** Asset catalogs may exist in both shared modules and apps (shared iconography vs. brand art), but `AppIcon`, `Info.plist`, `.entitlements`, bundle ID, display name and signing are app-target-only. Any Skill touching those must resolve *which app* before acting (§4.2–§4.4).

One more, which the config makes mechanical rather than a matter of taste: **`/new-feature` needs a target module.** "A screen in one app" and "a base view both apps extend" are different destinations with different visibility requirements. The Skill takes `--module`, defaults to the config's declared default app at T1/T2, and at T3 with more than one app **refuses to guess** (§4.1).

---

### 3.12 When the project must be regenerated

`/start` generates the `.xcodeproj` from `project.yml` (or `Project.swift`), and the generated project is committed (§8.8). That means the file list Xcode builds from is a **snapshot**, and it goes stale silently: a file that exists on disk but isn't in the snapshot simply isn't compiled, with no error pointing at the cause. Every Skill that adds a file therefore ends by regenerating, and a developer working by hand has to know the same rule.

**The rule is about the set of files and folders, not their contents.** Regenerate when the answer to "does a path exist that didn't before, or has one stopped existing?" is yes — or when the spec itself changed:

| Regenerate after | Don't bother after |
|---|---|
| Adding, deleting, renaming or moving **any** source file | Editing an existing source file |
| Adding a folder — a new `Features/<Name>/`, a new layer directory | Adding an entry inside a file that's already referenced |
| A module's **first** `Localization/Localizable.xcstrings` | Adding a key, a translation, or a whole **locale** to an existing catalog |
| A target's **first** `Assets.xcassets` | Adding an image set, color set or app icon inside an existing catalog |
| Any edit to `project.yml` / `Project.swift` — a new target, dependency, build setting, or `Info.plist` key | Editing `Secrets.xcconfig` (an xcconfig is read at build time, not baked into the project) |
| Adding or removing a package dependency | |

Two consequences worth stating, because both surprise people:

- **A new locale used to require a regenerate and now doesn't.** Under per-locale `.lproj/Localizable.strings`, adding a language created a folder and a file, so it landed squarely in the left column — the app would build and silently ship without the new language until someone ran `xcodegen generate`. With one String Catalog per module (§8.5) the file already exists and is already referenced, so a new locale is a content edit. XcodeGen additionally derives `knownRegions` from the catalog, so the project's language list stays correct on the next regenerate without anyone hand-maintaining it.
- **Xcode adding a file for you doesn't exempt you.** If a file is created in Xcode's UI, Xcode writes it into the `.xcodeproj` directly and the build works immediately — but the *spec* is still the source of truth, and the next regenerate rebuilds the project from disk. That happens to produce the same result here, since XcodeGen globs directories; the habit that breaks is hand-editing project settings in Xcode's inspector, which the next regenerate discards. Settings belong in `project.yml`.

When in doubt, regenerate: it is idempotent, takes under a second, and its only cost is a `pbxproj` diff — which is precisely the diff that should appear in the same commit as the file that caused it.


---

## 4. The Other Skills

Each checks §1.3's precondition first, then reads `ios-skeleton.config.json` to know which architecture/UI framework/navigation style **and topology** is in force — never asks the developer to re-specify it per invocation.

**Model tier, declared in each Skill's frontmatter.** Every `SKILL.md` — `/start` included — declares its model, so the tier is a property of the work the Skill does, not of whatever model the developer's session happens to be on. The alias form (`opus`) is used deliberately over a pinned model ID: these files are copied into projects that outlive any one model generation.

| Tier | Skills | Why |
|---|---|---|
| `model: opus`, `effort: high` | `/start` (§2), `/new-feature` (§4.1), `/add-module` (§4.7), `/add-app` (§4.8) | Irreversible or cross-cutting. `/start` writes the config every other Skill reads and owns the Path 3 adoption branch (infer topology from an existing project, read the real deployment target, detect the feature-folder convention, dry-run the checks, decide per-file what may be overwritten) — a wrong answer here propagates into every feature generated afterward. `/new-feature` is deterministic only for §1.4's four authored combos and falls back to agent-assisted generation otherwise. `/add-module` and `/add-app` rewire every consumer and the tier's whole spec/scheme set. These four are pinned precisely so they cannot quietly run on a cheaper session model. |
| `model: inherit` | `/add-assets`, `/update-app-icon`, `/add-permission`, `/update-theme`, `/status`, `/translate`, `/add-secret` | Bounded, single-destination edits over an already-decided architecture, each backed by a script that refuses an ambiguous destination. Nothing here justifies overriding the developer's own `/model` choice, so they inherit it. |

A pinned `model:` **replaces** the session model for that Skill's run — there is no per-invocation override flag, and `/model` cannot lower a pinned Skill. The escape hatch is editing the frontmatter in the project's own copy (`inherit` hands the choice back to `/model`). Any Skill added later declares one of the two tiers explicitly; an absent `model:` key is a defect, not a third tier.

Two known edges, both accepted rather than worked around. A bare `opus` alias is not the same selectable model as *Opus (1M context)*, so a developer running a 1M-context session may drop to the standard window for the duration of a pinned Skill — accepted, because a pinned model ID carrying the `1m` tag is exactly the staleness this alias choice avoids, and standard-window Opus at high effort still beats an inherited cheaper model for this work. And where an org restricts models (`availableModels`), a pinned alias that isn't on the allowlist is discarded and the session model is kept — the Skill still runs, just not necessarily at its declared tier.

Because `/start` §0 copies `.claude/` into the target project, these tiers propagate into every project scaffolded from this template — that is the intent, not a side effect. The copy is merge-only, so a project that already carries its own `.claude/skills/` (an adopted repo, or one scaffolded before this key existed) keeps it untouched and does not gain the keys on a re-run.

**Topology branch, applied by every Skill below.** At T1 there is one destination and no question to ask. At T2/T3 the config lists modules and apps; each Skill resolves its destination in this order: an explicit `--module`/`--app` argument → the config's declared default → **stop and ask**. No Skill may guess a destination when the config declares more than one candidate, and none may write into a module whose kind forbids it (a framework can't own an `Info.plist` permission; a leaf logic package can't own an asset catalog).

### 4.1 `/new-feature [--module <M>] <name> "field:Type,..."`

**Invocable in prose, but never on a guess.** The Skill is expected to be reached both by the argument form above and by plain English ("add a films list screen showing the title and release year") — the script only ever receives the argument form, so the Skill is what translates. Because that translation *invents* information the developer never supplied, the Skill must batch-ask the three things prose cannot carry, skipping any the invocation already answered explicitly, and must echo the resolved command before running it:

Ask them in this order, because the second depends on the first:

1. **Target module** — ask before invoking whenever `ios-skeleton.config.json` leaves more than one candidate, rather than letting the script's refusal (§4's topology branch) be how the developer discovers the ambiguity. The feature directory, test directory and `Localizable.xcstrings` all hang off the resolved module, and generated keys are namespaced `<module>.<feature>.*`.
2. **Grouping** — flat `<module>/Features/<Name>/` by default; ask with the concrete alternative whenever the request implies a section or flow, or the resolved module's feature directory already has group folders. There is no fixed `Features/` path to inspect until step 1 is settled.
3. **Field list and Swift types** — never inferred from English nouns. Propose a typed list, flag the genuinely ambiguous ones (an "avatar" is `URL`/`String`/`Data`; an "amount" is `Decimal`/`Double`), and confirm. An empty field list is legal and yields a property-less model — that is a decision to state, not a default to assume.

The rationale is that none of the three is cheap to reverse: models land in the shared `Models/` where a colliding type name stops the run, the script refuses if the feature folder already exists, and a feature generated into the wrong module has to be moved by hand along with its strings and access modifiers. This establishes the general principle — *an agent-chosen default is acceptable only where it is both stated and trivially reversible* — and two Skills now implement it: `/new-feature` and `/add-secret` (§4.10), which batch-asks key names, values, exposed Swift types and target apps before touching four files. The rest (`/add-assets`, `/add-module`, `/add-app`, `/update-theme`, `/translate`, `/add-permission`) still rely on their script refusing an ambiguous destination, which surfaces the same question later and less usefully. Extending the batched-confirmation pattern to them is a deliberate follow-up, not something already built.

Generates, end to end, per §3.2's layer shape for the project's chosen architecture:

- Business layer: for MVVM (default), the ViewModel depends on the data layer's *protocol* directly — no separate business-logic layer is generated by default (§3.8). For VIP/VIPER, the Interactor is this layer: one operation, pure Swift, no UI/networking imports. Never generate a `UseCase` — if a feature's ViewModel later needs to orchestrate more than one repository/service, add an `Interactor` instead (§3.8, §8.2).
- Data layer (Repository + Service): protocol + implementation, wired to the chosen networking stack (`Networking/RequestBuilder.swift` + `APIClient.swift` — never a second networking path). The protocol is declared where it's consumed, named for the capability rather than the type it abstracts (§8.2).
- Presentation layer (ViewModel/Presenter/Controller + View): matching the chosen UI framework, as a flat set of files directly in `Features/<Name>/` — see §3.2.
- Reads `docs/product/` first (§5.2). Where the requirement states a screen's fields, types, states or endpoint, that document is the source — the confirmation step below becomes "here's what the spec says, correct?" rather than an invention. An absent or silent requirement is normal and not a blocker; a contradictory one is a question, not a coin toss. Never work from a summary of a requirement — these documents change constantly, so re-read per invocation.
- Local persistence, only when Q4 isn't `None` (§3.8): a `<Name>LocalStore.swift` in the feature folder, its protocol declared beside the remote one in the consuming layer, a `<Name>Record` appended to `Models/` and registered with the app's container schema (SwiftData), and the store passed into the composition-root factory. With `persistence: None` none of this is generated and the feature is remote-only.
- Models: writes `Models/<Name>Models.swift` in the shared package (§3.2/§3.7), never a file inside the feature folder. If a type name in the new feature's field list collides with an existing type already in `Models/`, stops and asks rather than silently overwriting or shadowing it.
- Navigation: registers the new screen with whichever mechanism Q6 selected — a new `Router`/`Route` case or a new `start()` method on the feature's `Coordinator` — never a second, ad-hoc path. If part of a tab-bar flow, wires into that tab's own stack only (§3.5).
- If the field list includes a search-as-you-type input, wires it through `Core/Utilities/Debouncer.swift` rather than firing a request per keystroke.
- Destination: resolves the target module per §4's topology branch before generating anything. Accepts a grouped path (`/new-feature Settings/Profile`) per §3.2. If the resolved module is a shared framework rather than an app, every generated type the app must see is `public` with an explicit `public init` — the single most common reason an extracted module doesn't compile from its consumer (§3.10).
- If the feature introduces new user-facing text, adds it to **the target module's** `Localizable.xcstrings` with that module's key namespace and re-runs `Scripts/generate_strings.sh <module>` rather than hardcoding a string literal (§3.11).
- A **real, passing unit test** against a fake dependency — not a placeholder. With persistence on, a second test class covers the read-through policy itself against a fake local store (and, for VIP/MVC, a fake `APIClient`), since that policy is the densest logic generated per feature. Fake values default sensibly by type (`String → "test"`, `Int/Double → 0`, `Bool → true`, `Date → .now`, `Optional<T> → nil`); an unrecognized/custom type still compiles but fails loudly at test runtime (`fatalError("TODO: provide a fake value for <Type>")`) rather than silently guessing wrong.
- Refuses to run if the feature folder already exists.
- Leaves exactly the follow-ups that can't be automated — e.g. the real API endpoint — as `TODO.md` entries.

### 4.2 `/add-assets [--module <M>] <name>`

- Accepts one vector source (PDF/SVG, "preserve vector data") or three raster files explicitly labeled 1x/2x/3x.
- Validates with `sips` that 2x/3x are exact 2×/3× the 1x pixel dimensions; **refuses rather than silently accepting a mismatched scale set.**
- Writes `Assets.xcassets/<Name>.imageset/` with correct filenames and `Contents.json` — into the resolved module's catalog (§4's topology branch). Shared iconography belongs in the shared module; brand art belongs in the app.
- Generates/updates a typed accessor (e.g. `DesignSystem/Assets/ImageAssets.swift`) so features reference `Image.<name>` instead of a magic string. In a framework, that accessor resolves through the framework's own bundle, not `Bundle.main` (§3.11) — otherwise the image is nil at runtime in the consuming app while everything still compiles.

### 4.3 `/update-app-icon [--app <A>] <path-to-1024-png>`

- Requires exactly one 1024×1024 PNG with **no alpha channel** — validates and refuses otherwise.
- Replaces the modern single-size `AppIcon.appiconset`, or regenerates every required size via `sips` if a legacy multi-size iconset is present.
- Touches only `AppIcon.appiconset`, in exactly one app. With more than one app declared, `--app` is required — it must never silently re-icon both.

### 4.4 `/add-permission [--app <A>] <permission>`

- Maps a plain-language permission to its exact `Info.plist` `NSXxxUsageDescription` key(s), in the **app target's** plist — a framework cannot declare a permission, so if the requesting code lives in a shared module, the key still goes in every app that ships it, and the Skill says so explicitly.
- Inserts a real, reviewable usage string — never blank — marked `// TODO: confirm exact wording with product/legal`.
- Flags permissions needing a Capability toggle beyond Info.plist (Push, HealthKit, Sign in with Apple, background modes) and tells the developer this needs a manual toggle **plus** the matching entry in that app's `.entitlements` file.
- Appends the permission + justification + which app(s) it applies to, to `docs/PERMISSIONS.md`.

### 4.5 `/update-theme [--layer base|app --app <A>]`

- Adds/edits a token in `Theme/ColorTokens.swift`/`Typography.swift`, or in the family folder that file has since split into — **never** `Assets.xcassets`. See §6. Per-component styling goes in `Theme/ComponentStyles/`, never a `Theme/Views/` (§3.11).
- Every color token is a light/dark pair exposed as both `Color` and `UIColor` from the same value.
- Resolves the layer per §3.11: a new token in the shared base, an override in one app's theme. Refuses to write an app-specific value into the shared module, and warns when an app override shadows a base token it doesn't actually differ from.

### 4.6 `/status`

Computed fresh every call: topology tier and the module graph (each module, its kind, and who depends on it), features per module, whether SwiftLint passes, open `TODO.md` items, whether every module is referenced by at least one consumer and every project is listed in the workspace file, whether each app's scheme is shared, and whether `Package.resolved` sits at the tier-correct location (§3.10). No full build/test unless asked.

### 4.7 `/add-module <name> [--kind framework|package] [--deps A,B]`

The additive half of §3.10's migration path.

- Refuses at T1 with the reason: adding a module *is* the T1 → T2 migration; prints those steps and asks the developer to confirm the tier change first.
- Creates the module's folders, spec (`Package.swift` or `project.yml`), test target, and — if it owns UI — its `Localization/` + `Assets.xcassets` and a bundle-aware `L10n` (§3.11).
- Wires it: adds the dependency to each declared consumer's spec, regenerates, and at T3 re-runs `Scripts/generate_workspace.sh`.
- Enforces the dependency rule from §3.9 — a module may not depend on an app, and a cycle is a hard refusal, not a warning.
- Records the module, its kind, and its consumers in `ios-skeleton.config.json`, and appends a line to `docs/PROJECT_MAP.md`.
- Generates one real compiling type and one passing test, so the module is proven wired before anyone moves code into it.

### 4.8 `/add-app <name>`

- Requires T3, or offers the T2 → T3 migration first (§3.10) — never performs it silently.
- Asks for that app's identity (Q12 again: display name, bundle ID, team) and creates the app project, spec, shared scheme, `Info.plist`, `.entitlements`, and asset catalog with a placeholder icon.
- Declares dependencies on the existing shared modules and generates the app shell **by extending the shared base views**, plus one starter feature — so the sharing seam is exercised immediately (§2.1 step 10) rather than being asserted in a doc.
- Creates that app's own theme override layer (§3.11) and its own String Catalog, seeded from the shared module's key list.
- Adds the project to the workspace and regenerates; appends both the app and its per-app manual follow-ups (signing, App Store record, push certs) to `TODO.md`.
- Does **not** copy features from the existing app. If two apps need the same screen, it belongs in a shared module — the Skill says this rather than duplicating, because a copied screen is the fastest way to lose the value of T3.

### 4.9 `/translate [--module <M>] <locale-code> [locale-code...]`

Resolves §10's former "no localization Skill" gap. Drafts target-locale entries; never a substitute for a human review pass before shipping.

- Resolves the target module the same way §4.1 does (`--module` → config default → single-module fallback → ask).
- Reads that module's source language in `Localization/Localizable.xcstrings` (the only locale `/new-feature`/`/add-permission` write to) as the source of truth.
- Adds each requested locale into that same catalog — a String Catalog holds every locale in one file, so a new locale creates no new file and no new folder. It writes only the entries `check_strings.sh` reports as missing for that locale, and never touches an entry a human has already translated.
- Every newly drafted entry is agent-translated from the source string and written with the catalog's own `"state": "needs_review"` — the format's native review marker, which Xcode's String Catalog editor surfaces directly, rather than a comment convention layered on top of it. `check_strings.sh` reports the outstanding count without failing the commit.
- Writes through `Scripts/lib/xcstrings.py`, never by hand-editing JSON, so the file keeps Xcode's own formatting and a catalog this Skill touched produces no spurious diff the next time Xcode rewrites it.
- Re-runs `Scripts/generate_strings.sh <module>` afterward so the new locale's keys are covered by the same `L10n.swift` accessor as every other locale — `/translate` adds *strings*, it never changes what `L10n` exposes, since the base locale's key set is unchanged.
- Does not decide which locales a project ships — that's an explicit argument every invocation, never a guessed default, and not part of `/start`'s questionnaire (§2.2). A project records its shipped locale list wherever it already tracks product decisions (`docs/PROJECT_MAP.md` is the natural place); this Skill only fills in what's asked for.
- Refuses the same way every other Skill does if `ios-skeleton.config.json` is missing (§1.3), and if the base locale itself has keys `check_strings.sh` reports as inconsistent — fix the source of truth before drafting more locales from it.


### 4.10 `/add-secret [--app <A>] [KEY=value ...]`

The write path for everything that varies by environment, the base URL included (§8.3). A configuration key is only useful when four things exist, and this Skill's whole job is that none of them is left out: the value in `Secrets.xcconfig`, the key in the committed `Secrets.xcconfig.example`, a `$(KEY)` entry in **each** app target's `Info.plist`, and a typed accessor on `AppEnvironment`. An xcconfig assignment is a build setting, not a runtime value — a key with no plist entry is invisible to Swift, and a key missing from the example fails the next commit under `check_secrets.sh`.

- **Batch-asks before writing** (the §4.1 pattern, and the second Skill to implement it): key names, values, the Swift type each is exposed as, and — with more than one app — which apps get the plist entry.
- **`Scripts/add_secret.sh` owns the two config files.** It appends the real value to `Secrets.xcconfig` and a *placeholder* to `Secrets.xcconfig.example`, refuses a duplicate or malformed key, and applies the `$()` comment escape to any value containing `//`. That last one matters beyond URLs: `check_secrets.sh` shape-checks `API_BASE_URL` only, so for every other key this rewrite is the sole thing between a pasted URL and a silent truncation at the scheme.
- **It refuses to write a live credential, rather than warning about it** — same principle as §8.6's logging module: this template ships the mechanism. A vendor-prefixed token (`sk-`, `ghp_`, `AKIA`, `eyJ`, `-----BEGIN`, …), a long high-entropy blob, a 32+ digit hex string, or anything whose key name contains `KEY`, `SECRET`, `TOKEN`, `PASSWORD`, `PASSWD`, `CREDENTIAL(S)`, `PRIVATE`, `CERT`, `SIGNING`, `DSN`, `AUTH`, `APIKEY` or `PAT` and whose value isn't an obvious placeholder is written **commented out in both files** — the permitted-but-not-required state the shipped `API_KEY` line already occupies and `check_secrets.sh` already accepts — and the developer uncomments the line in the gitignored `Secrets.xcconfig` and pastes the value in by hand. The enforcement is in the script, not only in the Skill's prose, because the Skill is normally driven by an LLM and prose is exactly what an LLM can talk itself out of. The name half of that list is deliberately over-broad — `AUTH_BASE_URL` gets held back although a base URL is not a credential, because a webhook URL under the same name would be. One manual paste is the cost of a false positive; a false negative puts a live key in a transcript. The rationale is in §8.3's last bullet.
- **`AppEnvironment` normally already exists** — `/start` §1.7c renders it on any project that has a key, so this Skill appends an accessor to it. It renders the file itself only on a project that started with none (`networking: none`), from `Scripts/templates/config/AppEnvironment.swift.template`, into Core at the tier-correct path (the same table §1.7a uses for `PersistenceController`: `<app>/Core/Configuration/` at T1, `Packages/Core/Sources/Core/Configuration/` at T2, the `role: "core"` module's `Sources/<Name>/Configuration/` at T3). It lives in the shared module, not the app, so a feature in any module can read configuration without the app threading it down — `Bundle.main` resolves to the app bundle even from inside a package or framework. That same fact makes it untestable from a package test bundle, which is why the type takes an injectable lookup defaulting to `Bundle.main`.
- **One accessor per key**, at the `// MARK: add-secret-insertion-point` marker this Skill owns (the `new-feature-model-insertion-point` precedent), using typed readers — `string`/`url`/`bool`/`int` — that trap with the same three distinct messages the composition root uses: key absent, value empty, value unparseable. Nothing else in the app calls `Bundle.main.object(forInfoDictionaryKey:)` once this file exists.
- **`API_BASE_URL` is already an accessor on this type**, written by `/start` — don't add a second one, and don't reintroduce a reader in the composition root, which passes `AppEnvironment.current.apiBaseURL` into `RequestBuilder` (§3.7).
- Regenerates each touched spec (and `Scripts/generate_workspace.sh` at T3), runs `check_secrets.sh`, and records the key — never a held-back value — in `docs/PROJECT_MAP.md` and `TODO.md`.

---

## 5. Meta Files ("AI Brain")

| File | Rendered by | Forces the agent to... |
|---|---|---|
| `CLAUDE.md` | `/start`, from `CLAUDE.md.template` | Know the tech stack, chosen architecture, **topology tier and module graph**, and where deeper rules live — auto-loaded every session |
| `docs/ai/architecture.md` | `/start`, from `.template` | Use the one architecture pattern chosen at setup — no mixing patterns feature-to-feature |
| `docs/ai/modularization.md` | `/start`, from `.template` | Know the tier, the module graph and its direction, which module owns strings/assets/theme tokens, and what `--module` defaults to — the rules from §3.9–§3.11 rendered for *this* repo only |
| `docs/ai/theming_rules.md` | shipped as-is in the template | Route every color/font choice through a `Theme/` directory — the shared module's for base tokens, the app's for overrides (§3.11) |
| `docs/ai/ui_rules.md` | shipped as-is | Mandatory `#Preview`, no hardcoded strings — use the owning module's `L10n.<key>` (§3.7, §3.11), never a raw catalog key, never `Bundle.main` from inside a framework — real/explicit-`nil` accessibility labels — SF Symbols over imported icon assets wherever a symbol exists, `AsyncImage` for remote images by default (§6, §10) |
| `docs/ai/permissions_rules.md` | shipped as-is | Never add a permission without a non-empty usage string, a named app target, and a `docs/PERMISSIONS.md` entry |
| `docs/PROJECT_MAP.md` | `/start` seeds it, features and modules append | One line per file/folder not covered by the feature-first convention, the module list with each module's kind and consumers (§4.7), plus which architecture combos are template-backed vs. agent-assisted (§1.4) |
| `docs/CODING_STANDARDS.md` | shipped as-is | SwiftLint rules, naming, force-unwrap policy, `// MARK:` organization, and §8.2's protocol-boundary rules — dependencies are protocols, app-specific behaviour is injected, no branching on which app is running inside shared code |
| `docs/GIT_CONVENTIONS.md` | shipped as-is | Feature-based commits, message format, optional branch naming |
| `docs/ONBOARDING.md` | `/start`, **written fresh** (no `.template` — the copy that arrives with the template describes the template system, §1.2) | What this project is, day-to-day prompting guidance |
| `README.md` | `/start`, **written fresh** (same reason) | Tech stack, structure, getting-started, troubleshooting — for the real app, not the template |
| `docs/product/*` | **nobody** — the developer writes these, `/start` only creates the folder and its README | Read the actual requirement before implementing a feature — see §5.2 |
| `docs/PERMISSIONS.md` | created on first `/add-permission` | Running list of every declared permission + justification |

### 5.1 Xcode's own coding intelligence — interoperate, don't compete

Xcode now runs coding agents natively (Claude Agent, Codex) under **Xcode ▸ Settings ▸ Intelligence**. This template's surface is Claude Code in the terminal — `Scripts/` and the `core.hooksPath` hooks are terminal-side regardless of which agent drives them. Four facts change what `/start` should do, all verified against Apple's Xcode documentation. **Explicitly not established:** whether the in-Xcode Claude Agent loads a repo's `.claude/skills/`. Apple documents only that agent config under `~/Library/Developer/Xcode/CodingAssistant/` applies to in-Xcode launches; it says nothing about project-level Skill discovery. Do not write either claim into a rendered doc as settled.

1. **Xcode exposes its capabilities to external agents over MCP.** With **Intelligence ▸ Model Context Protocol ▸ "Allow external agents to use Xcode tools"** enabled, `xcrun mcpbridge` bridges an agent launched outside Xcode into the open project — build, test, and project actions run through Xcode itself instead of a reconstructed `xcodebuild` invocation. Registration is one line: `claude mcp add --transport stdio xcode -- xcrun mcpbridge`. The project must be open in Xcode, and Xcode notifies the developer on connect and while active. **`/start` must add this to `TODO.md` as an offered, optional step** — never run it silently, since it changes machine-level agent configuration outside the repo.
2. **Agent permissions are global to the Mac, not scoped to the repo.** **Intelligence ▸ Agents ▸ Permissions** holds the Allowed Commands / Allowed Tools lists, accumulating whatever was approved in any transcript, and applies across every project. Nothing this template writes can scope, audit or version that list — say so rather than implying the repo controls it.
3. **In-Xcode agent config lives outside the repo.** Files under `~/Library/Developer/Xcode/CodingAssistant/` (e.g. `ClaudeAgentConfig`) affect agents *launched in Xcode only*. The repo's `CLAUDE.md` is read by both surfaces, but Xcode expects it beside the `.xcodeproj` — repo root at T1/T2, which is **not** automatic at T3 where each project sits in its own folder. At T3, `/start` and `/add-app` should note this in `TODO.md` rather than assume the root file is found.
4. **Xcode's localization agent and this template now target the same format.** Xcode adds languages, populates `.xcstrings`, and marks entries Machine Translated (`state-qualifier: leveraged-mt` on XLIFF export); `/translate` (§4.9), `generate_strings.sh` and `check_strings.sh` all read and write that same per-module String Catalog (§8.5). A developer can add a language in Xcode's String Catalog editor and a `/translate` run will fill it in, or the reverse, without either side losing the other's work — one source of truth, two editors. What still differs is the review marker: Xcode's XLIFF round-trip uses `state-qualifier: leveraged-mt`, while `/translate` writes the catalog's own `needs_review` state. Both mean "not human-checked"; neither clears the other, so a locale can carry both and should be reviewed against both.

### 5.2 `docs/product/` — the domain slot, and why it's exempt from everything above

Every file in §5's table is generated, rendered or shipped by this template. `docs/product/` is the one place that isn't, and it's deliberately the only part of the repo that carries what the app is actually *for*: the PRD, the SRS, API contracts, a glossary, whatever a given project keeps.

This template is a build system for iOS projects, not for one product. The domain arrives later — after `/start`, often weeks later — and then keeps changing: a PRD is rewritten mid-sprint, an SRS grows a section after sign-off, an endpoint changes shape twice before launch. Three consequences, and they're rules, not observations:

- **Pointer, never summary.** `CLAUDE.md` links to `docs/product/` and does not digest it. A summary of a living document is stale within weeks and is worse than no summary, because it reads as current. Every Skill that needs a requirement re-reads the file at the start of that task.
- **Create-if-missing, never overwrite, never render.** `/start` creates the folder and the shipped `README.md` explaining the slot; nothing else. A re-run doesn't touch it (§2.4), and on Path 3 an adopted repo's existing product docs stay exactly where they are (§2.1 step 13).
- **Incomplete is the normal state.** A `TBD` or an open question is not an error to resolve before work can proceed. Where a requirement an agent needs is genuinely missing or self-contradicting, it asks and the answer is written back into `docs/product/` — not left in a chat transcript.

`/new-feature` is the concrete consumer today (§4.1): it reads the requirement before proposing field names and Swift types, so a spec'd field list beats an inferred one, and it says which document it drew from. Traceability stays lightweight on purpose — a feature notes its requirement in a commit message or in `docs/PROJECT_MAP.md`; there is no generated requirement-to-code matrix, because keeping one accurate by hand is work nobody does twice.

---

## 6. Theming — the one explicit deviation from stock Xcode convention

**Do not define colors as Asset Catalog color sets.** Define every color and font as a Swift value in a `Theme/` directory — `DesignSystem/Theme/` for base tokens, the app's own `Theme/` for overrides (§3.11):

```swift
enum ThemeColor {
    static let primary = Color(
        light: UIColor(red: 0.09, green: 0.45, blue: 0.91, alpha: 1),
        dark:  UIColor(red: 0.36, green: 0.65, blue: 0.98, alpha: 1)
    )
    // ...
}
```

Why: one typed, compiler-checked source of truth usable from both SwiftUI and UIKit instead of string-keyed Asset Catalog lookups that fail silently on a typo; enables `check_hardcoded_colors.sh` to mechanically catch a stray literal; keeps light/dark handling a one-file change. The multi-module payoff is bigger still: a Swift token crosses a framework boundary as a `public static let`, whereas an Asset Catalog color needs the right bundle at every lookup site and fails at runtime when it doesn't get one (§3.10).

From T2 onward this splits into base tokens in the shared module and a thin per-app override layer — see §3.11 for which layer owns what, and §4.5 for how `/update-theme` enforces it. At T1 there is one layer and nothing to decide.

Applies to **colors and typography**. A spacing scale (`Spacing.swift`) is optional — see §10.

**Icons and images (§10):** prefer SF Symbols (`Image(systemName:)`/`UIImage(systemName:)`) over an imported icon asset wherever a suitable symbol exists — one bundled system font instead of a growing set of PDF/SVG assets per icon, free light/dark and Dynamic Type behavior, and no `check_hardcoded_colors.sh`-style asset-catalog problem to enforce against in the first place. Reserve `Assets.xcassets` for genuinely custom iconography/artwork a symbol can't express. Remote images (avatars, thumbnails, hero art) load via SwiftUI's built-in `AsyncImage` by default — see §10 for when that default stops being enough and a caching library becomes the right call.

---

## 7. Code Style & Enforcement

Applies both to the template's own scripts (Phase A) and to whatever `/start`/the other Skills generate (Phase B):

- **One `.swiftlint.yml` at repo root, at every tier** — never one per module. Each project/package wires it as an Xcode Run Script build phase (and/or SPM build tool plugin) so violations surface as build warnings, all pointing at the same root config. Per-module overrides are `included`/`excluded` paths in that one file, not separate files that drift.
- SwiftLint's version is pinned like any other dependency (via SPM at the workspace level, or Mint/Homebrew recorded in `docs/ONBOARDING.md`) — an unpinned linter turns a version bump into a repo-wide diff, which is a real and recurring cost on shared codebases.
- Project-specific `custom_rules` (regex-based) are legitimate and expected — brace style, forbidden APIs, required preconditions. The template ships a small, conventional default set; a team's house style replaces it wholesale rather than being argued with piecemeal.
- `Scripts/lint.sh` wraps `swiftlint lint --strict` for CI/pre-commit, across every module.
- `Scripts/check_hardcoded_colors.sh` scans staged Swift files for `UIColor(red:`/`Color(red:`/hex-literal construction outside any `Theme/` directory and blocks the commit.
- `Scripts/check_strings.sh` checks localization health across modules and locales — see §8.5.
- `Scripts/check_secrets.sh` checks `Secrets.xcconfig` health — empty values, key parity with the committed `.example`, and `API_BASE_URL`'s shape — see §8.3.
- `.githooks/pre-commit` (wired via `core.hooksPath` by `/start`) runs these plus the test suite on any staged `.swift` change. **`check_secrets.sh` is the exception: it runs on every commit, before the staged-`.swift` early exit.** `Secrets.xcconfig` is gitignored, so it can never appear in a staged path — gating it on staged files would mean the check never fires for the one file it exists to check. At T3 it runs tests only for the modules whose files are staged, plus their dependents — running every app's full suite on every commit is how a hook gets disabled by the team.
- `.githooks/commit-msg` (§10, resolved) checks the message's first line against `docs/GIT_CONVENTIONS.md`'s format — `(<TICKET-ID> )?<type>: <summary>` with `<type>` one of `feat`/`fix`/`refactor`/`test`/`docs`/`chore` — and rejects the commit with the expected pattern on a mismatch. It checks shape only, never content: it can't tell a well-written summary from a lazy one, only that the format is there.
- **Generated code carries documentation, not provenance.** Every generated type, protocol, property and function gets a `///` doc comment saying what it is or does, in one or two lines. What generated code must *not* carry is commentary about the template that produced it: no section references (`§3.7`), no "rendered from `X.swift.template`", no explanation of why the template made a structural choice. That reasoning belongs in `docs/ai/architecture.md` and this document, which is where a reader goes to ask *why*; a file in `Features/Home/` is read to find out *what*, and a paragraph of template rationale at the top of it is noise that ages badly — it survives refactors that invalidate it, and it points at a document numbering scheme the project itself doesn't use. The same rule binds the agent: when a Skill writes a file, it documents the code and says nothing about the template.
- **Generated config files get a header, not an essay.** `Secrets.xcconfig`/`.example` and anything else generated in a non-Swift format carry a short header — what the file is for, the one syntax trap it has, and a pointer to `docs/CODING_STANDARDS.md` for the full rules — never a restatement of that document. Per-entry comments exist only where there is an action to take (a key deliberately left commented out because its value is missing); a key with a value needs none, because the assignment already says everything. This is the same failure mode as §7's provenance comments in a different file format: prose that reads as authoritative, ages badly, and pushes the actual content off the screen.
- `docs/CODING_STANDARDS.md` documents the conventions, separating tool-enforced from convention-only.

---

## 8. Production-Readiness Baseline

Everything above gets a project *compiling*. This section is what separates that from a project a team ships from for years.

It is calibrated against a long-lived, multi-app iOS workspace in production — two apps for different audiences sharing one framework spine plus small leaf frameworks, ~20 feature flows per app, 18 localizations, several years of history. Nothing from that codebase's domain, product names or module names is carried into this template; what's carried is the *structural evidence* about localization, theming, navigation, module boundaries and protocol-based abstraction. Every generated name in this document is a placeholder resolved from `/start`'s answers.

**Read the labels.** *Observed in production* = a practice that has survived years of contact with a shipping app of this shape, cited as evidence rather than as a name to copy. *Recommended* = this template's opinion. Don't launder one into the other.

### 8.1 Per-app build configuration, schemes and signing

- *Observed in production:* each app is its own project with its own `Info.plist`, `.entitlements`, asset catalog, fonts and animations, and a **shared scheme named after the shipped product**, not after the target. Framework projects ship shared schemes too, so each module is independently buildable and testable.
- *Observed in production:* only `Debug`/`Release`, no `.xcconfig` layer. Plain configurations are a legitimate, low-friction choice even at multi-app scale — this is evidence against premature build-config machinery.
- *Recommended:* move build settings into `.xcconfig` files (a shared base + per-app + per-configuration) once you have a third configuration or a second app, so an environment-specific value is a one-line diff instead of a spec edit in N places. Adopt when the pain appears, not preemptively.
- **Non-negotiable at any tier:** every scheme a human or CI needs is *shared* (`xcshareddata/xcschemes/`) and committed. An unshared scheme exists only on the machine that created it — the most common way a T3 workspace "works locally, fails in CI".
- `/start` and `/add-app` generate the shared scheme; `/status` reports any scheme that isn't shared.

### 8.1a Folder shapes, observed

The reference repo here is a **T3 workspace**: two shipped apps (a consumer app and a pro app) over four framework projects, one of which — call it the components framework — carries `Theme/`, `Views/`, `Models/`, `Localization/`, `Utilities/` and `Api/`. Both apps are VIP + SwiftUI, ~10–20 feature areas each. What it actually does, and why §3.2, §3.6 and §3.11 are shaped the way they are:

- *Observed in production:* a screen folder is **flat and layer-suffixed** — `Authentication/About/` holds `AboutView.swift`, `AboutViewModel.swift`, `AboutInteractor.swift`, `AboutPresenter.swift`, and nothing else. Both apps name their layers this way — the pro app's `Firmware/Update/` holds `FirmwareUpdateInteractor.swift` and `FirmwareUpdatePresenter.swift`, carrying only the layers that screen needs. This is the direct evidence for §3.2's flat-leaf rule and for the VIP+SwiftUI layer set (View, ViewModel, Interactor, Presenter) this template generates.
- *Observed in production:* a feature group holds **flow-level files beside its child screens** — `Authentication/` contains `AuthorizationCoordinator.swift` next to `About/`, `Login/`, `ForgotPassword/`, `Landing/`; the shared framework's `Views/` likewise holds an `AgreementsCoordinator.swift` beside the flows it drives. The group owns the flow; it is not just a naming folder (§3.2).
- *Observed in production:* the component library is a folder called **`Views/`, sitting beside `Theme/`**, holding ~20 loose single-file components (`LoadingView.swift`, `ErrorView.swift`, `CommonSwitch.swift`, `AsyncImageView.swift`) and ~15 component folders, each of which exists because the component has a companion — `CommonLabel/` is the view plus its `LabelViewModel`, likewise `Buttons/`, `Dropdown/`, `CommonTextField/` — plus one thematic family (`Molecules/Cards/`). No subfolder is named after a layer. That is §3.6's grouping rule, and the reason this template's shared folder is called `Views/`.
- *Diverged deliberately:* in that repo the component library lives **inside one app**, so the second app cannot reach it — the components framework's own `Views/` holds shared *screens and flows* (address selection, barcode scanner, device lists), not components. This template puts the component library in `DesignSystem/Views/` in the shared module from T2 onward precisely so the second app inherits it (§3.9). Shared *flows* remain a legitimate second thing a shared module can own; they just aren't the same folder's job.
- *Observed in production:* theming is genuinely **two layers, both real** — the framework carries the theme system (`Theme.swift`, `ThemeSpecifier`, `KeyThemable`, a branding entry point, a `Font/` folder) and each app carries its own `Theme/` with a per-brand `Theme.<App>.swift`, a `ThemeManager`, a `Themes` registry and `Font/`/`Size/` subfolders. Typography alone reaches four files there — the font family, a font-type enum, a size enum and a Dynamic Type helper. §3.11's base/override rule and its "start flat, split by family" refinement both come from this; the template still starts at two files, because day one is not year three.
- *Observed in production:* **per-component styling lives in the per-app theme layer, and both apps do it** — the consumer app's `Theme/Views/Buttons.swift`, the pro app's `Theme/Views/` with `Buttons.swift`, `Labels.swift` and `Views.swift` beside a `Theme.Pro.swift` that is almost the whole rest of that app's theme. That is the strongest available evidence for §3.11's rule that a component's look is theme material, not view material: it is exactly what differs between two apps sharing one component library.
- *Diverged deliberately:* the name. Calling it `Theme/Views/` leaves the repo with two folders called `Views` — one holding views, one holding styles — so this template calls it `Theme/ComponentStyles/` (§3.11).

### 8.2 Abstractions and protocol-based boundaries

The structural lesson that outlives every other one here: **a module's public surface is a set of protocols, and the concrete types satisfying them are injected by whoever composes the app.** This is what makes a shared framework serve two different apps without knowing either one exists.

- *Observed in production:* the shared framework vends **base view controllers and base flows that each app subclasses or configures**, rather than finished screens. The shared layer owns structure and behaviour; the app owns identity, copy and the handful of decisions that genuinely differ. This is the mechanism behind §3.9's "apps are thin".
- *Observed in production:* app-varying behaviour reaches shared code as injected values — configuration objects, protocol witnesses, closures — never as a branch on which app is running. **A shared module containing `if app == .x` has already failed**, because the next difference adds a second branch and the module now encodes both products.
- *Observed in production:* platform and vendor capabilities sit behind first-party protocols — networking, persistence, connectivity, analytics, logging, mail/share sheets, barcode scanning. The SDK or system API is an implementation detail behind a protocol the module owns.
- **Rules `/new-feature` and `/add-module` enforce:**
  - Every `Service`/`Repository`/`Interactor` is generated as a **protocol plus a concrete implementation**, with the consumer depending on the protocol. This is what makes §4.1's "real, passing unit test against a fake dependency" possible at all — the fake is a second conformance, not a mocking framework.
  - A protocol is owned by the module that *consumes* it, not the one that implements it. This keeps the dependency arrow pointing the right way (§3.9) and is what lets a leaf module be swapped without touching its callers.
  - Protocol names state a capability (`SystemRepository`, `AnalyticsReporting`), not a pattern (`HomeInteractorProtocol`) — a name that only exists to distinguish it from its own implementation usually means the abstraction has exactly one plausible implementation and shouldn't exist yet.
- *Recommended:* don't abstract on speculation. The threshold is a **second real conformance** — a test fake counts, a hypothetical future backend does not. Protocols with one implementation and no test double are ceremony; this is the discipline that keeps a protocol-oriented codebase from turning into indirection for its own sake.
- *Recommended:* keep protocols narrow enough that a fake is a few lines. A 20-method service protocol makes every test file expensive and is a strong signal the module is doing more than one thing.

### 8.3 Environments, secrets and configuration

- **Decided, and shipped in the four authored app-shell templates:** the base URL reaches the app as `Secrets.xcconfig`'s `API_BASE_URL` → the app target's `Info.plist` `APIBaseURL` → `AppEnvironment.current.apiBaseURL` in the shared Core module → `RequestBuilder`'s injected `baseURL` (§3.7). Nothing else reads it — the composition root has no reader of its own — and no `Service` holds a literal URL. `AppEnvironment`'s `url(_:xcconfig:)` reader `preconditionFailure`s on **three** distinct conditions, each with its own message because each sends the developer to a different file: the `Info.plist` key is absent (the per-target wiring never happened), the value resolves to an empty string (`API_BASE_URL` is blank *or* missing in `Secrets.xcconfig` — `$(API_BASE_URL)` expands to empty either way, so the message must not claim which), or the value parses but is not an absolute URL. A misconfigured base URL breaks every request in the app, so failing at launch beats a screen of empty states, and it's the one place the force-unwrap policy's "a crash is correct here" clause applies outside tests. **The third check tests `scheme` and `host`, not just a non-nil `URL(string:)`, and both halves are load-bearing:** `//` opens a comment in xcconfig, so an unescaped `https://host` arrives as the truncated `https:`, which parses with a `nil` host, and a scheme-less `host.example.com` parses as a *relative* URL. **The `$()` in the shipped `https:/$()/host` form is not an escape** — xcconfig has no escape character and no string literals, so quoting is useless and a `\/\/` leaves literal backslashes in the value. It works by sitting between xcconfig's two passes: at parse time the slashes aren't adjacent so the comment scanner finds nothing, and at expand time `$()` substitutes an empty build-setting name and disappears, yielding `https://host`. `${}` is equivalent. `docs/CODING_STANDARDS.md` carries the mechanism and the `xcodebuild -showBuildSettings`-verified table of every candidate form; the checker in the next bullet expands both escape spellings so it agrees with the build. A guard that only checked for a non-nil `URL` let both through and produced exactly the silent wrong-server bug the guard is there to prevent — so the read gets stricter over time, never more tolerant. `/add-app` must repeat the `configFiles:`/`Info.plist` half per app target, since configuration files are per target (§4.5).
- **The whole networking block in each app shell sits behind an `__IF_NETWORKING__` marker, resolved against Q7 (which now offers `None`).** An offline, local-only app renders no `RequestBuilder`, no `APIClient` property and no `apiBaseURL` accessor (the `__IF_NETWORKING__` block in `AppEnvironment.swift.template` drops out, and on a project with no keys at all `/start` skips the file entirely), so there is nothing to configure and nothing to crash about — and `/start` omits the `APIBaseURL` plist key and strips `API_BASE_URL` from the rendered `Secrets.xcconfig` rather than leaving a key nothing reads. **The rule is "don't render the reader", never "make the read tolerant":** a networked app that falls back to a default URL when its config is missing is precisely the failure the guard exists to catch, so softening the guard to accommodate offline apps would trade a correct crash for a silent wrong-server bug. `Networking/` itself still materializes at every tier — the types compile unused, so adding a backend later is a composition-root edit, not a module-graph change.
- **Never commit secrets — and this template ships the mechanism, it doesn't just recommend it (same principle as §8.6's logging module).** `Scripts/templates/config/Secrets.xcconfig.example` is a real file; `/start` §1.5a copies it to the repo root as both `Secrets.xcconfig.example` (committed) and `Secrets.xcconfig` (gitignored), points the app target's configurations at it, and surfaces `API_BASE_URL` through `Info.plist` for `AppEnvironment` to read and the composition root to pass into `RequestBuilder`'s `baseURL`. The `.gitignore` carrying that exclusion is copied in by §0 — a doc line telling a developer "`Secrets.xcconfig` is gitignored" against a repo with no such rule is worse than no line at all, because they'll believe it. Keys that must ship get injected at build time from the CI environment or that file; an API key in an Info.plist is extractable from the IPA — treat "in the binary" as "public", and keep anything genuinely sensitive server-side.
- **`Scripts/check_secrets.sh` is the commit-time half of that guard**, and it exists because a launch-time crash in the simulator is a worse place to learn this than a failed commit. It asserts that every key declared in `Secrets.xcconfig` has a non-empty value, that keys stay in parity with `Secrets.xcconfig.example` in both directions (a key the example carries *commented out* is permitted but not required — that's how the shipped `API_KEY` line stays valid), and that `API_BASE_URL`, when present, has a scheme and a host. It reproduces xcconfig's own comment-stripping, so it sees the truncated value the build would produce rather than what the developer thinks they typed. **Two states must pass, not fail:** no `Secrets.xcconfig` at all (it's gitignored — the normal state of a fresh clone, and of CI that injects config from the environment) and no `API_BASE_URL` key (an offline project, where `/start` stripped it). An unconditional check would fail both and get deleted.
- **Decided: `AppEnvironment` is the single reader for every key, `API_BASE_URL` included, and `/start` renders it on day one.** Two earlier positions were both wrong in the same direction — "no wrapper until a second key exists" and then "a wrapper, but the base URL keeps its own composition-root reader" — because both left the *first* key's parsing inline in four app-shell templates, so the day a project added its second key it had one reader in `App.swift` and one in Core, with two sets of failure messages for the same class of mistake. The template now ships one: `/start` §1.7c renders `AppEnvironment` into **Core** on any project that has a key (every networked project), with a generated `apiBaseURL` accessor, and the composition root reads `AppEnvironment.current.apiBaseURL` and holds no `Bundle.main` call. On a project with no keys at all (`networking: none`) the file is skipped and `/add-secret` renders it on the first key, the way `docs/PERMISSIONS.md` appears on the first `/add-permission`. It lives in Core, not the app, because a shared module can't read config the app hasn't injected otherwise, and it takes an injectable lookup defaulting to `Bundle.main` so a package test target can exercise it at all. Adding a key is then one line — a typed accessor over the generic `string`/`url`/`bool`/`int` readers — which is the property that keeps `Bundle.main.object(forInfoDictionaryKey:)` out of feature code where §3.7 and `docs/ai/ui_rules.md` both forbid it.
- **Never send a real credential through an AI agent — and `/add-secret` enforces that rather than advising it.** `/add-secret` is normally driven by an LLM, so any value typed into the prompt lands in that transcript, in the model's context, and in every log between the two, and stays there long after the key is rotated. `Scripts/add_secret.sh` therefore detects credential-shaped values (vendor prefixes, high-entropy blobs, `*_KEY`/`*_SECRET`/`*_TOKEN`/`*_PASSWORD` names carrying anything but a placeholder), writes the key **commented out in both files**, does the rest of the wiring, and tells the developer to paste the value into the gitignored `Secrets.xcconfig` by hand. The check is in the script, not only in the Skill's instructions, for the same reason the rest of §8's rules are in `.swiftlint.yml` and the pre-commit hook: an instruction an agent can reason its way past is not a control. This is orthogonal to the point above about "in the binary" means "public" — one is about what a client may ship, the other about what may pass through a model on the way there.
- *Observed in production:* **certificate pinning** with the CA material bundled as framework resources, and a separate development CA from the production one. If your app talks to infrastructure you control, this is the baseline; a pinned cert also means a **rotation plan** and an app update before expiry, which belongs in `TODO.md` the day pinning is added.
- *Observed in production:* a feature-flag layer inside the shared framework, so incomplete work ships disabled rather than living on a long-lived branch.

### 8.4 Dependencies at scale

- *Observed in production:* roughly a dozen runtime SPM dependencies, all pinned via a single `Package.resolved` **at the workspace level** — one resolution graph for every app and framework, which is the whole point of putting the resolve file there (§3.10 step 3).
- *Observed in production:* the linter itself is a pinned dependency, not a machine-local install (§7).
- *Recommended:* every dependency is added at the lowest module that needs it, never to an app "for now" — a dependency added to an app can't be used by the shared module later without moving it, and moving it changes the link graph of every app.
- *Recommended:* prefer wrapping a third-party SDK behind one of §8.2's protocols at the point it enters the codebase. It costs an hour and it's the difference between replacing a vendor in one file and in two hundred.
- *Recommended:* `docs/PROJECT_MAP.md` (or a `docs/DEPENDENCIES.md`) records *why* each dependency exists and what removing it would take. Third-party license attribution is a shipping requirement — production apps of this shape bundle an attributions document and surface it in-app.
- **When to move off manual DI (Q9's default).** Manual initializer injection stays the default at every tier — it's dependency-free and every construction site is visible by reading the code. The signal to introduce a container isn't module count on its own, it's when a composition root's constructor call has grown past what's readable at a glance (rule of thumb: more than ~6-8 positional dependencies threaded through, or the same dependency re-threaded through 3+ layers just to reach a leaf that needs it) — that's when a container's main win, resolving the graph automatically instead of by hand, starts paying for its indirection cost. When that happens, introduce a lightweight container (e.g. Factory) at the composition root only — it should never leak into `Features/`, where constructor injection stays the rule regardless of what wires it at the top. This is a project deciding to opt in later, not something `/start`/`/add-module` generate.

### 8.5 Localization at scale — the part that always gets underestimated

- *Observed in production:* 18 locales maintained **per module** — each app and the shared framework carries its own full locale set. This is the concrete evidence behind §3.11's per-module rule; it is a bundle-resolution fact, not a stylistic preference.
- *Observed in production:* a dedicated tooling layer around strings, because at 18 locales × 3 modules manual editing is not viable. That layer covers: importing a translation-service export **updating only existing keys, never adding new ones**; adding a key to every locale at once; removing a key from every locale; and checking for (a) unused keys, (b) keys out of order within a file, (c) keys in the base locale missing or extra in others. Translation imports are reviewed, never auto-merged.
- **This template's `Scripts/check_strings.sh` must implement at least the parity check** — base locale vs. every other locale, per module — and run in the pre-commit hook and CI. Missing-key drift is invisible until a user in one language sees a raw key on screen.
- *Recommended:* namespace keys by module and screen (`shared.error.retry`, `app.settings.title`) and keep files sorted, so the order check is meaningful and diffs stay readable.
- **String Catalogs are this template's format, not a recommendation.** Every resource-owning module owns exactly one `Localization/Localizable.xcstrings`, and `.strings` files are generated build output, never a source file anyone edits. This is the modern format — Apple's default for new projects since Xcode 15 — and it is what Xcode's own localization tooling and localization agent operate on (§5.1). Four concrete consequences, each verified against a real XcodeGen project and build rather than assumed:
  - **Ordering and duplicate keys stop being a class of problem.** A catalog is a JSON object keyed by string key, so keys cannot go out of order and the same key cannot appear twice in one locale. The "keys out of order within a file" check the production tooling needed simply has nothing to check, and `check_strings.sh` is correspondingly smaller: parity, translation state, and cross-module duplicates only.
  - **Translation state is first-class.** `translated` / `needs_review` / `new` live in the file itself, so "which strings are actually done" is a property of the source of truth rather than a comment convention. `/translate` writes `needs_review` and `check_strings.sh` counts them; an entry Xcode marks `new` is treated as missing, because a user sees the same fallback either way.
  - **Adding a locale adds no file and needs no project regeneration.** With per-locale `.lproj/Localizable.strings`, a new language meant a new folder and a new file on disk, which meant `xcodegen generate` before the app would build it — a genuinely surprising step (§3.12). A String Catalog already exists and already sits in the target's sources, so a new locale is an edit to a tracked file and the next build picks it up. XcodeGen also reads the catalog and populates the project's `knownRegions` from it, so the language list stays right without hand-editing anything.
  - **Pluralization and device variants have a defined home.** A `%d items` string that needs one/other forms is a variation inside the entry, editable in Xcode's catalog editor, instead of a parallel `.stringsdict` file that no parity script ever checked.
- **A `.strings` corpus is migrated, not carried alongside.** `Scripts/migrate_strings_to_catalog.sh` folds a module's `.lproj/Localizable.strings` set into one catalog, preserving keys, values and `/* … */` comments as `translated`, then regenerates `L10n.swift` and deletes the git-tracked originals. Running both formats at once is the one genuinely dangerous state — parity passes while half the strings are invisible to it — so `check_strings.sh` **fails** a module that has both. A module that still has only `.strings` gets a **warning** naming the migration script, not a failure: an adopted project (§2.1 Path 3) receives these hooks before anyone has asked it to change format, and blocking every commit on an unannounced migration would contradict adoption's own promise not to disrupt a working project.

### 8.6 Observability

- *Observed in production:* a first-party logging module with explicit levels rather than scattered `print`, plus an analytics layer inside the shared framework. A logging module as the *leaf* of the dependency graph — depending on nothing — is exactly the right shape (§3.9), and it's only reusable because it's a protocol with a default implementation rather than a global function.
- **This template ships that file, it doesn't just recommend it.** `/start` renders `Core/Logging/Log.swift` (a `Logging` protocol, level helpers, an `OSLog`-backed `OSLogLogger`) at every tier, because `docs/CODING_STANDARDS.md`'s no-`print()` rule and `.swiftlint.yml`'s `no_print_statements` both name it — a standard whose referent doesn't exist is a dead rule on day one. It lives in `Core` rather than its own project even at T3: one file doesn't earn a spec, a workspace entry and a scheme. `/add-module Logging` moves it out when a team wants independent versioning, and the config schema reserves the `logging` role for exactly that.
- *Recommended:* crash reporting and analytics sit behind a protocol owned by the shared module, with the concrete SDK injected per app (§8.2). Two apps frequently report to different destinations, and the vendor changes more often than the call sites.
- *Recommended:* logging is level-gated and never logs tokens, credentials, or personal data — a rule worth a `custom_rules` regex, not just a doc line.

### 8.7 Testing and CI

- *Observed in production:* framework projects carry their own test targets and shared schemes; app-level coverage is thinner than framework coverage. That's the normal, correct asymmetry — logic pushed behind module boundaries and protocols is what makes it testable at all, which is the strongest argument for T2/T3 beyond tidiness.
- *Recommended:* CI runs, per push: lint (`--strict`), `check_strings.sh`, and `xcodebuild test` **per scheme**. At T3 that's a matrix — one entry per app plus one per framework — growing every time `/add-app` or `/add-module` runs. Budget for it; a workspace multiplies CI time, not just target count.
- No pipeline is authored by this template (§10), but `/add-app`/`/add-module` should append a `TODO.md` entry reminding the developer to add the new scheme to CI.

### 8.8 Repo hygiene

- **Decided: generated `.xcodeproj`/`.xcworkspace` files are committed, not gitignored** (§10 — no longer left to the team). `/start` and every subsequent `/add-module`/`/add-app` regenerate them in place; committing keeps the repo openable without requiring XcodeGen/Tuist installed just to get to a build, at the cost of a pbxproj diff on every regenerate. Write this in the rendered `README.md` so a contributor isn't left guessing which policy this repo picked.
- Always gitignored regardless of that decision: `xcuserdata/`, `.DS_Store`, build products, `Secrets.xcconfig`, compiled tool binaries — none of that is reproducible-by-regeneration, it's either machine-local state or a secret. **This list is a committed `.gitignore` in the template, copied into the target by `/start` §0** — and because §0's merge skips a file the destination already has, an adopted repo's own `.gitignore` gets these entries *appended* in §1.5a instead, before any `Secrets.xcconfig` is created. Order matters: creating the secrets file first in a repo that doesn't ignore it is how a secret gets committed.
- *Observed in production:* an orphaned framework project sitting in the repo, referenced by no workspace and holding no sources — a module someone started and nobody removed. This is the characteristic T3 failure mode: modules are cheap to add and nobody deletes them. `/status` should flag any project directory not listed in the workspace and any module with no consumers (§4.6).
- *Observed in production:* commits carry the tracker ticket ID and land via PR. Encoded in `docs/GIT_CONVENTIONS.md` and its format mechanically checked by `.githooks/commit-msg` (§7, §10) — though the ticket-ID prefix itself stays convention-only, since the hook can't know whether a given team's tracker issues one.

### 8.9 App Store requirements that are easy to forget

- **Privacy manifest** (`PrivacyInfo.xcprivacy`) per app, declaring collected data types and required-reason API usage; third-party SDKs need theirs too, and App Store Connect rejects on this at upload time, not at build time.
- Per-app: App Store Connect record, push certificates/keys, App Groups if extensions share storage, and export-compliance answers.
- Accessibility as a merge gate, not a phase: Dynamic Type support, real or explicitly-`nil` accessibility labels (already in `ui_rules.md`, §5), and VoiceOver-passable navigation on every new screen `/new-feature` generates.
- Dark mode: guaranteed by construction if every color goes through §6's light/dark token pairs — which is the second reason the Asset Catalog deviation earns its keep.

---

### 8.10 Swift-level rules that outlive any architecture choice

These four are the questions a developer actually asks on day one, and none of them follow from Q1-Q12. All are **decided** and belong in `docs/CODING_STANDARDS.md` (which `CLAUDE.md.template`'s lookup table already auto-loads — no new `docs/ai/*_rules.md` file, which would be an orphan the agent never reads).

- **Where data goes, decided by kind, not by convenience.** `UserDefaults` for small non-sensitive app state and preferences; the Q4 store (SwiftData/Core Data) for domain records the app queries or works with offline; **Keychain for tokens, credentials, anything whose leak is a breach** — the only encrypted, hardware-backed option and the only one kept out of unencrypted backups. The hard line: never a credential in `UserDefaults` or in the local database. Note honestly that this template ships **no Keychain wrapper** (§10's auth/session gap) — the *selection rule* is the deliverable, and phrasing must not imply a shipped helper, or it becomes exactly the dead reference §8.6 forbids. `UserDefaults` itself is a dependency behind a narrow consumer-owned protocol (§8.2), not a global; `@AppStorage` directly in a View is fine for view-local UI state only.
- **Concurrency is structured, and the templates already prove it.** Every generated `Service`/`Repository`/`Worker`/`LocalStore` is `async throws`, `Debouncer` is an `actor`, UI-owning types are `@MainActor`, and **no template contains a single `DispatchQueue`**. So the rule is written against shipped code, not as generic Swift advice: GCD only where an API forces it, wrapped once in a continuation at the boundary; `actor` for shared mutable state rather than a serial queue or a lock; `@MainActor` annotation rather than `DispatchQueue.main.async`; never a semaphore-blocked wait on async work, which deadlocks the cooperative pool.
- **ARC rules keyed to ownership direction, anchored in generated code.** An escaping closure stored on a long-lived object needs `[weak self]` (the generated `ViewController`'s retry `UIAction` is the shipped example); a non-escaping one doesn't, and adding it there is noise. A back-reference *up* the ownership graph is always `weak` — VIP's `Presenter.displayLogic` is the case the combo READMEs already call out, including that it must be wired after both objects exist. Prefer `weak` over `unowned` (`unowned` is a crash where `weak` is a no-op). Coordinators own children strongly, children point back `weak`.
- **`struct` by default; `class` for a stated reason.** The reasons are identity (`AppCoordinator`, a ViewModel), a framework requirement (`UIViewController`, SwiftData `@Model`, `NSObject`, or needing to be the target of a `weak` reference — which is *why* VIP's SwiftUI variant needs its reference-type ViewModel bridge at all, §1.4), and `@Observable` view state. Everything in `Models/`, plus `RequestBuilder` and `URLSessionAPIClient`, is a struct precisely because none of those apply. Corollaries that get missed and so must be written down: mark classes `final` unless something subclasses them today; a `struct` holding a mutable reference-type property is not a value type; a `struct` whose whole surface is `mutating` usually wants to be an `actor` or a `class`.

## 9. Deliverables Checklists

### 9.1 Phase A — what this execution must produce

- [ ] `ios-ai-skeleton/` repo per §1.1 — no `App/`, `Features/`, `project.yml`, `.xcworkspace`, or `ios-skeleton.config.json`
- [ ] `.claude/skills/start/SKILL.md` implementing all of §2, including the topology branch and the Path 3 adoption flow
- [ ] `.claude/skills/{new-feature,add-assets,update-app-icon,add-permission,update-theme,status,add-module,add-app,translate,add-secret}/`, each gated by §1.3 and each implementing §4's destination-resolution rule
- [ ] Every `SKILL.md` — `/start` and all ten — declares §4's tier in frontmatter: `model: opus` + `effort: high` on the four cross-cutting Skills, `model: inherit` on the other seven (alias form, never a pinned model ID)
- [ ] `Scripts/templates/{mvvm-swiftui-navigationstack,vip-swiftui-navigationstack,vip-uikit-coordinator,mvc-uikit-coordinator}/` fully authored (§1.4); other combinations left template-assisted
- [ ] `Scripts/templates/persistence/{swiftdata,coredata}/` (§3.8) and `Scripts/templates/logging/` (§8.6)
- [ ] `Scripts/check_secrets.sh` (§8.3) — empty-value, parity and URL-shape checks, passing on both a missing file and an offline project
- [ ] `Scripts/templates/config/Secrets.xcconfig.example` (§8.3) and a `.gitignore` covering §8.8's always-ignored list, both copied into the target project by `/start` §0/§1.5a
- [ ] `Scripts/add_secret.sh` and `Scripts/templates/config/AppEnvironment.swift.template` — rendered by `/start` §1.7c on any project with a key (§8.3), and by `/add-secret` (§4.10) on the first key of a project that had none
- [ ] `Scripts/generate_workspace.sh` (§3.9) and `Scripts/new_module.sh` (§4.7)
- [ ] `.swiftlint.yml`, `Scripts/lint.sh`, `Scripts/check_hardcoded_colors.sh`, `Scripts/check_strings.sh` (§8.5), `Scripts/check_secrets.sh` (§8.3), `Scripts/generate_strings.sh` taking a module argument, `.githooks/pre-commit`, `.githooks/commit-msg` (§7)
- [ ] `docs/*.md` and `docs/ai/*.md`/`.template` files per §1.1 and §5, including `modularization.md.template`
- [ ] `docs/product/README.md` — the domain slot, explaining what lands there and that nothing generates it (§5.2)
- [ ] `CLAUDE.md.template`, `README.md` describing the template itself (§1.2)

### 9.2 Phase B — what a successful `/start` run must produce (build this expectation into the Skill itself)

- [ ] `ios-skeleton.config.json` recording every Q1–Q12 answer, plus the resolved module and app lists
- [ ] Spec file(s) per tier and a real `.xcodeproj` per project from `xcodegen generate`/`tuist generate` — plus, at T3, a `.xcworkspace` listing every project and a shared scheme per project
- [ ] Folder tree per §3.1 and the tier's shape per §3.9; layer shape per §3.2/§3.3 for the chosen architecture
- [ ] One working `Features/Home/` **per app** proving the stack compiles, with a real passing test — plus, at T3 multi-app, one shared base view both apps consume
- [ ] `Theme/` with at least one real color + font token, no Asset Catalog colors — base tokens in the shared module and a per-app override layer from T2 onward (§3.11)
- [ ] `DesignSystem/Views/` — `LoadingView`, `ErrorView` (with retry), `EmptyStateView`
- [ ] `Networking/RequestBuilder.swift` + `APIClient.swift`
- [ ] `Core/Logging/Log.swift` — at every tier, unconditionally (§8.6)
- [ ] `Core/Configuration/AppEnvironment.swift` on any project with a key, carrying the `apiBaseURL` accessor on a networked one — and no `Bundle.main.object(forInfoDictionaryKey:)` call left in any app shell (§8.3)
- [ ] If Q4 isn't `None`: `Core/Persistence/PersistenceController.swift`, and the starter feature's `<Name>LocalStore` wired into its data layer and into the composition-root factory. If Q4 is `None`: none of those files exist, and the starter feature is remote-only (§3.8)
- [ ] `docs/product/` created with the template's `README.md`, nothing rendered into it, and named in the closing report as where requirements go (§5.2)
- [ ] `Models/` created, with the starter feature's Request/Response/Entity structs in `Models/HomeModels.swift` — none of them left inside `Features/Home/`
- [ ] Per-module `Localizable.xcstrings` (String Catalog, one file, every locale) + generated **bundle-aware** `L10n.swift`, each `Features/Home/` referencing `L10n.*` and not a raw string literal
- [ ] No generated file references this document, a `.template` filename, or a `§` section number in a comment — and every generated type, protocol, property and function carries a `///` doc comment (§7)
- [ ] `DesignSystem/Views/` populated for the project's UI framework — SwiftUI views for the SwiftUI combos, `UIView` subclasses for the UIKit ones (§3.6)
- [ ] `Package.resolved` at the tier-correct location (§3.10 step 3)
- [ ] Git initialized (or detached from the template's history, if offered and accepted) with `.githooks/pre-commit` and `.githooks/commit-msg` wired
- [ ] `CLAUDE.md`, `docs/ai/architecture.md`, `docs/ai/modularization.md` rendered with real, locked-in decisions, and `README.md`/`docs/ONBOARDING.md` written fresh for this project — no leftover `{{placeholder}}` and no leftover `__IF_PERSISTENCE__`/`__ELSE_PERSISTENCE__`/`__END_PERSISTENCE__` marker in any rendered app-shell file
- [ ] `docs/PROJECT_MAP.md` seeded with §5's three sections (uncovered files/folders, the module list with kinds and consumers, template-backed vs. agent-assisted combos) — `CLAUDE.md` links to it, so a missing file is a dead link on day one
- [ ] `TODO.md` carrying the manual follow-ups, including the per-app items from §8.9

---

## 10. Known Limitations / Open Questions

Carry an honest, up-to-date version of this section into the rendered `README.md`/`ONBOARDING.md`. As of writing this prompt:

- ~~Objective-C scope is undefined.~~ **Resolved:** dropped entirely. Q2 is now a fixed Swift-only default with no interactive choice (§2.2) — this template scaffolds nothing for Objective-C. A project with legacy Objective-C to bridge in still can (a bridging header is a manual, one-time Xcode step), but no Skill or template file accounts for it.
- ~~Only one architecture combination is fully template-backed at launch.~~ **Resolved, partially:** four now are (§1.4) — MVVM+SwiftUI+`NavigationStack`, VIP+SwiftUI+`NavigationStack`, VIP+UIKit+Coordinator, and MVC+UIKit+Coordinator — and only at T1/T2 shape. Everything else (MVC+SwiftUI, MV either UI framework, VIPER, any architecture on the non-default navigation approach for its UI framework) stays template-assisted rather than fully deterministic — an honest scoping choice, not an oversight; expand further as real usage shows which combos are common. At T3, `/add-module`/`/add-app` generate specs, wiring and the workspace deterministically, but a module's *contents* are agent-written.
- **Idempotent conflict-handling in `/start` (§2.4) is agent judgment, not a mechanical diff.** Unlike a byte-for-byte "embedded copy in sync" check, deciding whether a new answer conflicts with existing generated code relies on the agent inspecting `Features/` and reasoning about it — there's no automated guarantee it catches every case.
- ~~`docs/PROJECT_MAP.md` is referenced but never created.~~ **Resolved:** §5's table always said `/start` seeds it and `CLAUDE.md.template` links to it, but neither §2.1 step 11 nor `start/SKILL.md` §1.9 created one — it first appeared whenever `/add-module` or `/translate` happened to append to it, leaving a dead link in `CLAUDE.md` until then. Both the step and the Skill now seed it explicitly, and §9.2's checklist verifies it. There is deliberately no `.template` for it: its day-one content is derived from the answers, not from placeholder substitution.
- **Proactive confirmation is implemented in `/new-feature` (§4.1) and `/add-secret` (§4.10).** They batch-ask before generating — module/grouping/field types, and key/value/type/target-app respectively; `/add-assets`, `/add-module`, `/add-app`, `/update-theme`, `/translate` and `/add-permission` still rely on their script refusing an ambiguous destination, which raises the same question later and with less context. The inconsistency is documented rather than fixed — extending the pattern to the remaining six is a deliberate follow-up.
- ~~**Two readers for configuration, not one.** `/add-secret` renders `AppEnvironment` in Core with typed accessors, but `API_BASE_URL` keeps its original path through the app shell's own `apiBaseURL` reader into `RequestBuilder`.~~ **Resolved:** `/start` §1.7c now renders `AppEnvironment` on any project that has a key, with a generated `apiBaseURL` accessor, and all four app-shell templates read `AppEnvironment.current.apiBaseURL` instead of carrying their own `Bundle.main` parsing. One reader, one set of failure messages (§8.3). What remains is unenforced rather than split: nothing mechanically catches a new `Bundle.main.object(forInfoDictionaryKey:)` call added inside a feature — it's a review gate, like the shared-view rule.
- ~~Q4's persistence answer had no downstream effect on any generated file.~~ **Resolved:** the questionnaire recorded SwiftData/Core Data/None and validated it against the deployment target, but every generated feature was remote-only, `§3.8`'s own diagram showed a `Local` branch nothing produced, and §9.2's checklist never asked for one. Persistence is now the optional half of the data layer (§3.8): `None` generates exactly what it always did, and a real stack additionally generates a per-feature `<Name>LocalStore` behind a consumer-owned protocol, a `<Name>Record` in `Models/`, and one injected `PersistenceController`.
- **Core Data's per-feature store is a wired seam, not a finished implementation.** SwiftData is fully generated end to end — record type, store, schema registration, factory wiring. Core Data gets the same wiring and a compiling `LocalStore`, but its two methods are `TODO(agent)` stubs, because a Core Data entity lives in a `.xcdatamodeld` bundle that can't be text-templated deterministically the way a `@Model` class can. Until the developer adds the data model and the entity, a Core Data project behaves exactly like a `persistence: None` one: local reads return nothing and the remote error propagates. `/start` writes both follow-ups to `TODO.md`, `/status` flags stores still holding the stubs, and `docs/PROJECT_MAP.md` records this in its template-backed-vs-agent-assisted section.
- **The generated read-through policy is a starting point, not a caching strategy.** Cache-on-success, read-on-failure, replace-the-whole-list. It is correct for a whole-list fetch and wrong for paging, delta sync, or local-first editing — all of which need that one method rewritten per feature. It ships with its own three generated tests (remote cached, cache used on failure, empty cache rethrows), so a rewrite starts from red rather than from nothing — but nothing detects a feature that has outgrown the policy in the first place.
- ~~`docs/CODING_STANDARDS.md` and `.swiftlint.yml` pointed at a Logging module nothing created.~~ **Resolved:** the no-`print()` rule and `no_print_statements` cited "the Logging module (§8.6)", §3.9's T3 tree drew a `Logging/` project, and no script or Skill ever produced either — a dead reference in every generated project on day one. `/start` now renders `Core/Logging/Log.swift` at every tier (§8.6); extracting it into its own module stays a deliberate `/add-module Logging`.
- ~~`README.md`/`docs/ONBOARDING.md` were described as rendered "from their `.template` counterparts", which don't exist.~~ **Resolved as a documentation bug:** `start/SKILL.md` always wrote both fresh for the real project — only §2.1 step 11 and §5's table claimed otherwise. Both now say what actually happens; no `.template` was added, because neither file's day-one content is placeholder substitution.
- **The domain lands in `docs/product/`, and nothing in this template validates it (§5.2).** The slot, its living-document rules, and `/new-feature`'s read-before-inventing step are specified; what is *not* specified is any check that a requirement was followed, any requirement-to-code traceability beyond a commit message, or any detection of a PRD that contradicts the code. Those are review concerns by design — a generated traceability matrix is work nobody keeps accurate.
- **An offline project's data-layer body is agent-written, not templated.** `networking: none` (Q7) makes every other part of a feature deterministic — the gap is one file's read method per feature and its test. Authoring full local-only branches in all four combos' Repository/Worker/Service and test templates was considered and deliberately deferred: it multiplies the marker matrix across ~13 template files for a shape whose correct body is three lines, and the template-assisted mechanism already exists for exactly this. Revisit if offline projects become common enough that the repeated hand-write is the friction rather than the templates.
- **Auth/session handling, deep linking, and test tiers beyond unit tests are unaddressed** — not by decision, just out of scope so far. `Networking/` has no token-refresh, Keychain or 401-retry story; §3.4's navigation covers in-app pushes but nothing maps an incoming URL onto a `Route`; and nothing generates a UI-test target or a snapshot-test convention. A project needing any of them builds it by hand today.
- **`new_feature.sh` cannot place a feature in a module that isn't an app.** §4.1 contemplates a shared framework as the destination (hence its `public`/`public init` guidance), and §4's topology branch resolves "the target module" generally — but the script's path lookup reads the config's `apps` list only and falls back to the app path when the name isn't found there, so `--module <framework>` silently writes the feature, its tests and its strings into the app instead. Either the script should resolve against `modules` too, or §4.1 should restrict the destination to app targets; today the spec and the script disagree.
- ~~Two localization toolchains can silently split the source of truth (§5.1).~~ **Resolved:** the template now uses String Catalogs itself (§8.5), so Xcode's localization tooling and this template's scripts read and write the same per-module `Localizable.xcstrings`. The split-source-of-truth failure is additionally guarded rather than only avoided: `check_strings.sh` fails a module that carries both a catalog and `.strings` files, and `Scripts/migrate_strings_to_catalog.sh` folds an existing corpus into the catalog. What remains unenforced is the *review* state across the two editors — Xcode's XLIFF round-trip marks machine translations with `state-qualifier: leveraged-mt` while `/translate` writes the catalog's `needs_review`, and neither clears the other (§5.1).
- **Agent permissions granted inside Xcode are global to the Mac and invisible to this repo (§5.1).** The Allowed Commands / Allowed Tools lists in Intelligence settings apply to every project and every agent launched in Xcode. Nothing here can scope, version or audit them, so a repo-level review of "what can an agent run?" is incomplete by construction.
- **Detaching a cloned template's git history (§2.1 step 7) is offered, not automatic** — a team could still end up with the template repo's history if they decline or if `/start` is run non-interactively.
- ~~No localization *Skill* defined.~~ **Resolved:** `/translate` (§4.9) drafts target-locale entries into the module's String Catalog from its source language, written with the catalog's own `needs_review` state, on top of the localization *utility* that already existed (§3.7).
- **`Models/` holding every type — including per-feature Request/Response/Entity structs that aren't actually reused elsewhere — is a deliberate simplicity trade-off (§3.2), not a claim that everything in there is genuinely shared.** It buys "one place to look for any data shape" at the cost of a growing, multi-author file directory and real naming-collision risk (two features both wanting a type called `Item`, say). The mitigation is filename discipline (`Models/<Feature>Models.swift`) plus `/new-feature`'s collision check (§4.1) — there's no compiler-level namespacing beyond that.
- **No hardcoded-*string* enforcement script**, unlike colors (`check_hardcoded_colors.sh`). A raw string literal in `Text(...)`/`UILabel.text` isn't mechanically caught the way a raw `UIColor(red:...)` is — flagged as a documented convention in `ui_rules.md` only, since a blanket check would false-positive heavily on legitimate non-UI string literals (log messages, format strings, identifiers).
- **No CI pipeline included — confirmed as deliberate scope, not an open question.** GitHub Actions/Xcode Cloud wiring stays out of both phases: CI is infra-specific (runners, signing, host choice) in a way that would force a guess this template has no basis for. Add on request. Note that at T3 this is a per-scheme matrix that grows with every `/add-app` and `/add-module` (§8.7) — the cost is real and the template only reminds you about it.
- **Topology migrations are documented and partly scripted, not automated.** §3.10 lists real steps and `/add-module`/`/add-app` do the additive half, but the access-control pass, the file moves, and the `import` rewrites are manual and reviewed. Nothing verifies an extraction is *complete* — the original app keeps compiling long after it isn't (§3.10). Building the second consumer is the only real check.
- **Per-module localization is a correctness requirement, not a preference — and it has no compile-time guard.** A framework using `Bundle.main`, or a key present in one locale and missing in another, fails at runtime in one language only. `check_strings.sh` catches key parity; nothing catches a wrong-bundle lookup (§3.11, §8.5).
- **Shared views are mandatory by convention, with nothing detecting a forked copy (§3.6).** `/new-feature` consumes `DesignSystem/Views/` and `/start` generates the three state views for the project's UI framework, but nothing catches a developer — or an agent — reimplementing a spinner inside a feature folder, the way `check_hardcoded_colors.sh` catches a raw color. A mechanical check would have to recognize "this view is the same as that one," which is not a regex; it stays a review gate.
- **Storyboards and XIBs are out of scope by decision, not by omission (§3.3).** No Skill generates one, no template emits one, and generated UIKit screens lay out in code with a programmatic `SceneDelegate` and a `UILaunchScreen` dictionary. A project that wants Interface Builder adds those files itself and maintains them by hand; the reasoning — unstable file text, opaque identifiers, runtime-only wiring, verbose constraint XML — is recorded in §3.3 so the question doesn't get re-litigated from scratch each time it comes up.
- **The base/app theme split is convention-enforced only.** `/update-theme` routes tokens to the right layer, but nothing stops hand-written code in an app from defining a color the shared module already owns; `check_hardcoded_colors.sh` catches raw literals, not duplicated tokens.
- ~~Whether generated `.xcodeproj`s are committed is left to the team.~~ **Resolved:** committed by default (§8.8) — every project built from this template now gets the same merge-experience trade-off rather than picking its own.
- **§8's production baseline is calibrated against one long-lived multi-app codebase,** UIKit-heavy and hybrid. Items labeled *observed in production* are evidence from that single codebase's structure, not an industry survey; items labeled *recommended* are this template's opinion. A different domain (games, offline-first, extension-heavy apps) will have a different baseline. Nothing from that codebase's naming or domain is embedded in the template — only the structural conclusions.
- **The protocol-boundary discipline in §8.2 is convention, not tooling.** `/new-feature` generates protocol + implementation pairs, but nothing detects a shared module that has quietly grown an app-specific branch, a protocol that never got a second conformance, or a service protocol that has drifted to 20 methods. These are review concerns, and they're where a protocol-oriented codebase degrades first.
- **Dependency injection defaults to manual initializer injection — confirmed, with the upgrade path now documented (§8.4).** A container stays an explicit, project-level upgrade a team opts into, never a default this template generates. At T3 each app owns a composition root that constructs the shared modules' dependencies — workable and explicit, and it grows linearly with module count; §8.4 gives the concrete signal for when that growth justifies introducing a container, and where it may (and may not) reach into the codebase once adopted.
- ~~No image-loading/caching library decided by default.~~ **Resolved: `AsyncImage` is the default** (§6), matching this template's no-third-party-package-by-default posture elsewhere (Q7's networking default). Upgrade to a caching library (Nuke, Kingfisher) once a project's image volume or caching needs justify the dependency — that's a project decision to make explicitly, not something `/start` defaults into. Icons follow the same restraint in the other direction: SF Symbols over imported assets wherever a symbol exists (§6).
- **Pagination isn't baked into the base `Repository` contract — confirmed as deliberate, not an oversight.** Guessing a cursor/page-index shape before any generated feature needs one risks guessing wrong and then migrating every feature off it (§8.2's "don't abstract on speculation"). Add the convention once a feature actually needs infinite scroll, and document it in that project's `docs/ai/architecture.md` at that point.
- ~~`docs/GIT_CONVENTIONS.md` is documentation only, not tool-enforced.~~ **Resolved:** `.githooks/commit-msg` (§7) now checks the message format mechanically. What stays convention-only: whether a commit is genuinely feature-based/one-coherent-change (§7's other bullets) — that's a review concern, not something a hook can check.
- **Spacing scale is optional** — colors/typography are mandatory Swift-token citizens (§6); spacing can be added the same way once a team wants one.
- **`sips`-based image/icon resizing assumes macOS tooling is present** on whatever machine runs the Skills.
