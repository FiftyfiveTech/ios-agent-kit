# mvc-uikit-coordinator templates

One of the four fully-authored, deterministic combos (§1.4): classic **MVC** +
**UIKit** + `UINavigationController` **Coordinator** navigation, at T1/T2 shape.

## Why one file, on purpose

Per §3.3's table, MVC's feature folder holds exactly **one** file:
`<Name>ViewController.swift`. Models live in `Models/`, never here — but there
is no separate Repository/Service/Worker layer for MVC the way MVVM or VIP
have one. That's intentional, not an oversight: MVC's whole point (and its
well-known risk) is that the ViewController owns everything, including the
networking call itself. So `ViewController.swift.template` contains the
service protocol, its concrete networking implementation, **and** the
ViewController together — one honestly "massive" file that makes MVC's
documented Massive-View-Controller risk visible instead of hiding it behind
an extra file that would just relocate the same coupling.

The protocol/concrete-implementation split still exists *inside* that one
file, because §4.1 requires a real, passing unit test against a fake
dependency for every generated feature — MVC gets no exception. Faking
`__FEATURE__ServiceProtocol` is what makes that test possible without a
mocking framework (§8.2).

Reasonable only for very small apps or a handful of screens — see §3.3's
"most Massive-View-Controller risk" note. A feature that outgrows one file is
a signal to reach for MVVM or VIP, not to start splitting this file into
ad-hoc pieces.

## Token convention

Every `*.template` file is plain Swift with these tokens, replaced by whichever
script or Skill renders it:

| Token | Replaced with | Example |
|---|---|---|
| `__FEATURE__` | PascalCase feature name | `Home` |
| `__FEATURE_LOWER__` | lowerCamelCase feature name | `home` |
| `__MODULE_LOWER__` | lowercase target-module name, for L10n namespacing | `app` |
| `__MODULE_IMPORTS__` | tier-dependent import lines (empty at T1) | `import Models` |
| `__APP_NAME__` | the app's type-name-safe display name | `MyApp` |
| `__IF_PERSISTENCE__` / `__ELSE_PERSISTENCE__` / `__END_PERSISTENCE__` | whole-line block markers: the `__IF_` branch survives when the project's Q4 answer isn't `None`, the `__ELSE_` branch when it is; all three marker lines are always deleted | — |
| `__TESTABLE_IMPORT__` | the test file's `@testable import` line | `@testable import App` |
| `__FAKE_MODEL_LIST__` | a fake `[__FEATURE__Model]` literal for the generated test | `[HomeModel(title: "test", subtitle: "test")]` |

## Layout

- `feature/` — the one flat per-feature file (`ViewController.swift.template`)
  plus its test, rendered once per `/new-feature` call by `Scripts/new_feature.sh`.
  The ViewController is a real `UITableView` + `UIActivityIndicatorView` +
  error label/retry button, driven by a plain `state` property — no
  `@Observable`/Combine needed, this is UIKit.
- `app-shell/` — rendered exactly once, by `/start`, to bootstrap the very
  first app: `AppDelegate`/`SceneDelegate` composition root,
  `AppCoordinator` (the app-wide navigation owner, §3.4), base theme tokens,
  and the two Networking primitives. `/new-feature` never touches these again
  except to insert a new `make<Feature>ViewController()` factory at the
  marked insertion point in `AppCoordinator.swift`.

`AppCoordinator` deliberately doubles as this app's composition root — MVC has
no separate Router/Presenter layer to own navigation, so the one app-wide
Coordinator (§3.4) both constructs each screen's dependencies and pushes it.
This is the same navigation contract `vip-uikit-coordinator` uses, so the two
UIKit combos are interchangeable at the navigation layer — their
`AppDelegate.swift.template`, `SceneDelegate.swift.template`, and
`AppCoordinator.swift.template` are byte-for-byte identical.

Shared, unmodified from `mvvm-swiftui-navigationstack/app-shell/`:
`ColorTokens.swift.template`, `Typography.swift.template`,
`RequestBuilder.swift.template`, `APIClient.swift.template`,
`Debouncer.swift.template`.

`LoadingView`/`ErrorView`/`EmptyStateView` exist here too, as `UIView`
subclasses rather than the SwiftUI versions — same names, same
`DesignSystem/Views/` destination, same rule that no feature reimplements
them (§3.6). Not copied: `Route`/`Router`/`App.swift.template`, since this
combo's navigation root is `UINavigationController`, not a SwiftUI
`NavigationStack`.

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
