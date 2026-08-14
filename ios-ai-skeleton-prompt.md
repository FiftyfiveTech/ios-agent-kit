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
│   └── translate/                    # §4.9 — drafts target-locale .strings entries for human review
├── Scripts/
│   ├── new_feature.sh                # deterministic for the default stack, template-assisted otherwise — §1.4
│   ├── new_module.sh                 # §4.7 — creates a module's spec + folders, deterministic at every tier
│   ├── generate_workspace.sh         # §3.9 — emits <Name>.xcworkspace/contents.xcworkspacedata from config
│   ├── templates/                    # per-architecture file templates new_feature.sh selects from
│   │   ├── mvvm-swiftui-navigationstack/   # fully-authored, deterministic — see §1.4
│   │   ├── vip-swiftui-navigationstack/    # fully-authored, deterministic — ViewModel bridge (§1.4)
│   │   ├── vip-uikit-coordinator/          # fully-authored, deterministic — classic Clean Swift (§1.4)
│   │   └── mvc-uikit-coordinator/          # fully-authored, deterministic — ViewController only (§1.4)
│   ├── check_hardcoded_colors.sh     # §7 — theming enforcement
│   ├── check_strings.sh              # §8.5 — missing/extra/duplicate keys across locales and modules
│   ├── generate_strings.sh           # §3.7 — regenerates each module's L10n.swift from its Localizable.strings
│   └── lint.sh                       # §7 — swiftlint wrapper
├── .swiftlint.yml
├── .githooks/
│   ├── pre-commit
│   └── commit-msg                    # §7 — enforces docs/GIT_CONVENTIONS.md's message format
├── docs/
│   ├── ONBOARDING.md                 # how to use *this template* — §1.2
│   ├── CODING_STANDARDS.md
│   ├── GIT_CONVENTIONS.md
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

