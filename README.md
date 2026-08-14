# iOS AI-Optimized Skeleton

A reusable **template repository** for iOS projects built to be worked on by an
AI coding agent (Claude Code, Codex, etc.) — deterministic scaffolding,
auto-loaded meta-files, enforced lint/style, and Skills for routine work.

This repo describes **the template system itself**, not any one app. There is no
Xcode project here, no architecture decision, no `ios-skeleton.config.json` —
those all belong to a real project generated *from* this template, via `/start`.

## Quick start

`/start` takes an optional target path and copies its own files in — no
manual `cp -r`:

```bash
# No path — clone the template as a new project's root, then run /start inside it
git clone <template-repo-url> MyNewApp && cd MyNewApp
/start

# A path — run from anywhere; /start inspects the target and picks the right scenario
/start MyNewApp             # missing or empty → fresh start
/start ~/Code/ExistingApp   # a mature single .xcodeproj → adoption, never overwrites what's there
/start ~/Code/Workspace     # an existing .xcworkspace + N projects → adoption
```

`/start` asks a one-time Setup Questionnaire (topology, language, UI framework,
persistence, architecture, navigation, networking, minimum iOS version, DI
style, testing framework, tooling, per-app identity), validates the answers,
then generates a real, compiling app via XcodeGen/Tuist — **no manual Xcode
step, ever**. It's idempotent: re-running it on an initialized project shows
what's already recorded and never silently regenerates or deletes anything.

Full walkthrough: [`docs/ONBOARDING.md`](docs/ONBOARDING.md).

## What's in here

```
.claude/skills/    — /start plus 9 routine-work Skills (new-feature, add-module,
                      translate, ...)
Scripts/           — lint, string/color enforcement, codegen, and four
                      fully-authored file-template sets (see Architecture below)
docs/              — this template's own docs + the .template sources /start renders
.swiftlint.yml      — one root lint config, every tier
.githooks/{pre-commit,commit-msg}
CLAUDE.md.template  — renders into a real project's CLAUDE.md
```

## Topology tiers

| | T1 | T2 *(default)* | T3 |
|---|---|---|---|
| Shape | single `.xcodeproj` | project + local Swift packages | workspace + N projects |
| Good for | prototypes, <10 screens | one shipping app of any size | two apps sharing a spine, or a shipped framework |

Moving up a tier later is a bounded, scripted migration (spec edit + regenerate,
never `pbxproj` surgery) — see `docs/ONBOARDING.md` for the honest cost table,
including the one migration that reliably costs more than it looks: turning an
existing single-target app into something a second app can import.

## Architecture

`docs/ai/architecture.md.template` is a generic reference covering MVC, MVVM,
VIP (Clean Swift), VIPER, and MV (SwiftUI-native) — `/start` renders it into a
real project's `docs/ai/architecture.md` showing **only** the one pattern
actually chosen. Four combinations are fully template-backed today:

- **MVVM + SwiftUI + `NavigationStack`** (`mvvm-swiftui-navigationstack/`) — the default. ViewModel depends on the Repository's protocol directly — no `UseCase` layer (see `docs/CODING_STANDARDS.md`'s §8.2 rules for why).
- **VIP + SwiftUI + `NavigationStack`** (`vip-swiftui-navigationstack/`) — classic Clean Swift with a thin `@Observable` ViewModel bridge, since a SwiftUI `View` can't hold a `weak` Presenter reference the way a `UIViewController` can.
- **VIP + UIKit + Coordinator** (`vip-uikit-coordinator/`) — classic Clean Swift, ViewController conforms to `DisplayLogic` directly.
- **MVC + UIKit + Coordinator** (`mvc-uikit-coordinator/`) — deliberately one file per feature, making MVC's "Massive View Controller" risk honest rather than hidden.

VIPER is deliberately template-assisted only — it's close enough to VIP (drops the `weak` reference, gives Router full navigation ownership) that a dedicated template would be near-duplicate effort. Every other combination still gets deterministic folder/DI/navigation/test scaffolding from `/new-feature`, but the layer file bodies fall back to the agent writing them from the rendered architecture doc.

## Known limitations

Carried over honestly rather than hidden:

- The four fully-deterministic combos above are all T1/T2 shape; T3 placement
  for any of them is best-effort. Everything else (MVC+SwiftUI, MV, VIPER, or
  any architecture on its non-default navigation approach) is template-assisted.
- `/start`'s idempotent conflict-handling is agent judgment, not a byte-for-byte
  diff check.
- No hardcoded-*string* enforcement script (colors have one; strings don't —
  a blanket regex would false-positive too heavily on legitimate literals).
- No CI pipeline, no image-caching library choice (`AsyncImage` is the
  default — see `docs/ai/ui_rules.md`), no pagination convention — confirmed
  as deliberate scope, not oversights.
- Per-module localization and the base/app theme split are correctness
  requirements with no compile-time guard — `check_strings.sh` catches key
  parity, nothing catches a wrong-bundle lookup at runtime.
- Generated `.xcodeproj`/`.xcworkspace` files are **committed**, not
  gitignored (see `docs/ONBOARDING.md`).
- Xcode's own localization agent writes String Catalogs (`.xcstrings`);
  `/translate` and `check_strings.sh` operate on per-module
  `Localizable.strings`. Nothing detects a project using both — parity passes
  while a locale is actually incomplete. Pick one (build spec §5.1).
- Agent permissions granted inside Xcode (Intelligence ▸ Agents ▸ Permissions)
  are global to the Mac and apply to every project. Nothing in this template
  can scope, version or audit them.

Resolved since the initial build (Objective-C support dropped entirely,
`/translate` Skill added, commit-msg format now hook-enforced, DI-container
upgrade path documented, `docs/PROJECT_MAP.md` now seeded by `/start` instead of
first appearing when another Skill appends to it) — see the build spec's §10 for
the full history.

Full list: `docs/ONBOARDING.md` and the build spec this template was generated
from.
