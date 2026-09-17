---
name: new-feature
description: Generate a new feature end to end — layer files, shared Models entry, navigation registration, and a real passing unit test against a fake dependency. Use for "/new-feature <Name> [field:Type,...]" or plain English like "add a screen for X". Confirms field types, folder grouping and target module with the developer before generating anything, rather than inferring them.
model: opus
effort: high
---

# /new-feature `[--module <M>] <Name>[/<Group/Path>] ["field:Type,field2:Type2,..."]`

## Precondition

Check for `ios-skeleton.config.json` at repo root before doing anything else.
Missing → refuse: *"This project hasn't been initialized yet — run `/start`
first."* Never guess an architecture or a "reasonable default."

## Invoking it in plain English

Both forms are supported and end up in the same place — the script only ever
receives the argument form, so prose is something **you** translate:

| What the developer types | What you must end up running |
|---|---|
| `/new-feature Films "title:String,year:Int"` | `Scripts/new_feature.sh Films "title:String,year:Int"` |
| *"add a films list screen showing the title and release year"* | the same command — after confirming the two field types |
| *"add a profile screen under the account section"* | `Scripts/new_feature.sh Account/Profile "…"` — after confirming the grouping |
| *"add a settings screen to the Shared module"* | `Scripts/new_feature.sh --module Shared Settings "…"` |
| *"add an empty Onboarding screen for now"* | `Scripts/new_feature.sh Onboarding` — no field list is legal (see below) |

The translation step is where information gets **invented**: an English noun
carries no Swift type, "under the account section" may or may not mean a
nested folder, and a project with more than one module has no obvious
destination. Never resolve any of that silently.

## Before the questions: read the requirement

Look in `docs/product/` for the PRD/SRS/API document covering the screen being
asked for, and read the relevant part **now, from the file**, not from memory or
from anything summarized in `CLAUDE.md`. These documents change constantly; the
version on disk today is the only one that counts.

What it changes:

- **Fields and types** come from the requirement when it states them. A spec'd
  field list beats an inferred one every time, and it turns question 3 below from
  an invention into a confirmation.
- **Behaviour** — validation, error and empty states, whether the list pages —
  comes from there too, and is what you implement after the script runs.
- **The endpoint** the feature's Service/Worker should call, if the document
  names one; otherwise the generated placeholder path stays and goes to
  `TODO.md`.

If `docs/product/` is empty or the screen isn't described there yet, that's
normal and not a blocker — proceed on the developer's description and say plainly
that you found no requirement for it. If a requirement exists but is ambiguous or
self-contradicting, ask rather than picking a reading; the answer belongs back in
`docs/product/`, not only in this conversation.