The `/start [path]` invocation from §0 and its three detected scenarios (fresh/empty, adoption, already-initialized), spelled out for a human reading this repo for the first time, plus: what `/start` does, that it's idempotent (§2.4), the three topology tiers and the honest cost of moving between them (§3.9–§3.10), and a pointer to `docs/ai/architecture.md.template` explaining that the real architecture doc doesn't exist until `/start` renders it. State the adoption scenario's scope plainly rather than letting it read as workspace-only: a single mature `.xcodeproj` with its own hand-written `CLAUDE.md`/`README.md` and years of history is exactly what it's for, not just a multi-project workspace.

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
9. Materialize the folder tree from §3 for the chosen architecture **and tier**: `App/`, `Core/` (Utilities + Localization), `Networking/`, `Models/`, `DesignSystem/` (Theme + SharedViews), `Features/` — as folders in one target at T1, as local packages at T2, as separate framework projects at T3 (§3.9). Seed **each localization-owning module's** `Localizable.strings` with its first few real strings and run `Scripts/generate_strings.sh` once per module to produce its bundle-aware `L10n.swift` (§3.11) — never leave the localization layer unwired even before the first feature exists.
10. Scaffold one starter feature (e.g. "Home") **in each app** using the same logic §4.1 describes for `/new-feature` — proving the whole stack actually compiles and its one generated test actually passes, not aspirationally. At T3 with more than one app, also generate one shared base view in the shared UI module that both apps' Home screens consume, so the sharing seam is exercised on day one rather than discovered later (§3.9).
11. Render `CLAUDE.md`, `docs/ai/architecture.md`, `docs/ai/modularization.md`, `README.md`, `docs/ONBOARDING.md` from their `.template` counterparts, **and seed `docs/PROJECT_MAP.md`** with the three sections §5 names (there is no `.template` for it — it's written fresh, and `CLAUDE.md` links to it, so it can't be left for `/add-module` to create on first append), replacing every placeholder with the real, locked-in decisions — a project that chose VIPER should never see MVVM's diagram in its own `docs/ai/architecture.md`, and a T1 project should never see a workspace diagram in its `modularization.md`. On Path 3 (step 13), never run this unmodified against a `CLAUDE.md`/`README.md`/`docs/ONBOARDING.md` that already existed before this run — see step 13's carve-out.
12. Report exactly what's left to do by hand (point the real API base URL, open the project once in Xcode, per-app signing) as `TODO.md` entries — not just a message that scrolls off-screen. Include the optional Xcode MCP bridge step from §5.1 as an *offer*, never as something this run performed.
13. **Path 3 (§0) variant — adopting an existing repo:** skip steps 5–6 for anything already present.
    - **Infer the tier from what's actually there — don't assume workspace means Path 3 and a bare project doesn't.** One `.xcodeproj` with no local packages → T1. One `.xcodeproj` plus local Swift packages → T2. `.xcworkspace` + N projects → T3. State the inferred tier and confirm it with the developer before writing `ios-skeleton.config.json`, exactly the same way whether one project exists or several.
    - **Record the deployment target actually set on the existing project's build settings** as `minIOSVersion`, instead of asking Q8's greenfield picklist (iOS 16/17/18) — an adopted project may already sit below that floor, and every §2.3 validation rule (SwiftData/`@Observable`/`NavigationStack` gating) must check against the real number, not the picklist default.
    - **Detect the existing feature-folder convention** (e.g. `Features/`, `Scenes/`, `Modules/`) and record its name in the config instead of assuming the literal `Features/`. `new_feature.sh` and `/new-feature` must read this field rather than hardcode the name — otherwise adoption produces a second, inconsistent folder alongside the one already in use (§3.2).
    - **Surface an untemplated combo immediately, during this confirmation, not later.** If the detected architecture/UI-framework/navigation combination isn't one of §1.4's four fully-templated ones (e.g. any Hybrid UI-framework project), say so plainly here — don't let the developer discover it only when `/new-feature` first falls back mid-run.
    - **Never silently overwrite hand-authored project docs.** Before step 11 renders `CLAUDE.md`/`README.md`/`docs/ONBOARDING.md`, check whether each already exists with real content (no leftover `{{placeholder}}` tokens; predates this run's `ios-skeleton.config.json`). If so, do not overwrite it — render the new version to a side file (or simply skip it and note the gap in `TODO.md`) and ask the developer how to reconcile it manually. `docs/ai/architecture.md`/`modularization.md` are still safe to render fresh, since an adopted repo never had them before.
    - **Never wire hooks blind.** Before step 8, run `Scripts/lint.sh`, `check_hardcoded_colors.sh`, and `check_strings.sh` once against the adopted codebase as a dry run. If any fail, report the failures and ask whether to fix them first or wire the hooks in report-only mode instead — an adopted codebase has never been checked against this template's conventions, and a hard-blocking hook can lock the developer out of their very next commit.
    - Detect the existing `.xcworkspace`/`.xcodeproj` set, record it as the topology, and write a `TODO.md` entry naming each project not yet described by a spec file. Never regenerate or overwrite a hand-maintained `.xcodeproj` — converting one to a generated spec is an explicit, separate migration the developer opts into (§3.10).

### 2.2 Setup Questionnaire

Q1 is asked and answered **first**, and its answer gates most of what follows: which spec files exist, whether a workspace file exists at all, where `Package.resolved` and `.swiftlint.yml` live, where localized strings live, and which module `/new-feature` writes into. Everything below is numbered in ask-order.

| # | Question | Options | Recommended default | Why it matters |
|---|---|---|---|---|
| 1 | **Project topology & modularization** | **T1** single `.xcodeproj`, one app target / **T2** single `.xcodeproj` + local Swift packages (`Core`, `DesignSystem`, `Networking`, `Models`, `Features/*`) / **T3** `.xcworkspace` + N projects (1..N apps + shared framework projects) | T2 for one app; T3 the moment a second app, app-extension, or separately-versioned SDK is on the roadmap | Gates the whole tree (§3.9), the location of lint/strings/`Package.resolved`, and every Skill's "which module?" branch. Also asks: **how many apps now?** — see Q12 |
| 2 | Language | Swift only *(no Objective-C option — decided against; see §10)* | Swift-only | Every generated file is Swift. A project with legacy Objective-C to bridge in still can — add a bridging header manually — but this template generates nothing for it. |
| 3 | UI framework | SwiftUI / UIKit / Hybrid (UIKit shell hosting SwiftUI screens) | SwiftUI | Changes the shape of the presentation layer |
| 4 | Persistence | SwiftData / Core Data / None (network + in-memory only) | SwiftData | SwiftData requires iOS 17+ — validate against Q8 |
| 5 | Architecture pattern | MVVM / MVC / VIP (Clean Swift) / VIPER / MV (SwiftUI-native, `@Observable`, no separate ViewModel) | MVVM | Determines the layer set every feature scaffold generates — see §3 |
| 6 | Navigation implementation | UIKit `UINavigationController` + Coordinator (more mature) / SwiftUI `NavigationStack` + Router object (native, less glue code) | `UINavigationController` + Coordinator if Q3 includes any UIKit; either for SwiftUI-only | **Independent of Q3** — a SwiftUI app can still run its nav backbone on `UINavigationController` via `UIHostingController`; a pure-UIKit app cannot use `NavigationStack` at all — see §2.3 |
| 7 | Networking & concurrency | URLSession + async/await / URLSession + Combine / Alamofire | URLSession + async/await | Affects the generated `Service`/`Repository` signatures |
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
> 4. SwiftData, Core Data, or no local persistence?
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
├── README.md
├── docs/
│   ├── ONBOARDING.md
│   ├── CODING_STANDARDS.md
│   ├── GIT_CONVENTIONS.md
│   ├── PERMISSIONS.md                # created on first use of /add-permission
│   ├── PROJECT_MAP.md
│   └── ai/
│       ├── architecture.md           # rendered with the ONE chosen pattern's layers
│       ├── modularization.md         # rendered with THIS repo's tier + module graph — §3.9–§3.11
│       ├── theming_rules.md
│       ├── ui_rules.md
│       └── permissions_rules.md
├── .claude/skills/                   # copied over as-is from the template
├── Scripts/                          # copied over as-is from the template
│   ├── lint.sh
│   ├── check_hardcoded_colors.sh
│   ├── check_strings.sh              # key parity across locales, per module — §8.5
│   ├── generate_strings.sh           # <module> → that module's L10n.swift from its Localizable.strings
│   ├── new_module.sh
│   └── new_feature.sh
├── App/                              # the app target: composition root, identity, app-specific features
│   ├── <AppName>App.swift            # or AppDelegate/SceneDelegate for UIKit
│   ├── Theme/                        # app-level token overrides only — base tokens live in DesignSystem (§3.11)
│   ├── Localization/
│   │   ├── Localizable.strings       # this module's user-facing strings, keys namespaced `app.*`
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
│   │       └── Utilities/Debouncer.swift    # shared debounce helper for search-as-you-type interactors
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
│       │   └── SharedViews/          # LoadingView, ErrorView (message + optional retry), EmptyStateView
│       ├── Resources/
│       │   ├── Assets.xcassets       # shared iconography
│       │   └── Localization/         # this package's own strings + bundle-aware L10n (§3.11)
│       └── Tests/
└── TODO.md                           # created on first use — manual follow-ups per feature
```

Package boundaries are only worth their cost if they're directed: `App` → `DesignSystem`/`Networking` → `Models`/`Core`, never the reverse (§3.9). Anything the app touches from a package is `public` with an explicit `public init`.

### 3.2 Leaf feature folders are flat; models always live in the shared `Models/` package

Two fixed rules, applied regardless of architecture pattern:

- **A leaf feature's folder is flat.** `Features/Home/` contains every layer file for that screen directly — `HomeView.swift`, `HomeInteractor.swift`, `HomePresenter.swift`, and so on — named `<Feature><Layer>.swift`. No `Presentation/`/`Domain/`/`Data/` subfolders inside a feature. **Grouping folders one level above a leaf feature are allowed** — `Features/Settings/Profile/`, `Features/Settings/Notifications/` — when a flow genuinely contains several screens; what's banned is layer-named subfolders *inside* a screen's folder, not thematic grouping between `Features/` and the screen. (Shipped apps of this size nest exactly this way, two levels deep — see §8; a strictly flat `Features/` stops scaling somewhere around 30 screens.) `/new-feature` accepts a path — `/new-feature Settings/Profile` — and creates the intermediate group without inventing layer subfolders.
- **Models never live inside a feature folder, ever.** Every model type — a domain model shared across screens (`Movie`, `TVShow`) and a single feature's own Request/Response/Entity/ViewModel structs alike — lives in the top-level `Models/` package instead. This is a deliberate simplicity choice: one place to look for any data shape in the app, at the cost of `Models/` growing large and needing file-per-feature discipline (`Models/HomeModels.swift`, `Models/SearchModels.swift`) rather than one shared file for everything — see §10 for the naming-collision trade-off this creates. At T2/T3 `Models/` is one module, shared by every consumer; a model needed by only one app still lives there unless it is genuinely app-private, in which case it may stay in that app's own `Models/`.
- **Exception — MV's `Model` is not a data model.** In the MV (SwiftUI-native) pattern, `<Name>Model.swift` is an `@Observable` class holding view state and calling services — it's presentation-layer plumbing, analogous to a ViewModel, and stays in `Features/<Name>/` like every other layer file. Don't confuse it with the data models in `Models/`.

Applied consistently by both `/start`'s starter feature and every feature `/new-feature` generates afterward. On an adopted project (Path 3, §2.1 step 13), the folder named `Features/` throughout this section is whatever name `/start` detected on disk (e.g. `Scenes/`, `Modules/`) and recorded in the config — everything else here applies unchanged once that substitution is made; `new_feature.sh` reads the name from config rather than hardcoding it.

### 3.3 Architecture Pattern Reference

| Pattern | Files directly inside `Features/<Name>/` (flat) | Notes | Fully templated? (§1.4) |
|---|---|---|---|
| **MVC** | `<Name>ViewController.swift` (+ `.xib`/storyboard if used) | Models live in `Models/`, never here. Simplest, most Massive-View-Controller risk — reasonable only for very small apps. | UIKit: yes (`mvc-uikit-coordinator`). SwiftUI: template-assisted — see the MV row instead. |
| **MVVM** *(default)* | `<Name>View.swift`, `<Name>ViewModel.swift`, `<Name>Repository.swift`, `<Name>Service.swift` | View binds to an `ObservableObject`/`@Observable` `ViewModel`; `ViewModel` depends on the Repository's protocol directly — no separate business-logic layer between them. If a feature needs to orchestrate more than one repository/service, or apply a rule that belongs in neither the ViewModel nor the Repository, add an `<Name>Interactor.swift` (the native-iOS name for that layer, already used by VIP/VIPER below) rather than a `UseCase` — see §8.2's "don't abstract on speculation." | SwiftUI + `NavigationStack`: yes. UIKit/Coordinator: template-assisted. |
| **VIP (Clean Swift)** | `<Name>View.swift` (SwiftUI: **+ `<Name>ViewModel.swift`**), `<Name>Interactor.swift`, `<Name>Presenter.swift`, `<Name>Router.swift`, `<Name>Worker.swift` | Request/Response/ViewModel structs live in `Models/<Name>Models.swift`, not here. Strict unidirectional flow: View → Interactor → Presenter → View. SwiftUI needs the extra `ViewModel` as a bridge, since a SwiftUI View can't hold `weak var displayLogic` itself (§1.4) — UIKit's `ViewController` holds it directly, no bridge needed. | Yes, both variants: `vip-swiftui-navigationstack` and `vip-uikit-coordinator`. |
| **VIPER** | `<Name>View.swift`, `<Name>Interactor.swift`, `<Name>Presenter.swift`, `<Name>Router.swift` | Entity structs live in `Models/<Name>Models.swift`. Full separation, heaviest boilerplate. Differs from VIP only by dropping the `weak` reference and giving Router full navigation ownership — close enough to VIP that it's deliberately not given its own template (§1.4). | Template-assisted. |
| **MV (SwiftUI-native)** | `<Name>View.swift`, `<Name>Model.swift` | `<Name>Model` is presentation state, not a data model — see the exception in §3.2. Fewest layers, least isolatable for unit testing. | Template-assisted. |

### 3.4 Navigation approaches (independent of the architecture pattern above and of Q3's UI framework)

| Approach | How a screen gets pushed | Notes |
|---|---|---|
| **`UINavigationController` + Coordinator** | Coordinator holds the `UINavigationController` and calls `pushViewController`; SwiftUI screens wrapped in `UIHostingController` before pushing | More mature — precise stack control, reliable interactive-pop, easier custom transitions. Works regardless of whether individual screens are UIKit or SwiftUI. |
| **SwiftUI `NavigationStack` + Router** | A `Router` holds a `NavigationPath`/typed path array; Views append/remove from it, `.navigationDestination` maps a route to a screen | Less glue code, fully declarative — only available when the hosting screen is SwiftUI. |

Whichever is chosen (Q6) is the **one** navigation mechanism for the whole app — `/new-feature` always wires into it, never introduces a second path. At T3 with more than one app, each app owns its own navigation root, but both must use the *same* mechanism — a shared framework can only vend pushable screens if it can assume one navigation contract (§3.9).

**Don't confuse this `Router` with VIP's per-scene `Router.swift` (§3.3, §1.4).** This section's `Router`/`Coordinator` is the one app-wide mechanism that actually owns the `NavigationPath`/`UINavigationController`. VIP's own `<Name>Router.swift` is a per-scene layer file that decides *where* a given scene should go next and hands that decision to whichever app-wide mechanism is in force here — it never owns navigation state itself.

### 3.5 Tab-based apps: independent navigation per tab

If the app has a tab bar, **each tab owns its own navigation stack** — never a single shared one: one `Coordinator` (and its own `UINavigationController`) per tab, or one `NavigationStack`/`Router` per tab. Pushing a detail screen from one tab must never affect another tab's back stack. This belongs in `/start`'s app-shell template, not left for the first multi-tab feature to improvise.

### 3.6 Shared loading / error / empty states

Every list or detail screen needs the same three states. Generate them once in `DesignSystem/SharedViews/` and have every feature consume them rather than re-inventing a spinner/error text per feature. `ErrorView` takes a message and an optional retry closure wired to redispatch the same load action.

### 3.7 Shared utilities — never duplicated per feature

These five live in exactly one place each, referenced by every feature that needs them — never re-implemented locally:

| Utility | Location | What it does |
|---|---|---|
| Request builder | `Networking/RequestBuilder.swift` | Base URL, headers, API-key injection, query params — one place every `Service` calls through |
| API caller | `Networking/APIClient.swift` | Executes the built request via URLSession (or Alamofire per Q7), decodes the response, maps errors/failures/empty responses |
| Models | `Models/` | Every model type in the app, per §3.2 — domain models and per-feature Request/Response/Entity structs alike |
| Localization | `<module>/Localization/` | One strings catalog **per resource-owning module**, not one per repo, with a bundle-aware `L10n` per module — §3.11 |
| Theming | `DesignSystem/Theme/` (base) + `App/Theme/` (overrides) | Colors and typography as Swift values — see §6 and §3.11 |

`Scripts/generate_strings.sh <module>` regenerates that module's `L10n.swift` from its `Localizable.strings` whenever the latter changes — run by `/start` once per module at setup and by `/add-permission`/`/new-feature` whenever they add a new user-facing string, the same "typed accessor over a magic string" pattern already used for colors (§6) and assets (§4.2). Run with no argument it does every module in the config.

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
│   └── Resources/{Assets.xcassets, en.lproj/…, Info.plist, <AppOne>.entitlements}
├── <AppTwo>/                               # same shape — different identity, theme, feature set
├── Shared/                                 # framework: the spine both apps import
│   ├── project.yml
│   ├── Sources/{Api,Models,Theme,Views,Utilities,Localization}
│   ├── Resources/{Assets.xcassets, en.lproj/…}     # frameworks own their own resources
│   └── Tests/
├── DesignSystem/                           # optional: split out once Shared/Views gets big
└── Logging/                                # leaf framework — depends on nothing in this repo
```

Names are placeholders — `/start` uses whatever the team answers at Q12. What's prescriptive is the *shape*: apps are thin and interchangeable in structure, the spine is a framework, and leaves depend on nothing.

**Dependency rule, enforced by review and by `/add-module`:** apps → shared frameworks → leaf frameworks. Never framework → app. Never app → app. A shared framework that needs app-specific behaviour takes it as a protocol or closure injected by the app at launch — that inversion is the single most load-bearing convention at T3, and it's what makes "base views each app extends" work instead of degenerating into `if currentApp == .x` branches inside shared code. §8.2 covers the abstraction discipline this depends on.

**Framework project vs. local Swift package at T3.** Both are legitimate; don't mix arbitrarily.

| | Framework `.xcodeproj` | Local Swift package |
|---|---|---|
| Resources (assets, `.lproj`, fonts) | first-class, plain bundle | works, but via `Bundle.module` and `resources:` declarations |
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

- **Localization is per resource-owning module, not per repo.** `NSLocalizedString` resolves against a bundle: a framework that ships user-facing views must carry its own `.lproj` set, or its strings silently fall back to the key at runtime in the consuming app. So every module that has UI owns `Localization/Localizable.strings` (+ its translations), and its generated `L10n.swift` is **bundle-aware** — the accessor resolves through that module's own bundle, never `Bundle.main`. Keys are namespaced by module (`shared.error.retry`, `app.settings.title`) so two modules can't collide, and `Scripts/check_strings.sh` verifies key parity across locales *within* each module and flags cross-module duplicates (§8.5). At T1 — and only at T1 — there is one module, so this collapses to one app-level `Localization/`.
- **Theme is base + override, not one file.** Base tokens (the full palette, type scale, spacing) live in the shared module's `Theme/`. Each app owns a thin `Theme/` of its own that overrides only what actually differs — brand color, maybe a font family — and adds nothing else. `/update-theme` must ask which layer a token belongs in and refuse to write an app-specific value into the shared module (§4.5). Two apps that each redefine the whole palette are not sharing a design system, they're maintaining two.
- **Assets, icons, permissions and identity are per app, always.** Asset catalogs may exist in both shared modules and apps (shared iconography vs. brand art), but `AppIcon`, `Info.plist`, `.entitlements`, bundle ID, display name and signing are app-target-only. Any Skill touching those must resolve *which app* before acting (§4.2–§4.4).

One more, which the config makes mechanical rather than a matter of taste: **`/new-feature` needs a target module.** "A screen in one app" and "a base view both apps extend" are different destinations with different visibility requirements. The Skill takes `--module`, defaults to the config's declared default app at T1/T2, and at T3 with more than one app **refuses to guess** (§4.1).

---

## 4. The Other Skills

Each checks §1.3's precondition first, then reads `ios-skeleton.config.json` to know which architecture/UI framework/navigation style **and topology** is in force — never asks the developer to re-specify it per invocation.

**Topology branch, applied by every Skill below.** At T1 there is one destination and no question to ask. At T2/T3 the config lists modules and apps; each Skill resolves its destination in this order: an explicit `--module`/`--app` argument → the config's declared default → **stop and ask**. No Skill may guess a destination when the config declares more than one candidate, and none may write into a module whose kind forbids it (a framework can't own an `Info.plist` permission; a leaf logic package can't own an asset catalog).

### 4.1 `/new-feature [--module <M>] <name> "field:Type,..."`

**Invocable in prose, but never on a guess.** The Skill is expected to be reached both by the argument form above and by plain English ("add a films list screen showing the title and release year") — the script only ever receives the argument form, so the Skill is what translates. Because that translation *invents* information the developer never supplied, the Skill must batch-ask the three things prose cannot carry, skipping any the invocation already answered explicitly, and must echo the resolved command before running it:

Ask them in this order, because the second depends on the first:

1. **Target module** — ask before invoking whenever `ios-skeleton.config.json` leaves more than one candidate, rather than letting the script's refusal (§4's topology branch) be how the developer discovers the ambiguity. The feature directory, test directory and `Localizable.strings` all hang off the resolved module, and generated keys are namespaced `<module>.<feature>.*`.
2. **Grouping** — flat `<module>/Features/<Name>/` by default; ask with the concrete alternative whenever the request implies a section or flow, or the resolved module's feature directory already has group folders. There is no fixed `Features/` path to inspect until step 1 is settled.
3. **Field list and Swift types** — never inferred from English nouns. Propose a typed list, flag the genuinely ambiguous ones (an "avatar" is `URL`/`String`/`Data`; an "amount" is `Decimal`/`Double`), and confirm. An empty field list is legal and yields a property-less model — that is a decision to state, not a default to assume.

