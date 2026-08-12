# Onboarding — using this template

This repo is a **template**, not an app. It contains Skills, scripts, doc
templates, and lint config — no Xcode project, no architecture decision, no
`ios-skeleton.config.json`. Those are all Phase B, produced by running `/start`
inside Claude Code against a real project.

## The three ways to start a real project from this template

```bash
# Path 1 — clone the template as the new project's root
git clone <template-repo-url> MyNewApp && cd MyNewApp
/start

# Path 2 — copy the template's files into an existing/empty folder
cp -r ios-ai-skeleton/{.claude,Scripts,docs,.swiftlint.yml,.githooks,CLAUDE.md.template,README.md} MyExistingFolder/
cd MyExistingFolder
/start

# Path 3 — adopt into an existing multi-project workspace
cp -r ios-ai-skeleton/{.claude,Scripts,docs,.githooks} ExistingWorkspaceRepo/
cd ExistingWorkspaceRepo
/start   # detects the existing .xcworkspace/.xcodeproj, records the topology,
         # generates only what's missing, never rewrites a hand-maintained project
```

## What `/start` actually does

Asks a one-time, batched Setup Questionnaire (topology, language, UI framework,
persistence, architecture pattern, navigation, networking, minimum iOS version,
DI style, testing framework, tooling, and per-app identity), validates the
combination, then generates a real, compiling app from scratch via
XcodeGen/Tuist — **no manual Xcode step, ever**. It also renders this
template's `.template` doc files into the new project's real
`CLAUDE.md`/`docs/ai/architecture.md`/`docs/ai/modularization.md`, with the
chosen decisions locked in and every placeholder resolved.

`/start` is **idempotent** — re-running it on an already-initialized project
shows the recorded answers first, never silently regenerates or deletes
anything already built, and refuses to apply a topology or architecture change
as a side effect of a re-run (that's a deliberate migration, not an answer
edit — see the cost table below).

## Topology tiers, and the honest cost of moving between them

| | T1 — single project | T2 — project + packages *(default)* | T3 — workspace + N projects |
|---|---|---|---|
| Good for | prototypes, <10 screens | one shipping app of any size | two apps sharing a spine, or a framework you ship to others |
| Compile-time layering | none | real | real, plus independent versioning |

Moving up a tier is bounded and scripted — an edit to a text spec plus a
regenerate, never `pbxproj` surgery. Moving up *after* two years of
app-coupled code (adding a second app late) is the expensive path: an
access-control pass across every type the new consumer touches, plus bundle
lookups that fail at runtime rather than build time. See
`docs/ai/modularization.md`'s rendered module graph for this repo's actual
shape once `/start` has run — the full cost breakdown lives in the spec this
template was built from.

## Where the architecture reference lives

`docs/ai/architecture.md.template` is a generic, multi-pattern reference — it
does not describe a real app yet. `/start` renders it into a real
`docs/ai/architecture.md` that shows **only** the one pattern your project
chose; until then, this file intentionally shows all of them.

## Known limitations (carried over honestly, not hidden)

- Only MVVM + SwiftUI + `NavigationStack` + SwiftData is fully template-backed
  today; every other combination is template-assisted (folder/DI/nav/test
  scaffolding is still deterministic, but layer file bodies fall back to the
  agent writing them from `docs/ai/architecture.md`'s description).
- No CI pipeline, no localization-authoring Skill, no hardcoded-string
  enforcement script, no image-caching library choice, no pagination
  convention — these are documented gaps, not oversights. See the template
  repo's own `README.md` for the full list.
