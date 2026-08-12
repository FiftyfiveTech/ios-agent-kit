# iOS AI-Optimized Skeleton

A reusable **template repository** for iOS projects built to be worked on by an
AI coding agent (Claude Code, Codex, etc.) — deterministic scaffolding,
auto-loaded meta-files, enforced lint/style, and Skills for routine work.

This repo describes **the template system itself**, not any one app. There is no
Xcode project here, no architecture decision, no `ios-skeleton.config.json` —
those all belong to a real project generated *from* this template, via `/start`.

## Quick start

```bash
# Path 1 — clone the template as a new project's root
git clone <template-repo-url> MyNewApp && cd MyNewApp
/start

# Path 2 — copy the template's files into an existing/empty folder
cp -r ios-ai-skeleton/{.claude,Scripts,docs,.swiftlint.yml,.githooks,CLAUDE.md.template,README.md} MyExistingFolder/
cd MyExistingFolder && /start

# Path 3 — adopt into an existing multi-project workspace
cp -r ios-ai-skeleton/{.claude,Scripts,docs,.githooks} ExistingWorkspaceRepo/
cd ExistingWorkspaceRepo && /start
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
.claude/skills/    — /start plus 8 routine-work Skills (new-feature, add-module, ...)
Scripts/           — lint, string/color enforcement, codegen, and the one
                      fully-authored file-template set (MVVM+SwiftUI+NavigationStack)
docs/              — this template's own docs + the .template sources /start renders
.swiftlint.yml      — one root lint config, every tier
.githooks/pre-commit
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
actually chosen. Only **MVVM + SwiftUI + `NavigationStack` + SwiftData** is
fully template-backed today (`Scripts/templates/mvvm-swiftui-navigationstack/`)
— every other combination still gets deterministic folder/DI/navigation/test
scaffolding from `/new-feature`, but the layer file bodies fall back to the
agent writing them from the rendered architecture doc.

## Known limitations

Carried over honestly rather than hidden:

- Objective-C interop scope (Q2) is undefined until a team decides and documents
  it — full parity scaffolding vs. bridging-header support only.
- Only the MVVM/SwiftUI/NavigationStack/SwiftData combo is fully deterministic,
  and only at T1/T2 shape; T3 placement for it is best-effort.
- `/start`'s idempotent conflict-handling is agent judgment, not a byte-for-byte
  diff check.
- No localization-authoring Skill (a shared localization *utility* exists, but
  nothing drafts a second-language `.strings` file yet).
- No hardcoded-*string* enforcement script (colors have one; strings don't —
  a blanket regex would false-positive too heavily on legitimate literals).
- No CI pipeline, no image-caching library choice, no pagination convention, no
  commit-msg format enforcement.
- Per-module localization and the base/app theme split are correctness
  requirements with no compile-time guard — `check_strings.sh` catches key
  parity, nothing catches a wrong-bundle lookup at runtime.

Full list: `docs/ONBOARDING.md` and the build spec this template was generated
from.