The rationale is that none of the three is cheap to reverse: models land in the shared `Models/` where a colliding type name stops the run, the script refuses if the feature folder already exists, and a feature generated into the wrong module has to be moved by hand along with its strings and access modifiers. This establishes the general principle — *an agent-chosen default is acceptable only where it is both stated and trivially reversible* — but note honestly that `/new-feature` is currently the only Skill that asks proactively. The others (`/add-assets`, `/add-module`, `/add-app`, `/update-theme`, `/translate`, `/add-permission`) rely on their script refusing an ambiguous destination, which surfaces the same question later and less usefully. Extending the batched-confirmation pattern to them is a deliberate follow-up, not something already built.

Generates, end to end, per §3.2's layer shape for the project's chosen architecture:

- Business layer: for MVVM (default), the ViewModel depends on the data layer's *protocol* directly — no separate business-logic layer is generated by default (§3.8). For VIP/VIPER, the Interactor is this layer: one operation, pure Swift, no UI/networking imports. Never generate a `UseCase` — if a feature's ViewModel later needs to orchestrate more than one repository/service, add an `Interactor` instead (§3.8, §8.2).
- Data layer (Repository + Service): protocol + implementation, wired to the chosen networking stack (`Networking/RequestBuilder.swift` + `APIClient.swift` — never a second networking path). The protocol is declared where it's consumed, named for the capability rather than the type it abstracts (§8.2).
- Presentation layer (ViewModel/Presenter/Controller + View): matching the chosen UI framework, as a flat set of files directly in `Features/<Name>/` — see §3.2.
- Models: writes `Models/<Name>Models.swift` in the shared package (§3.2/§3.7), never a file inside the feature folder. If a type name in the new feature's field list collides with an existing type already in `Models/`, stops and asks rather than silently overwriting or shadowing it.
- Navigation: registers the new screen with whichever mechanism Q6 selected — a new `Router`/`Route` case or a new `start()` method on the feature's `Coordinator` — never a second, ad-hoc path. If part of a tab-bar flow, wires into that tab's own stack only (§3.5).
- If the field list includes a search-as-you-type input, wires it through `Core/Utilities/Debouncer.swift` rather than firing a request per keystroke.
- Destination: resolves the target module per §4's topology branch before generating anything. Accepts a grouped path (`/new-feature Settings/Profile`) per §3.2. If the resolved module is a shared framework rather than an app, every generated type the app must see is `public` with an explicit `public init` — the single most common reason an extracted module doesn't compile from its consumer (§3.10).
- If the feature introduces new user-facing text, adds it to **the target module's** `Localizable.strings` with that module's key namespace and re-runs `Scripts/generate_strings.sh <module>` rather than hardcoding a string literal (§3.11).
- A **real, passing unit test** against a fake dependency — not a placeholder. Fake values default sensibly by type (`String → "test"`, `Int/Double → 0`, `Bool → true`, `Date → .now`, `Optional<T> → nil`); an unrecognized/custom type still compiles but fails loudly at test runtime (`fatalError("TODO: provide a fake value for <Type>")`) rather than silently guessing wrong.
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

