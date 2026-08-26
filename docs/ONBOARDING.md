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

## Which model runs which Skill

Each `SKILL.md` declares its model in frontmatter, so you don't have to remember
to switch:

- **Pinned to `model: opus`, `effort: high`** — `/start`, `/new-feature`,
  `/add-module`, `/add-app`. Irreversible or cross-cutting work; `/start` in
  particular writes the config every other Skill reads. A pinned model replaces
  your session model for that run, so `/model sonnet` then `/start` still runs
  on Opus. That's deliberate.
- **`model: inherit`** — `/add-assets`, `/update-app-icon`, `/add-permission`,
  `/update-theme`, `/status`, `/translate`, `/add-secret`. These follow whatever
  `/model` is set to, so you pick per session.

To change either group, edit the frontmatter in your project's own
`.claude/skills/<name>/SKILL.md` — `/start` copied those files in, and nothing
else reads the keys. There is no per-invocation flag. A project scaffolded
before these keys existed won't gain them on a `/start` re-run: the copy is
merge-only and leaves an existing `SKILL.md` alone, so add them by hand.

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
`API_BASE_URL` reaches the app through `Info.plist` — `AppEnvironment` reads it
and the composition root passes the `URL` into `RequestBuilder`. A `Service` never holds a
literal URL. Anything compiled into the binary is extractable from the IPA, so
genuinely sensitive material stays server-side.

Every key is read in one place: `AppEnvironment`, in the shared Core module.
Nothing else in the app touches `Bundle.main` for configuration — the composition
root asks `AppEnvironment.current.apiBaseURL` and hands the result to
`RequestBuilder`. Add further keys with **`/add-secret KEY=value`** rather than by
hand: it writes
both files, adds the `$(KEY)` entry to each app target's `Info.plist` (without
which Swift cannot see the value at all), and exposes it as a typed accessor on
`AppEnvironment` in the shared module — the one place the app reads
configuration. **Do not paste a real credential into the prompt.** The Skill is
driven by an AI agent, so the value would live in that transcript and its logs
long after you rotate the key; `Scripts/add_secret.sh` detects credential-shaped
values, declares the key commented out in both files, and leaves you to paste
the value into the gitignored `Secrets.xcconfig` yourself.

Full rules, plus where data
belongs (`UserDefaults` vs. the local store vs. Keychain), concurrency, ARC and
struct-vs-class: `docs/CODING_STANDARDS.md`.

## When to run `xcodegen generate`

The `.xcodeproj` is generated from `project.yml` and **committed** (see below),
which means the file list Xcode builds from is a snapshot of the disk at the
moment it was generated. That snapshot goes stale quietly: a file that exists on
disk but isn't in it is never compiled, and nothing reports an error — the symbol
just isn't there.

**Regenerate whenever the set of files or folders changed, or the spec did.**

| Run `xcodegen generate` after | No need after |
|---|---|
| Adding, deleting, renaming or moving a source file | Editing an existing source file |
| Adding a folder — a new `Features/<Name>/`, a new layer directory | Adding an entry inside a file that's already referenced |
| A module's **first** `Localization/Localizable.xcstrings` | Adding a key, a translation, or a whole **locale** to an existing String Catalog |
| A target's **first** `Assets.xcassets` | Adding an image set, color set or icon inside an existing catalog |
| Any edit to `project.yml` — new target, dependency, build setting, `Info.plist` key | Editing `Secrets.xcconfig` (xcconfig is read at build time) |
| Adding or removing a package dependency | |

(Tuist projects: same rule, `tuist generate`, `Project.swift` in place of
`project.yml`.)

Two things worth knowing, because both catch people out:

- **A new language used to need this and no longer does.** With the older
  per-locale `de.lproj/Localizable.strings` layout, adding a language created a
  new folder and a new file — squarely in the left column, so the app would build
  and silently ship without the language until someone regenerated. This template
  uses one String Catalog per module instead, so a new locale is an edit to a file
  that already exists and the next build picks it up. XcodeGen also reads the
  catalog to fill in the project's `knownRegions`, so the language list stays
  correct on the next regenerate without anyone maintaining it by hand. (The
  build ships a locale even before that regenerate — `knownRegions` is the Xcode
  project's own record, not what the compiler reads.)
- **Don't edit project settings in Xcode's inspector.** They live in `project.yml`;
  the next regenerate overwrites anything set in the UI. Adding a *file* in Xcode
  is fine — Xcode writes it into the project immediately, and because XcodeGen
  globs directories the next regenerate finds it on disk anyway.

The Skills regenerate for you whenever they add a file, so this is mainly a rule
for hand-editing. When unsure, just run it: it's idempotent and takes about a
second. The `pbxproj` diff it produces belongs in the same commit as the change
that caused it.

## Localization

Each resource-owning module owns exactly one String Catalog —
`<module>/Localization/Localizable.xcstrings` — holding every locale for that
module, plus a generated `L10n.swift` beside it.

- **Add or edit strings** in the catalog (Xcode's String Catalog editor, or by
  hand — it's JSON), then run `Scripts/generate_strings.sh <module>` to refresh
  the typed `L10n` accessor. Views reference `L10n.home.title`, never a raw key
  and never a literal.
- **Add a language** with `/translate <locale-code>`, which drafts every missing
  entry and marks it `needs_review` — the catalog's own review state, which
  Xcode's editor shows directly. Review before shipping the locale. You can also
  add a language in Xcode; the two write the same file and don't fight.
- **Check health** with `Scripts/check_strings.sh` (also in the pre-commit hook):
  it fails on a key missing or still `new` in any locale, and on the same key
  owned by two modules. Outstanding `needs_review` entries are reported, not
  failed.
- **Why one catalog per module, not one per repo:** `NSLocalizedString` resolves
  against a *bundle*. A shared framework that ships UI must carry its own strings
  or they silently fall back to the raw key inside the consuming app. That's why
  the generated `L10n` resolves through its own module's bundle and never
  `Bundle.main`.
- **Migrating an adopted project** off per-locale `.strings`:
  `Scripts/migrate_strings_to_catalog.sh [<module>]` folds them into a catalog,
  keeps existing translations and comments, regenerates `L10n.swift`, and removes
  the old git-tracked files. Run `xcodegen generate` afterwards — the set of files
  on disk changed. Until you migrate, `check_strings.sh` warns and skips that
  module; it does not block commits. **Don't keep both formats**, though — that
  one *does* fail, because the check only sees the catalog and parity would pass
  while half your strings are invisible to it.

## UIKit screens are laid out in code

No Skill generates a storyboard or a XIB, and no generated UIKit screen uses one
— view hierarchies and constraints are built in the ViewController, the app is
launched programmatically from `SceneDelegate`, and the launch screen is the
`UILaunchScreen` Info.plist dictionary rather than a storyboard file.

This was a considered call, not an oversight: storyboards are rewritten by Xcode
on open (so they diff and conflict without anyone changing the design), keyed by
opaque generated identifiers (so a merge conflict is unreadable and an agent has
nothing stable to edit against), and wire `@IBOutlet`/`@IBAction` connections that
fail at runtime rather than at build time — which is the exact failure mode this
template's typed color tokens and generated `L10n` exist to eliminate.

Nothing stops you adding Interface Builder files for screens you write by hand;
they're picked up on the next regenerate. Just expect to maintain those yourself
rather than through a Skill.

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
- Shared views are a review gate, not a tooled one: nothing detects a feature
  that quietly reimplements a component `DesignSystem/Views/` already has,
  the way `check_hardcoded_colors.sh` detects a raw color.
