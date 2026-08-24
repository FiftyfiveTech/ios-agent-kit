# Onboarding — using this template

This repo is a **template**, not an app. It contains Skills, scripts, doc
templates, and lint config — no Xcode project, no architecture decision, no
`ios-skeleton.config.json`. Those are all Phase B, produced by running `/start`
inside Claude Code against a real project.

## Starting a real project from this template

`/start` takes one optional argument, a target path, and does its own file
copying — there's no manual `cp -r` step:

```bash
/start [path]
```

- **No path** — clone the template as the new project's root, then run
  `/start` from inside it:
  ```bash
  git clone <template-repo-url> MyNewApp && cd MyNewApp
  /start
  ```
- **A path** — run `/start <path>` from anywhere (e.g. from inside this
  template repo), and it resolves the path, copies its own files in, and
  scaffolds from there. It inspects what's at that path and picks the right
  scenario automatically:
  ```bash
  /start MyNewApp             # missing or empty → fresh start
  /start ~/Code/ExistingApp   # a mature single .xcodeproj → adoption
  /start ~/Code/Workspace     # an existing .xcworkspace + N projects → adoption
  ```
  Adoption detects the existing `.xcodeproj`(s)/`.xcworkspace`, infers the
  topology tier from what's there (a bare project vs. one with local packages
  vs. a workspace), records it, and generates only what's missing — it never
  rewrites a hand-maintained project, and the copy step never overwrites a
  file already at the destination (so an adopted project's own `CLAUDE.md`,
  `README.md`, and `docs/` are safe).

## What `/start` actually does

Asks a one-time, batched Setup Questionnaire (topology, language, UI framework,
persistence, architecture pattern, navigation, networking, minimum iOS version,
DI style, testing framework, tooling, and per-app identity), validates the
combination, then generates a real, compiling app from scratch via
XcodeGen/Tuist — **no manual Xcode step, ever**. It also renders this
template's `.template` doc files into the new project's real
`CLAUDE.md`/`docs/ai/architecture.md`/`docs/ai/modularization.md`, with the
chosen decisions locked in and every placeholder resolved.

Two files land in `Core` on the way through, regardless of the architecture
combo: `Logging/Log.swift` always (a `Logging` protocol over `OSLog` — the thing
`docs/CODING_STANDARDS.md`'s no-`print()` rule and SwiftLint's
`no_print_statements` actually point at), and `Persistence/PersistenceController.swift`
only when the persistence answer isn't `None`.

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

## Where your requirements go: `docs/product/`

This template describes **how** the app is built. It says nothing about **what**
it's for — that's `docs/product/`, and it's the one folder here that nothing
generates, renders or overwrites.

Put the PRD, SRS, API contracts and anything else domain-specific there as they
arrive. They're expected to keep changing: a PRD rewritten mid-sprint, an SRS
that grows a section after sign-off, an endpoint that changes shape twice before
launch is the normal case, not a problem to fix first. Three rules follow:

- **`CLAUDE.md` points at the folder and never summarizes it.** A digest of a
  living document is stale within weeks and reads as current.
- **Agents re-read the file per task**, not from memory. `/new-feature` checks
  there for the screen's fields, types, states and endpoint before proposing
  anything, and tells you which document it used — or that it found none.
- **Incomplete is fine; contradictory gets a question.** Where a needed
  requirement is missing or self-contradicting, the agent asks rather than
  inventing one, and the answer belongs back in `docs/product/`.

Traceability stays deliberately light: note the requirement a feature came from
in its commit message or `docs/PROJECT_MAP.md`. There's no generated
requirement-to-code matrix, because keeping one accurate by hand is work nobody
does twice.

## Local persistence: what the Q4 answer actually changes

`None` means every generated feature is remote-only — one dependency, one
protocol, one fake in its test. That's a complete answer for an app that's a view
onto a server.

`SwiftData`/`Core Data` means each feature *additionally* gets a
`<Name>LocalStore` beside its remote dependency, behind a protocol the consuming
layer owns (Repository for MVVM, Worker for VIP, Service for MVC), plus one
`PersistenceController` injected from the composition root. SwiftData also gets a
`@Model` record in `Models/`, registered with the container schema automatically.
Core Data gets the same wiring but leaves the store's two methods as
`TODO(agent)` stubs — its entity lives in a `.xcdatamodeld` that can't be
generated from text, so `/start` writes that follow-up to `TODO.md`.