- Adds/edits a token in `Theme/ColorTokens.swift`/`Typography.swift` — **never** `Assets.xcassets`. See §6.
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
- Creates that app's own theme override layer (§3.11) and its own `.lproj` set, seeded from the shared module's key list.
- Adds the project to the workspace and regenerates; appends both the app and its per-app manual follow-ups (signing, App Store record, push certs) to `TODO.md`.
- Does **not** copy features from the existing app. If two apps need the same screen, it belongs in a shared module — the Skill says this rather than duplicating, because a copied screen is the fastest way to lose the value of T3.

### 4.9 `/translate [--module <M>] <locale-code> [locale-code...]`

Resolves §10's former "no localization Skill" gap. Drafts target-locale entries; never a substitute for a human review pass before shipping.

- Resolves the target module the same way §4.1 does (`--module` → config default → single-module fallback → ask).
- Reads that module's base locale (`en.lproj/Localizable.strings`, the only locale `/new-feature`/`/add-permission` write to) as the source of truth.
- For each requested locale code not yet present under the module's `Localization/` folder, creates `<locale>.lproj/Localizable.strings` from scratch; for a locale that already exists, adds only the keys `check_strings.sh` reports as **missing** in it — never touches a key a human has already translated, drafted or not.
- Every newly drafted line is agent-translated from the base English string and marked, in-file, as needing review — e.g. `/* NEEDS_REVIEW */ "home.title" = "...";` — so `grep -r NEEDS_REVIEW` finds every unreviewed line across the repo and a reviewer can clear the marker once they've checked it. A key is never left both marked-reviewed and untranslated.
- Re-runs `Scripts/generate_strings.sh <module>` afterward so the new locale's keys are covered by the same `L10n.swift` accessor as every other locale — `/translate` adds *strings*, it never changes what `L10n` exposes, since the base locale's key set is unchanged.
- Does not decide which locales a project ships — that's an explicit argument every invocation, never a guessed default, and not part of `/start`'s questionnaire (§2.2). A project records its shipped locale list wherever it already tracks product decisions (`docs/PROJECT_MAP.md` is the natural place); this Skill only fills in what's asked for.
- Refuses the same way every other Skill does if `ios-skeleton.config.json` is missing (§1.3), and if the base locale itself has keys `check_strings.sh` reports as inconsistent — fix the source of truth before drafting more locales from it.

