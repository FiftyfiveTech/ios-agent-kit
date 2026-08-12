---
name: new-feature
description: Generate a new feature end to end — layer files, shared Models entry, navigation registration, and a real passing unit test against a fake dependency. Use for "/new-feature <Name> [field:Type,...]" or "add a screen for X".
---

# /new-feature `[--module <M>] <Name>[/<Group/Path>] ["field:Type,field2:Type2,..."]`

## Precondition

Check for `ios-skeleton.config.json` at repo root before doing anything else.
Missing → refuse: *"This project hasn't been initialized yet — run `/start`
first."* Never guess an architecture or a "reasonable default."

## What this Skill does

Runs `Scripts/new_feature.sh` with the same arguments, then reviews its output.

```
Scripts/new_feature.sh [--module <M>] <Name>[/<Group/Path>] ["field:Type,..."]
```

The script is deterministic for the default stack (MVVM + SwiftUI +
`NavigationStack`): it generates

- **Business layer** (UseCase/Interactor): pure Swift, no UI/networking
  imports, depending on the data layer's *protocol* only.
- **Data layer** (Repository + Service): protocol + implementation, wired to
  the project's chosen networking stack — never a second networking path.
- **Presentation layer** (ViewModel/Presenter/Controller + View): matching the
  chosen UI framework, flat in `Features/<Name>/` (or
  `Features/<Group>/<Name>/`) — no `Presentation/`/`Domain/`/`Data/`
  subfolders.
- **Models**: `Models/<Name>Models.swift` in the shared location — never a
  file inside the feature folder. The script refuses and asks if a field's
  type collides with an existing type already defined in `Models/`.
- **Navigation**: a new `Route` case and a `destination(for:)`/
  `make<Name>View()` registration, inserted at the markers left by `/start` —
  never a second navigation path. If part of a tab-bar flow, wires into that
  tab's own stack only.
- **Localization**: appends the target module's `Localizable.strings` with
  `<module>.<feature>.title`/`.empty` and regenerates that module's `L10n.swift`
  — never a hardcoded string literal.
- **A real, passing unit test** against a fake dependency (not a placeholder).
  Fake values default sensibly by type; an unrecognized/custom type still
  compiles but fails loudly at test runtime via `fatalErrorFakeValue()`.

For any other architecture/UI/navigation combination, the script still
generates the folder skeleton (one stub file per that architecture's layer
names — see `docs/ai/architecture.md`'s table), the Models file, and a test
scaffold — but the layer file **bodies** are `TODO(agent)` stubs. When the
script reports this ("not the fully-templated combo"), **you must then write
those bodies** from `docs/ai/architecture.md`'s description of the chosen
pattern — this is the one place this Skill hands off real work to you rather
than the script.

## Destination resolution (§4's topology branch)

An explicit `--module` argument wins. Otherwise the script reads the config's
`defaultModule`. If neither resolves (more than one app/module candidate and no
default declared), it refuses and asks you to pass `--module <name>` — never
guess.

## After the script runs

- If it printed a "no Route/destination insertion marker found" warning,
  manually wire the new screen into the navigation backbone before considering
  the feature done — the script only writes at markers it can find.
- If it fell back to template-assisted mode, write the stub layer file bodies
  now, following the protocol-boundary rules in `docs/CODING_STANDARDS.md`
  (§8.2): each layer file declares the protocol for the capability it consumes,
  and the concrete type for the capability it implements.
- Search-as-you-type fields: wire through `Core/Utilities/Debouncer.swift`
  rather than firing a request per keystroke — the script does not do this
  automatically.
- Refuses to run if the feature folder already exists — don't work around this
  by picking a different name; either the feature is genuinely new, or you
  meant to edit the existing one.