The generated policy is cache-on-success, read-on-failure, replace-the-whole-list.
Correct for a whole-list fetch; a feature that pages, syncs deltas or edits
locally rewrites that one method.

Changing this answer later only affects features generated after the change —
existing ones keep whatever they were built with, which is why `/start` treats a
Q4 switch as a conflict to confirm rather than an edit to apply.

## Where the architecture reference lives

`docs/ai/architecture.md.template` is a generic, multi-pattern reference — it
does not describe a real app yet. `/start` renders it into a real
`docs/ai/architecture.md` that shows **only** the one pattern your project
chose; until then, this file intentionally shows all of them.

## Configuration and secrets

**On a fresh clone, copy `Secrets.xcconfig.example` to `Secrets.xcconfig` and
fill it in before the first build** — the file is gitignored, so it isn't in
your clone. On a networked project the app deliberately crashes at launch with a
message saying so, rather than falling back to a wrong URL. An offline project
(`networking: none` in the config) has no `API_BASE_URL` and no such check — its
composition root never had a `RequestBuilder` rendered into it.

Filling it in "somehow" isn't enough, and two mistakes are common enough to name:

- **Leaving a key blank.** `$(API_BASE_URL)` expands to an empty string, so a
  blank key and a missing key are the same thing by the time Swift sees it. The
  app stops at launch and tells you which file to edit.
- **Writing `https://host` unescaped.** `//` starts a comment in xcconfig, so
  that value truncates to `https:` — which is a *parseable* URL with no host.
  Write `https:/$()/host`. The launch check tests for a scheme and a host
  precisely so this fails loudly instead of breaking every request at runtime.
- **Trying to quote your way out of it.** xcconfig has no string literals and no
  escape character, so `"https://host"` truncates identically and leaves a stray
  quote behind. `$()` (or `${}`) is the only thing that works, and it works by
  slipping between xcconfig's parse and expand passes rather than by escaping
  anything — `docs/CODING_STANDARDS.md` has the mechanism and a table of what
  every candidate form actually resolves to.

Run `Scripts/check_secrets.sh` to catch both at commit time rather than in the
simulator. It passes silently when there is no `Secrets.xcconfig` yet (the normal
state of a fresh clone, and of CI jobs that inject configuration from the
environment) and when there is no `API_BASE_URL` to check (an offline project).

`Secrets.xcconfig` (gitignored) holds anything that varies by environment or
must not be committed; `Secrets.xcconfig.example` (committed) is the record of
which keys exist, and adding a key to one without the other is what breaks CI
and new machines. The app target's build configurations include the former, and
`API_BASE_URL` reaches the app through `Info.plist` — the composition root
reads it and passes the `URL` into `RequestBuilder`. A `Service` never holds a
literal URL. Anything compiled into the binary is extractable from the IPA, so
genuinely sensitive material stays server-side. Full rules, plus where data
belongs (`UserDefaults` vs. the local store vs. Keychain), concurrency, ARC and
struct-vs-class: `docs/CODING_STANDARDS.md`.

## Generated `.xcodeproj`s are committed

`/start`, `/add-module`, and `/add-app` regenerate `.xcodeproj`/`.xcworkspace`
files in place, and they're committed to the repo — not gitignored. That
keeps a fresh clone openable without requiring XcodeGen/Tuist just to get to a
build, at the cost of a pbxproj diff on every regenerate. Always gitignored
regardless: `xcuserdata/`, `.DS_Store`, build products, `Secrets.xcconfig` —
see `.gitignore`, which `/start` copies in with those entries already present.

## Known limitations (carried over honestly, not hidden)

- Four combinations are fully template-backed (MVVM+SwiftUI, VIP+SwiftUI,
  VIP+UIKit, MVC+UIKit — see the template repo's own `README.md`), each at
  T1/T2 shape only; every other combination is template-assisted
  (folder/DI/nav/test scaffolding is still deterministic, but layer file
  bodies fall back to the agent writing them from `docs/ai/architecture.md`'s
  description).
- Core Data's per-feature store is wired and compiling but its two methods are
  `TODO(agent)` stubs; SwiftData is generated end to end.
- No auth/session layer (token refresh, Keychain, 401 retry), no deep-link →
  `Route` mapping, no UI/snapshot test tier — unaddressed so far.
- No CI pipeline, no hardcoded-string enforcement script, no pagination
  convention — these are documented gaps, not oversights. See the template
  repo's own `README.md` for the full list.