---

## 5. Meta Files ("AI Brain")

| File | Rendered by | Forces the agent to... |
|---|---|---|
| `CLAUDE.md` | `/start`, from `CLAUDE.md.template` | Know the tech stack, chosen architecture, **topology tier and module graph**, and where deeper rules live — auto-loaded every session |
| `docs/ai/architecture.md` | `/start`, from `.template` | Use the one architecture pattern chosen at setup — no mixing patterns feature-to-feature |
| `docs/ai/modularization.md` | `/start`, from `.template` | Know the tier, the module graph and its direction, which module owns strings/assets/theme tokens, and what `--module` defaults to — the rules from §3.9–§3.11 rendered for *this* repo only |
| `docs/ai/theming_rules.md` | shipped as-is in the template | Route every color/font choice through a `Theme/` directory — the shared module's for base tokens, the app's for overrides (§3.11) |
| `docs/ai/ui_rules.md` | shipped as-is | Mandatory `#Preview`, no hardcoded strings — use the owning module's `L10n.<key>` (§3.7, §3.11), never `Localizable.strings` accessed by raw key, never `Bundle.main` from inside a framework — real/explicit-`nil` accessibility labels — SF Symbols over imported icon assets wherever a symbol exists, `AsyncImage` for remote images by default (§6, §10) |
| `docs/ai/permissions_rules.md` | shipped as-is | Never add a permission without a non-empty usage string, a named app target, and a `docs/PERMISSIONS.md` entry |
| `docs/PROJECT_MAP.md` | `/start` seeds it, features and modules append | One line per file/folder not covered by the feature-first convention, the module list with each module's kind and consumers (§4.7), plus which architecture combos are template-backed vs. agent-assisted (§1.4) |
| `docs/CODING_STANDARDS.md` | shipped as-is | SwiftLint rules, naming, force-unwrap policy, `// MARK:` organization, and §8.2's protocol-boundary rules — dependencies are protocols, app-specific behaviour is injected, no branching on which app is running inside shared code |
| `docs/GIT_CONVENTIONS.md` | shipped as-is | Feature-based commits, message format, optional branch naming |
| `docs/ONBOARDING.md` | `/start`, from `.template` | What this project is, day-to-day prompting guidance |
| `README.md` | `/start`, from `.template` | Tech stack, structure, getting-started, troubleshooting — for the real app, not the template |
| `docs/PERMISSIONS.md` | created on first `/add-permission` | Running list of every declared permission + justification |