When you echo the resolved command, say which document you drew from (or that
there wasn't one).

## Confirm before generating — the three questions

Ask them in **one batched interaction**, not one per turn. Skip any question the
invocation already answered explicitly — a fully-specified
`/new-feature Films "title:String,year:Int"` on a single-app project needs none
of them. Do not run the script until the unanswered ones are settled.

This is not ceremony: none of the three is cheap to undo. Models are written to
the shared `Models/` location, where a colliding type name makes the script stop
rather than overwrite; the script refuses outright if the feature folder already
exists; and a feature generated into the wrong module has to be moved by hand
along with its strings and its access modifiers.

Ask them in this order — module first, because the feature directory doesn't
exist at a fixed path until the module is settled, and the grouping question
needs to look inside it.

**1. Module — ask whenever more than one candidate exists.**
Resolution order is `--module` → the config's `defaultModule` → the single app
if there is exactly one. Read `ios-skeleton.config.json` and ask *before*
invoking if that leaves more than one candidate — don't let the script's refusal
be the way the developer finds out. The feature directory, its test directory
and its `Localizable.xcstrings` all hang off the resolved module, and generated
keys are namespaced `<module>.<feature>.*`, so this answer decides more than
placement.

> **Known gap — a shared framework as the destination.** The spec contemplates
> it (generated types the app must see then need `public` plus an explicit
> `public init`), but `new_feature.sh`'s path lookup reads the config's `apps`
> list only and falls back to the app path when the name isn't there. If the
> developer picks a module that isn't an app, say so and verify where the files
> actually landed before reporting the feature done.

**2. Grouping — ask whenever the feature could nest.**
Default is flat: `<module>/Features/<Name>/`. Offer the concrete choice
(`Features/Profile/` vs `Features/Account/Profile/`) rather than an open question,
and **propose nesting** whenever any of these holds:

- the request mentions a section, flow or tab — *"under settings"*, *"part of
  onboarding"*;
- the resolved module's feature directory already contains group folders;
- **a feature already exists that the new one plainly belongs to.**
  `Features/Contacts/` is there and the request is `AddContact`, `Favorites` or
  `ContactDetails` — propose `Features/Contacts/AddContact/`, not a fourth folder
  at the top level. A screen folder may be a leaf and a group at once (§3.2), so
  `Contacts/` keeps its own `ContactsView.swift` and gains child folders beside
  it; nothing that already exists has to move;
- the request names several screens of one area at once — propose the parent
  folder once, then generate each child into it.

Pass the nested path straight through — `Scripts/new_feature.sh
Contacts/AddContact "…"` creates `Features/Contacts/AddContact/` and the mirrored
`<Module>Tests/Features/Contacts/AddContact/`, identically for all four templated
architectures.

**Nesting is directories only.** Generated type names, the `Route`/factory
registration and the `Models/<Name>Models.swift` entry all sit in one flat
namespace that the folder path does not scope. Name a child screen uniquely
app-wide — `ContactDetails`, not `Details` — or its models file collides with
another area's.

**3. Fields — ask unless given as explicit `field:Type` pairs, or specified in
`docs/product/`.**
Never infer a Swift type from an English noun. Where the requirement states the
shape, propose exactly that and cite the document — a spec'd `year: Int` is not
something to re-derive. Propose a concrete typed list
derived from what was described and ask for confirmation or correction, e.g.
*"I'll generate `FilmsModel` with `title: String`, `year: Int`, `posterURL: URL`
— correct, or different types?"* Call out the genuinely ambiguous ones rather
than burying them: an "avatar" is `URL`, `String` or `Data` depending on the
API, and an "amount" is `Decimal` or `Double` depending on whether it's money.
If no fields are described at all, say so plainly — omitting them is legal and
produces a property-less `<Name>Model` that compiles, but it is **not** an
inference that the model has no fields, and nothing will fill it in later
automatically.

**Then echo the resolved command and get a go-ahead** before running it — one
line, so what's about to be generated is visible rather than inferred:

```
About to run: Scripts/new_feature.sh --module Shared Account/Profile "name:String,avatarURL:URL"
→ Features/Account/Profile/ in Shared, ProfileModel in Models/, registered on the Route enum, one test.
```

## What this Skill does

Runs `Scripts/new_feature.sh` with the confirmed arguments, then reviews its
output.

```
Scripts/new_feature.sh [--module <M>] <Name>[/<Group/Path>] ["field:Type,..."]
```

The script is fully deterministic for four combinations (§1.4 of the build
spec) — MVVM+SwiftUI+`NavigationStack` (the default), VIP+SwiftUI+`NavigationStack`
(ViewModel bridge, since a SwiftUI `View` can't hold a `weak` reference),
VIP+UIKit+Coordinator (classic Clean Swift), and MVC+UIKit+Coordinator
(deliberately one file, making the pattern's own risk honest). Whichever one
the project's config selects, it generates:

- **The full layer set for that combo** — e.g. MVVM's ViewModel depending on
  the Repository's *protocol* directly (no separate business-logic layer —
  there's nothing to test in a pass-through that adds no business rule; see
  `docs/CODING_STANDARDS.md`), or VIP's View(Controller)/Interactor/Presenter/
  Router/Worker with the Presenter holding a `weak` reference back up. Flat in
  `Features/<Name>/` (or `Features/<Group>/<Name>/`) — no `Presentation/`/
  `Domain/`/`Data/` subfolders.
- **Models**: `Models/<Name>Models.swift` in the shared location — never a
  file inside the feature folder. The script refuses and asks if a field's
  type collides with an existing type already defined in `Models/`.
- **Navigation**: a new screen registered at whichever markers the combo's
  app-shell left — a `Route` case + `destination(for:)`/`make<Name>View()` for
  the SwiftUI combos, or a `make<Name>ViewController()` factory on
  `AppCoordinator` for the UIKit combos — never a second navigation path. If
  part of a tab-bar flow, wires into that tab's own stack only.
- **Localization**: adds `<module>.<feature>.title`/`.empty` to the target
  module's `Localization/Localizable.xcstrings` String Catalog and regenerates
  that module's `L10n.swift` — never a hardcoded string literal. Only the
  source language is written; use `/translate` for the rest.
- **Shared views, not new ones.** The generated screen consumes `LoadingView`,
  `ErrorView` and `EmptyStateView` from `DesignSystem/Views/` — SwiftUI
  views for the SwiftUI combos, `UIView` subclasses for the UIKit ones. If the
  screen needs a component another screen already has, consume it or promote it
  into `DesignSystem/Views/`; never copy a view into the feature folder
  (`docs/ai/ui_rules.md`).
- **Subviews stay in the screen's file.** A subview only this screen uses is a
  `private` view type in the generated screen file — not a file of its own, and
  never a `Views/` subfolder inside the feature. It graduates to its own file in
  the same feature folder once it owns state or its own loading/error, and to its
  own child-screen folder (`/new-feature Home/HomeDetail`) once it is really a
  second screen (`docs/ai/ui_rules.md`). A grouped path whose parent already holds
  a screen is valid — the script's existence guard checks the leaf folder, not the
  group — so `Features/Home/` may carry `HomeView.swift` and a `HomeDetail/` child
  folder side by side, and a group may also hold flow-level files of its own — a
  coordinator, a state object its screens share — beside those folders. Confirm
  the child's name is unique app-wide before generating: every layer type and the `Models/<Name>Models.swift` entry go into
  flat namespaces that nesting does not scope.
- **Documented code, with nothing about the template in it.** Every generated
  type, protocol, property and function carries a `///` doc comment saying what
  it is or does. No generated file mentions the template, a `.template`
  filename, or a spec section number — that rationale lives in
  `docs/ai/architecture.md` (`docs/CODING_STANDARDS.md`).
- **A project regeneration**, because a feature adds files and folders: the
  script runs `xcodegen generate`/`tuist generate` at the end, and the resulting
  `pbxproj` diff belongs in the same commit as the feature.
- **A local store, only when the project's Q4 answer isn't `None`.** With
  SwiftData or Core Data recorded in the config, the script also generates
  `<Name>LocalStore.swift` in the feature folder, declares its protocol beside
  the remote one in the consuming layer (Repository for MVVM, Worker for VIP,
  Service for MVC), appends a SwiftData `<Name>Record` to `Models/`, registers it
  with the app's `ModelContainer` schema, and passes the store into the factory
  it writes at the composition root. With `persistence: None` none of that
  exists and the feature is remote-only — both are complete outcomes.
- **With `networking: none`, the remote half doesn't exist instead.** The store
  becomes the source of truth rather than a fallback, so the script generates
  everything except that one file's body: folder, `Models/`, `<Name>LocalStore`,
  the factory (constructed with `localStore:` and no `requestBuilder`/
  `apiClient`), navigation registration and localization are all still
  deterministic, and the data-layer type arrives as a compiling `TODO(agent)`
  stub that already declares `<Name>LocalStoreProtocol` and conforms to whatever
  protocol the layer above consumes. Its test is a **failing placeholder**, not a
  passing one — the templated read-through tests assert remote-vs-cache semantics
  this feature doesn't have, so generating them would be a green test that proves
  nothing. See "After the script runs" for what you owe here. Core Data
  is the one seam left half-open on purpose: the store compiles and is wired, but
  its two methods are `TODO(agent)` until the entity exists in the app's
  `.xcdatamodeld` (§10).
- **A real, passing unit test** against a fake dependency (not a placeholder),
  plus — when persistence is on — a second test class covering the read-through
  policy itself: remote result cached, cache used when the remote call fails,
  remote error rethrown when the cache is empty.
  Fake values default sensibly by type; an unrecognized/custom type still
  compiles but fails loudly at test runtime via `fatalErrorFakeValue()`.

For any other architecture/UI/navigation combination (MVC+SwiftUI, MV, VIPER,
or any of the four above on its *non*-default navigation approach), the
script still generates the folder skeleton (one stub file per that
architecture's layer names — see `docs/ai/architecture.md`'s table), the
Models file, and a test scaffold — but the layer file **bodies** are
`TODO(agent)` stubs. When the script reports this ("not the fully-templated
combo"), **you must then write those bodies** from `docs/ai/architecture.md`'s
description of the chosen pattern — this is the one place this Skill hands
off real work to you rather than the script. VIPER specifically: write it as
VIP's shape with the `weak` reference dropped and Router taking full
navigation ownership (§3.3).

## Destination resolution (§4's topology branch)

An explicit `--module` argument wins. Otherwise the script reads the config's
`defaultModule`. If neither resolves (more than one app/module candidate and no
default declared), it refuses and asks you to pass `--module <name>` — never
guess. That refusal is the backstop, not the interface: question 3 above means
the developer should have chosen before the script ever runs.

## After the script runs

- If it printed a "no Route/destination insertion marker found" warning,
  manually wire the new screen into the navigation backbone before considering
  the feature done — the script only writes at markers it can find.
- If it fell back to template-assisted mode, write the stub layer file bodies
  now, following the protocol-boundary rules in `docs/CODING_STANDARDS.md`
  (§8.2): each layer file declares the protocol for the capability it consumes,
  and the concrete type for the capability it implements.
- **On a `networking: none` project** the script says so explicitly. Write the
  data layer's one `fatalError` body against `localStore`, then replace the
  placeholder test with a real one against a fake `<Name>LocalStoreProtocol`.
  Two things not to do: don't reintroduce a read-through policy (there is no
  remote call to fall back *from* — the store is the source of truth), and don't
  add a `RequestBuilder`/`APIClient` dependency to make it look like the
  networked templates. If the feature genuinely needs a network call, that's the
  developer changing `networking` in the config, not you widening one screen.
- Search-as-you-type fields: wire through `Core/Utilities/Debouncer.swift`
  rather than firing a request per keystroke — the script does not do this
  automatically.
- With a local store generated, check the read-through policy against the
  requirement before calling it done: the template caches the whole list and
  falls back to the cache only when the remote call fails. A feature that pages,
  syncs deltas, or must read local-first needs that method rewritten — the
  generated version is a starting policy, not a decision made for you.
- Implement the behaviour the requirement describes (validation, empty/error
  copy, paging) on top of the scaffold, and note anything the requirement left
  open in `TODO.md` rather than choosing silently.
- Refuses to run if the feature folder already exists — don't work around this
  by picking a different name; either the feature is genuinely new, or you
  meant to edit the existing one.
