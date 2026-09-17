# Onboarding — using this template

This repo is a **template**, not an app. It holds Skills, scripts, doc templates
and lint config — no Xcode project, no architecture decision, no
`ios-skeleton.config.json`. All of that appears when you run `/start` inside
Claude Code against a real project.

## Start here

1. `brew install xcodegen swiftlint jq` (or `tuist` instead of `xcodegen`), plus
   Xcode 16 or newer.
2. `git clone <template-repo-url> MyNewApp && cd MyNewApp`
3. Run `/start` in Claude Code.
4. Answer the eleven setup questions — or say **"use the recommended defaults"**
   and just give it an app name and bundle ID.
5. Put your API base URL in `Secrets.xcconfig`, written as `https:/$()/host`
   (see [Configuration and secrets](#configuration-and-secrets) — the plain form
   breaks).
6. Open the generated `.xcodeproj`/`.xcworkspace` and hit Run.

The template's own `README.md` has the same six steps with the commands spelled
out. The rest of this file is what to know once you're past them.

## `/start [path]`

`/start` copies its own files in — there is no manual `cp -r` step. It takes one
optional argument:

- **No path** — the target is the current folder. Clone the template as the new
  project's root, then run `/start` from inside it.
- **A path** — run `/start <path>` from anywhere. It resolves the path, copies
  the template's files in, and picks the right scenario from what it finds:

```bash
/start MyNewApp             # missing or empty → fresh start
/start ~/Code/ExistingApp   # an app that already exists → adoption
/start ~/Code/Workspace     # an .xcworkspace + N projects → adoption
```

**Adoption is not workspace-only.** One mature `.xcodeproj` with years of history
and its own `CLAUDE.md`/`README.md` is exactly what it's for. `/start` detects the
existing project(s), infers the topology tier, and generates only what's missing.
It never rewrites a hand-maintained project, and never overwrites a file already
at the destination — your `CLAUDE.md`, `README.md` and `docs/` are safe.

## What `/start` does

It always asks the Setup Questionnaire first — topology, UI framework,
persistence, architecture, navigation, networking, minimum iOS version, DI,
testing framework, tooling, app identity — with a recommended default shown
beside every question. It checks the answers as a set (some combinations
contradict each other), then generates a real, compiling app via XcodeGen/Tuist.
**There is no manual Xcode step, ever.**

It then renders your project's real `CLAUDE.md`, `docs/ai/architecture.md` and
`docs/ai/modularization.md` with those decisions locked in, and drops
`Core/Logging/Log.swift` in (the thing the no-`print()` rule points at), plus
`Core/Persistence/PersistenceController.swift` unless persistence is `None`.

`/start` is **idempotent**. Re-running it on an initialized project shows the
recorded answers, recreates anything missing, and never silently regenerates or
deletes what's already built. It refuses to change topology or architecture as a
side effect of a re-run — those are deliberate migrations, not answer edits.

Which model each Skill runs on is declared in its own frontmatter, so you don't
have to switch by hand — see the template `README.md`'s *Model tiers* table.

## Topology tiers, and the honest cost of moving between them

| | T1 — single project | T2 — project + packages *(default)* | T3 — workspace + N projects |
|---|---|---|---|
| Good for | prototypes, <10 screens | one shipping app of any size | two apps sharing a spine, or a framework you ship |
| Compile-time layering | none | real | real, plus independent versioning |

Moving up a tier is bounded and scripted — an edit to a text spec plus a
regenerate, never `pbxproj` surgery. The expensive path is adding a second app
*after* two years of app-coupled code: an access-control pass over every type the
new consumer touches, plus bundle lookups that fail at runtime rather than at
build time. Once `/start` has run, `docs/ai/modularization.md` shows your real
module graph.

## Where your requirements go: `docs/product/`

This template describes **how** the app is built, never **what** it's for. That's
`docs/product/` — the one folder here that nothing generates, renders or
overwrites. Put the PRD, SRS and API contracts there as they arrive, and keep
changing them; incomplete and mid-rewrite is the normal state.

- `CLAUDE.md` points at the folder and never summarizes it — a digest of a living
  document is stale within weeks and reads as current.
- `/new-feature` re-reads the relevant file at the start of each run and tells you
  which document it used, or that it found none.
- Where a requirement is missing or contradicts itself, the agent asks instead of
  inventing one, and the answer belongs back in `docs/product/`.

Traceability stays light on purpose: note the requirement in the commit message
or `docs/PROJECT_MAP.md`. There's no generated requirement-to-code matrix — nobody
keeps one accurate twice.

## What the persistence answer (Q4) changes

`None` means every generated feature is remote-only — a complete answer for an app
that's a view onto a server. `SwiftData`/`Core Data` gives each feature a
`<Name>LocalStore` beside its remote dependency, plus one `PersistenceController`
injected from the composition root. SwiftData is generated end to end; Core Data
is wired and compiling with `TODO(agent)` bodies, because its entity lives in a
`.xcdatamodeld` that can't be generated from text.

The generated policy is cache-on-success, read-on-failure, replace-the-whole-list
— right for a whole-list fetch; a feature that pages or syncs deltas rewrites that
one method. Changing the answer later only affects features generated after it,
which is why `/start` treats the switch as a conflict to confirm.

## Where the architecture reference lives

`docs/ai/architecture.md.template` is a generic, multi-pattern reference — it does
not describe a real app. `/start` renders it into `docs/ai/architecture.md`
showing **only** the pattern your project chose. Until then it intentionally shows
all of them.

## Configuration and secrets

`Secrets.xcconfig` (gitignored) holds anything that varies by environment or must
not be committed. `Secrets.xcconfig.example` (committed) is the record of which
keys exist — adding a key to one and not the other is what breaks CI and new
machines.

**On a fresh clone of a project, copy `Secrets.xcconfig.example` to
`Secrets.xcconfig` and fill it in before the first build.** A networked app
deliberately crashes at launch with a message saying so, rather than falling back
to a wrong URL. (An offline project — `networking: none` — has no `API_BASE_URL`
and no such check.)

Two mistakes are common enough to name:

- **Leaving a key blank.** `$(API_BASE_URL)` expands to an empty string, so blank
  and missing are the same thing by the time Swift sees it. The app stops at
  launch and names the file to edit.
- **Writing `https://host` unescaped.** `//` starts a comment in xcconfig, so the
  value truncates to `https:` — a parseable URL with no host. Write
  `https:/$()/host`. Quoting does not help: xcconfig has no string literals and no
  escape character, so `"https://host"` truncates identically and leaves a stray
  quote. `$()` is the only form that works. `docs/CODING_STANDARDS.md` has the
  mechanism and a table of what every candidate resolves to.

Run `Scripts/check_secrets.sh` to catch both at commit time instead of in the
simulator. It passes silently when there's no `Secrets.xcconfig` yet (a fresh
clone, or CI injecting from the environment) and when there's no `API_BASE_URL`
to check.