### 5.1 Xcode's own coding intelligence — interoperate, don't compete

Xcode now runs coding agents natively (Claude Agent, Codex) under **Xcode ▸ Settings ▸ Intelligence**. This template's surface is Claude Code in the terminal — `Scripts/` and the `core.hooksPath` hooks are terminal-side regardless of which agent drives them. Four facts change what `/start` should do, all verified against Apple's Xcode documentation. **Explicitly not established:** whether the in-Xcode Claude Agent loads a repo's `.claude/skills/`. Apple documents only that agent config under `~/Library/Developer/Xcode/CodingAssistant/` applies to in-Xcode launches; it says nothing about project-level Skill discovery. Do not write either claim into a rendered doc as settled.

1. **Xcode exposes its capabilities to external agents over MCP.** With **Intelligence ▸ Model Context Protocol ▸ "Allow external agents to use Xcode tools"** enabled, `xcrun mcpbridge` bridges an agent launched outside Xcode into the open project — build, test, and project actions run through Xcode itself instead of a reconstructed `xcodebuild` invocation. Registration is one line: `claude mcp add --transport stdio xcode -- xcrun mcpbridge`. The project must be open in Xcode, and Xcode notifies the developer on connect and while active. **`/start` must add this to `TODO.md` as an offered, optional step** — never run it silently, since it changes machine-level agent configuration outside the repo.
2. **Agent permissions are global to the Mac, not scoped to the repo.** **Intelligence ▸ Agents ▸ Permissions** holds the Allowed Commands / Allowed Tools lists, accumulating whatever was approved in any transcript, and applies across every project. Nothing this template writes can scope, audit or version that list — say so rather than implying the repo controls it.
3. **In-Xcode agent config lives outside the repo.** Files under `~/Library/Developer/Xcode/CodingAssistant/` (e.g. `ClaudeAgentConfig`) affect agents *launched in Xcode only*. The repo's `CLAUDE.md` is read by both surfaces, but Xcode expects it beside the `.xcodeproj` — repo root at T1/T2, which is **not** automatic at T3 where each project sits in its own folder. At T3, `/start` and `/add-app` should note this in `TODO.md` rather than assume the root file is found.
4. **Xcode's localization agent targets String Catalogs, this template targets `.strings`.** Xcode adds languages, populates `.xcstrings`, and marks entries Machine Translated (`state-qualifier: leveraged-mt` on XLIFF export). `/translate` (§4.9), `generate_strings.sh` and `check_strings.sh` operate on per-module `Localizable.strings`. **These are two sources of truth for the same content** — §10 carries this as a limitation, and a project must pick one. If a team chooses String Catalogs, the parity/order scripts no longer describe reality (§8.5 already flags this trade-off for new projects).

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
- `.githooks/pre-commit` (wired via `core.hooksPath` by `/start`) runs these plus the test suite on any staged `.swift` change. At T3 it runs tests only for the modules whose files are staged, plus their dependents — running every app's full suite on every commit is how a hook gets disabled by the team.
- `.githooks/commit-msg` (§10, resolved) checks the message's first line against `docs/GIT_CONVENTIONS.md`'s format — `(<TICKET-ID> )?<type>: <summary>` with `<type>` one of `feat`/`fix`/`refactor`/`test`/`docs`/`chore` — and rejects the commit with the expected pattern on a mismatch. It checks shape only, never content: it can't tell a well-written summary from a lazy one, only that the format is there.
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

- *Recommended:* one `AppEnvironment` type per app resolving base URL, API keys and feature endpoints from build configuration — never a literal URL inside a `Service`. `Networking/RequestBuilder.swift` (§3.7) reads it; nothing else does.
- **Never commit secrets.** API keys that must ship get injected at build time from the CI environment or a gitignored `Secrets.xcconfig` with a committed `Secrets.xcconfig.example`. An API key in an Info.plist is extractable from the IPA — treat "in the binary" as "public", and keep anything genuinely sensitive server-side.
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

- *Observed in production:* 18 locales maintained **per module** — each app and the shared framework carries its own full `.lproj` set. This is the concrete evidence behind §3.11's per-module rule; it is a bundle-resolution fact, not a stylistic preference.
- *Observed in production:* a dedicated tooling layer around strings, because at 18 locales × 3 modules manual editing is not viable. That layer covers: importing a translation-service export **updating only existing keys, never adding new ones**; adding a key to every locale at once; removing a key from every locale; and checking for (a) unused keys, (b) keys out of order within a file, (c) keys in the base locale missing or extra in others. Translation imports are reviewed, never auto-merged.
- **This template's `Scripts/check_strings.sh` must implement at least the parity check** — base locale vs. every other locale, per module — and run in the pre-commit hook and CI. Missing-key drift is invisible until a user in one language sees a raw key on screen.
- *Recommended:* namespace keys by module and screen (`shared.error.retry`, `app.settings.title`) and keep files sorted, so the order check is meaningful and diffs stay readable.
- *Recommended for new projects:* `.xcstrings` String Catalogs (Xcode 15+) over `.strings`, which gets ordering, pluralization and missing-translation state from Xcode itself. Note honestly that this changes what the parity/order scripts operate on, and that a large existing `.strings` corpus is usually not worth migrating.

### 8.6 Observability

