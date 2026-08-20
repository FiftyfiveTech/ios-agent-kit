# mvvm-swiftui-navigationstack templates

One of four fully-authored, deterministic combos (§1.4) — the default: MVVM + SwiftUI +
`NavigationStack` + SwiftData, at T1/T2 shape (T3 placement for this combo is
best-effort — §10). The other three (`vip-swiftui-navigationstack/`,
`vip-uikit-coordinator/`, `mvc-uikit-coordinator/`) share this same token
convention and `feature/`/`app-shell/` split.

## Token convention

Every `*.template` file is plain Swift with these tokens, replaced by whichever script
or Skill renders it:

| Token | Replaced with | Example |
|---|---|---|
| `__FEATURE__` | PascalCase feature name | `Home` |
| `__FEATURE_LOWER__` | lowerCamelCase feature name | `home` |
| `__MODULE_LOWER__` | lowercase target-module name, for L10n namespacing | `app` |
| `__MODULE_IMPORTS__` | tier-dependent import lines (empty at T1) | `import Models` |
| `__APP_NAME__` | the app's type-name-safe display name | `MyApp` |
| `__IF_PERSISTENCE__` / `__ELSE_PERSISTENCE__` / `__END_PERSISTENCE__` | whole-line block markers: the `__IF_` branch survives when the project's Q4 answer isn't `None`, the `__ELSE_` branch when it is; all three marker lines are always deleted | — |

## Layout

- `feature/` — the five flat per-feature layer files + a test, rendered once per
  `/new-feature` call by `Scripts/new_feature.sh`. Each file declares the protocol
  for the capability it *consumes* and the concrete type for the capability it
  *implements* — never both for the same capability (§8.2).
- `app-shell/` — rendered exactly once, by `/start`, to bootstrap the very first
  app: composition root, navigation backbone, base theme tokens, the three shared
  states, and the two Networking primitives. `/new-feature` never touches these
  again except to insert a new `Route` case and `navigationDestination` arm at the
  marked insertion points.

## Local persistence

The `feature/` files above are the remote half of the data layer and are rendered
identically whatever the project's Q4 answer is. When that answer isn't `None`,
`Scripts/new_feature.sh` additionally renders
`Scripts/templates/persistence/<swiftdata|coredata>/LocalStore.swift.template`
into the same feature folder and keeps this combo's `__IF_PERSISTENCE__` blocks —
which is where the consuming layer declares the local store's protocol and gains
its second dependency (§3.8). The `app-shell/` composition root holds the one
`PersistenceController`; `/start` resolves its blocks by hand, since nothing
renders app-shell files mechanically.