Add further keys with **`/add-secret KEY=value`**, never by hand — it writes both
files, adds the `$(KEY)` entry to each app's `Info.plist` (without which Swift
can't see the value at all), and exposes a typed accessor on `AppEnvironment`, the
one place in the app that reads configuration. **Don't paste a real credential
into the prompt**: it would live in the agent transcript long after you rotate the
key, so the script comments the key out in both files and leaves you to paste the
value into the gitignored one yourself. Anything compiled into the binary is
extractable from the IPA anyway — genuinely sensitive material stays server-side.

## When to run `xcodegen generate`

The `.xcodeproj` is generated from `project.yml` and committed, so its file list
is a snapshot of the disk from the last generate. It goes stale quietly: a file on
disk that isn't in it is never compiled, and nothing reports an error — the symbol
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

(Tuist: same rule, `tuist generate`, `Project.swift` in place of `project.yml`.)

**Don't edit project settings in Xcode's inspector** — they live in `project.yml`
and the next regenerate overwrites them. Adding a *file* in Xcode is fine. The
Skills regenerate for you whenever they add a file, so this is mainly a rule for
hand-editing; when unsure, just run it — it's idempotent, takes a second, and its
`pbxproj` diff belongs in the same commit as the change that caused it.

## Localization

Each resource-owning module owns exactly one String Catalog —
`<module>/Localization/Localizable.xcstrings` — holding every locale for that
module, plus a generated `L10n.swift` beside it.

- **Add or edit strings** in the catalog (Xcode's editor, or by hand — it's JSON),
  then run `Scripts/generate_strings.sh <module>`. Views reference
  `L10n.home.title`, never a raw key and never a literal.
- **Add a language** with `/translate <locale-code>`. It drafts every missing entry
  as `needs_review`, which Xcode's editor shows directly — review before shipping
  the locale. Adding a language in Xcode works too; both write the same file.
- **Check health** with `Scripts/check_strings.sh` (also in the pre-commit hook):
  it fails on a key missing or still `new` in any locale, and on the same key owned
  by two modules. `needs_review` entries are reported, not failed.
- **One catalog per module, not one per repo**, because `NSLocalizedString`
  resolves against a *bundle*. A shared framework that ships UI must carry its own
  strings or they fall back to the raw key inside the consuming app — which is why
  the generated `L10n` resolves through its own module's bundle and never
  `Bundle.main`.
- **Adopting a project** still on per-locale `.strings`:
  `Scripts/migrate_strings_to_catalog.sh [<module>]` folds them into a catalog,
  keeping translations and comments — then run `xcodegen generate`. Until you
  migrate, `check_strings.sh` warns and skips that module. **Don't keep both
  formats**: that one does fail, because the check sees only the catalog and
  parity would pass while half your strings are invisible to it.

## Two things that are decisions, not gaps

- **UIKit screens are laid out in code.** No Skill generates a storyboard or XIB.
  Storyboards are rewritten by Xcode on open, keyed by opaque identifiers an agent
  can't edit against, and wire connections that fail at runtime instead of at
  build time. Add Interface Builder files by hand if you want them; expect to
  maintain those yourself.
- **Generated `.xcodeproj`/`.xcworkspace` files are committed**, not gitignored —
  a fresh clone opens and builds without installing XcodeGen first, at the cost of
  a pbxproj diff on every regenerate. Always gitignored regardless: `xcuserdata/`,
  `.DS_Store`, build products, `Secrets.xcconfig`.

## Known limitations

Carried over honestly rather than hidden — the full list lives in the template
repo's own `README.md`. The short version: four architecture combinations are
fully template-backed (MVVM+SwiftUI, VIP+SwiftUI, VIP+UIKit, MVC+UIKit) at T1/T2
shape and everything else is template-assisted; Core Data's per-feature store is a
wired seam with `TODO(agent)` bodies; there's no auth/session layer, no deep-link
mapping, no UI/snapshot test tier, no CI pipeline and no hardcoded-string check;
and the shared-views rule is a review gate, not a tooled one.