- *Observed in production:* a first-party logging module with explicit levels rather than scattered `print`, plus an analytics layer inside the shared framework. A logging module as the *leaf* of the dependency graph — depending on nothing — is exactly the right shape (§3.9), and it's only reusable because it's a protocol with a default implementation rather than a global function.
- *Recommended:* crash reporting and analytics sit behind a protocol owned by the shared module, with the concrete SDK injected per app (§8.2). Two apps frequently report to different destinations, and the vendor changes more often than the call sites.
- *Recommended:* logging is level-gated and never logs tokens, credentials, or personal data — a rule worth a `custom_rules` regex, not just a doc line.

### 8.7 Testing and CI

- *Observed in production:* framework projects carry their own test targets and shared schemes; app-level coverage is thinner than framework coverage. That's the normal, correct asymmetry — logic pushed behind module boundaries and protocols is what makes it testable at all, which is the strongest argument for T2/T3 beyond tidiness.
- *Recommended:* CI runs, per push: lint (`--strict`), `check_strings.sh`, and `xcodebuild test` **per scheme**. At T3 that's a matrix — one entry per app plus one per framework — growing every time `/add-app` or `/add-module` runs. Budget for it; a workspace multiplies CI time, not just target count.
- No pipeline is authored by this template (§10), but `/add-app`/`/add-module` should append a `TODO.md` entry reminding the developer to add the new scheme to CI.

### 8.8 Repo hygiene

- **Decided: generated `.xcodeproj`/`.xcworkspace` files are committed, not gitignored** (§10 — no longer left to the team). `/start` and every subsequent `/add-module`/`/add-app` regenerate them in place; committing keeps the repo openable without requiring XcodeGen/Tuist installed just to get to a build, at the cost of a pbxproj diff on every regenerate. Write this in the rendered `README.md` so a contributor isn't left guessing which policy this repo picked.
- Always gitignored regardless of that decision: `xcuserdata/`, `.DS_Store`, build products, `Secrets.xcconfig`, compiled tool binaries — none of that is reproducible-by-regeneration, it's either machine-local state or a secret.
- *Observed in production:* an orphaned framework project sitting in the repo, referenced by no workspace and holding no sources — a module someone started and nobody removed. This is the characteristic T3 failure mode: modules are cheap to add and nobody deletes them. `/status` should flag any project directory not listed in the workspace and any module with no consumers (§4.6).
- *Observed in production:* commits carry the tracker ticket ID and land via PR. Encoded in `docs/GIT_CONVENTIONS.md` and its format mechanically checked by `.githooks/commit-msg` (§7, §10) — though the ticket-ID prefix itself stays convention-only, since the hook can't know whether a given team's tracker issues one.

### 8.9 App Store requirements that are easy to forget

- **Privacy manifest** (`PrivacyInfo.xcprivacy`) per app, declaring collected data types and required-reason API usage; third-party SDKs need theirs too, and App Store Connect rejects on this at upload time, not at build time.
- Per-app: App Store Connect record, push certificates/keys, App Groups if extensions share storage, and export-compliance answers.
- Accessibility as a merge gate, not a phase: Dynamic Type support, real or explicitly-`nil` accessibility labels (already in `ui_rules.md`, §5), and VoiceOver-passable navigation on every new screen `/new-feature` generates.
- Dark mode: guaranteed by construction if every color goes through §6's light/dark token pairs — which is the second reason the Asset Catalog deviation earns its keep.

---

## 9. Deliverables Checklists

### 9.1 Phase A — what this execution must produce

- [ ] `ios-ai-skeleton/` repo per §1.1 — no `App/`, `Features/`, `project.yml`, `.xcworkspace`, or `ios-skeleton.config.json`
- [ ] `.claude/skills/start/SKILL.md` implementing all of §2, including the topology branch and the Path 3 adoption flow
- [ ] `.claude/skills/{new-feature,add-assets,update-app-icon,add-permission,update-theme,status,add-module,add-app,translate}/`, each gated by §1.3 and each implementing §4's destination-resolution rule
- [ ] `Scripts/templates/{mvvm-swiftui-navigationstack,vip-swiftui-navigationstack,vip-uikit-coordinator,mvc-uikit-coordinator}/` fully authored (§1.4); other combinations left template-assisted
- [ ] `Scripts/generate_workspace.sh` (§3.9) and `Scripts/new_module.sh` (§4.7)
- [ ] `.swiftlint.yml`, `Scripts/lint.sh`, `Scripts/check_hardcoded_colors.sh`, `Scripts/check_strings.sh` (§8.5), `Scripts/generate_strings.sh` taking a module argument, `.githooks/pre-commit`, `.githooks/commit-msg` (§7)
- [ ] `docs/*.md` and `docs/ai/*.md`/`.template` files per §1.1 and §5, including `modularization.md.template`
- [ ] `CLAUDE.md.template`, `README.md` describing the template itself (§1.2)

### 9.2 Phase B — what a successful `/start` run must produce (build this expectation into the Skill itself)

- [ ] `ios-skeleton.config.json` recording every Q1–Q12 answer, plus the resolved module and app lists
- [ ] Spec file(s) per tier and a real `.xcodeproj` per project from `xcodegen generate`/`tuist generate` — plus, at T3, a `.xcworkspace` listing every project and a shared scheme per project
- [ ] Folder tree per §3.1 and the tier's shape per §3.9; layer shape per §3.2/§3.3 for the chosen architecture
- [ ] One working `Features/Home/` **per app** proving the stack compiles, with a real passing test — plus, at T3 multi-app, one shared base view both apps consume
- [ ] `Theme/` with at least one real color + font token, no Asset Catalog colors — base tokens in the shared module and a per-app override layer from T2 onward (§3.11)
- [ ] `DesignSystem/SharedViews/` — `LoadingView`, `ErrorView` (with retry), `EmptyStateView`
- [ ] `Networking/RequestBuilder.swift` + `APIClient.swift`
- [ ] `Models/` created, with the starter feature's Request/Response/Entity structs in `Models/HomeModels.swift` — none of them left inside `Features/Home/`
- [ ] Per-module `Localizable.strings` + generated **bundle-aware** `L10n.swift`, each `Features/Home/` referencing `L10n.*` and not a raw string literal
- [ ] `Package.resolved` at the tier-correct location (§3.10 step 3)
- [ ] Git initialized (or detached from the template's history, if offered and accepted) with `.githooks/pre-commit` and `.githooks/commit-msg` wired
- [ ] `CLAUDE.md`, `README.md`, `docs/ONBOARDING.md`, `docs/ai/architecture.md`, `docs/ai/modularization.md` rendered with real, locked-in decisions — no leftover placeholders
- [ ] `docs/PROJECT_MAP.md` seeded with §5's three sections (uncovered files/folders, the module list with kinds and consumers, template-backed vs. agent-assisted combos) — `CLAUDE.md` links to it, so a missing file is a dead link on day one
- [ ] `TODO.md` carrying the manual follow-ups, including the per-app items from §8.9

---

## 10. Known Limitations / Open Questions

Carry an honest, up-to-date version of this section into the rendered `README.md`/`ONBOARDING.md`. As of writing this prompt:

- ~~Objective-C scope is undefined.~~ **Resolved:** dropped entirely. Q2 is now a fixed Swift-only default with no interactive choice (§2.2) — this template scaffolds nothing for Objective-C. A project with legacy Objective-C to bridge in still can (a bridging header is a manual, one-time Xcode step), but no Skill or template file accounts for it.
- ~~Only one architecture combination is fully template-backed at launch.~~ **Resolved, partially:** four now are (§1.4) — MVVM+SwiftUI+`NavigationStack`, VIP+SwiftUI+`NavigationStack`, VIP+UIKit+Coordinator, and MVC+UIKit+Coordinator — and only at T1/T2 shape. Everything else (MVC+SwiftUI, MV either UI framework, VIPER, any architecture on the non-default navigation approach for its UI framework) stays template-assisted rather than fully deterministic — an honest scoping choice, not an oversight; expand further as real usage shows which combos are common. At T3, `/add-module`/`/add-app` generate specs, wiring and the workspace deterministically, but a module's *contents* are agent-written.
- **Idempotent conflict-handling in `/start` (§2.4) is agent judgment, not a mechanical diff.** Unlike a byte-for-byte "embedded copy in sync" check, deciding whether a new answer conflicts with existing generated code relies on the agent inspecting `Features/` and reasoning about it — there's no automated guarantee it catches every case.
- ~~`docs/PROJECT_MAP.md` is referenced but never created.~~ **Resolved:** §5's table always said `/start` seeds it and `CLAUDE.md.template` links to it, but neither §2.1 step 11 nor `start/SKILL.md` §1.9 created one — it first appeared whenever `/add-module` or `/translate` happened to append to it, leaving a dead link in `CLAUDE.md` until then. Both the step and the Skill now seed it explicitly, and §9.2's checklist verifies it. There is deliberately no `.template` for it: its day-one content is derived from the answers, not from placeholder substitution.
- **Proactive confirmation is implemented in `/new-feature` only (§4.1).** It batch-asks module, grouping and field types before generating; `/add-assets`, `/add-module`, `/add-app`, `/update-theme`, `/translate` and `/add-permission` still rely on their script refusing an ambiguous destination, which raises the same question later and with less context. The inconsistency is documented rather than fixed — extending the pattern is a deliberate follow-up.
- **`new_feature.sh` cannot place a feature in a module that isn't an app.** §4.1 contemplates a shared framework as the destination (hence its `public`/`public init` guidance), and §4's topology branch resolves "the target module" generally — but the script's path lookup reads the config's `apps` list only and falls back to the app path when the name isn't found there, so `--module <framework>` silently writes the feature, its tests and its strings into the app instead. Either the script should resolve against `modules` too, or §4.1 should restrict the destination to app targets; today the spec and the script disagree.
- **Two localization toolchains can silently split the source of truth (§5.1).** Xcode's built-in localization agent writes String Catalogs (`.xcstrings`); `/translate`, `generate_strings.sh` and `check_strings.sh` operate on per-module `Localizable.strings`. Nothing detects a project using both — `check_strings.sh` simply doesn't see the half it doesn't own, so parity passes while a locale is actually incomplete. A project must pick one, and this template has no mechanism to enforce that choice.
- **Agent permissions granted inside Xcode are global to the Mac and invisible to this repo (§5.1).** The Allowed Commands / Allowed Tools lists in Intelligence settings apply to every project and every agent launched in Xcode. Nothing here can scope, version or audit them, so a repo-level review of "what can an agent run?" is incomplete by construction.
- **Detaching a cloned template's git history (§2.1 step 7) is offered, not automatic** — a team could still end up with the template repo's history if they decline or if `/start` is run non-interactively.
- ~~No localization *Skill* defined.~~ **Resolved:** `/translate` (§4.9) drafts target-locale `.strings` entries from the base locale, marked for human review, on top of the localization *utility* that already existed (§3.7).
- **`Models/` holding every type — including per-feature Request/Response/Entity structs that aren't actually reused elsewhere — is a deliberate simplicity trade-off (§3.2), not a claim that everything in there is genuinely shared.** It buys "one place to look for any data shape" at the cost of a growing, multi-author file directory and real naming-collision risk (two features both wanting a type called `Item`, say). The mitigation is filename discipline (`Models/<Feature>Models.swift`) plus `/new-feature`'s collision check (§4.1) — there's no compiler-level namespacing beyond that.
- **No hardcoded-*string* enforcement script**, unlike colors (`check_hardcoded_colors.sh`). A raw string literal in `Text(...)`/`UILabel.text` isn't mechanically caught the way a raw `UIColor(red:...)` is — flagged as a documented convention in `ui_rules.md` only, since a blanket check would false-positive heavily on legitimate non-UI string literals (log messages, format strings, identifiers).
- **No CI pipeline included — confirmed as deliberate scope, not an open question.** GitHub Actions/Xcode Cloud wiring stays out of both phases: CI is infra-specific (runners, signing, host choice) in a way that would force a guess this template has no basis for. Add on request. Note that at T3 this is a per-scheme matrix that grows with every `/add-app` and `/add-module` (§8.7) — the cost is real and the template only reminds you about it.
- **Topology migrations are documented and partly scripted, not automated.** §3.10 lists real steps and `/add-module`/`/add-app` do the additive half, but the access-control pass, the file moves, and the `import` rewrites are manual and reviewed. Nothing verifies an extraction is *complete* — the original app keeps compiling long after it isn't (§3.10). Building the second consumer is the only real check.
- **Per-module localization is a correctness requirement, not a preference — and it has no compile-time guard.** A framework using `Bundle.main`, or a key present in one locale and missing in another, fails at runtime in one language only. `check_strings.sh` catches key parity; nothing catches a wrong-bundle lookup (§3.11, §8.5).
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
