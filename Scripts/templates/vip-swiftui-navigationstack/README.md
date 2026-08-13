# vip-swiftui-navigationstack templates

The second fully-authored, deterministic combo (§1.4): VIP (Clean Swift) + SwiftUI +
`NavigationStack`, at T1/T2 shape (T3 placement for this combo is best-effort, same
caveat as `mvvm-swiftui-navigationstack`).

## Why VIP needs a ViewModel bridge in SwiftUI

Classic VIP puts `weak var displayLogic: XDisplayLogic?` on the Presenter, pointing
back at the ViewController — safe because a `UIViewController` is a reference type.
A SwiftUI `View` is a **value type** and cannot be the target of a weak reference.
This combo inserts a thin `@Observable` ViewModel as the reference-type bridge
instead (evidence-based, not invented for this template — see the production
reference in the spec's §8 baseline):

```
View → ViewModel (holds Interactor as XBusinessLogic, conforms to XDisplayLogic)
     → Interactor (conforms to XBusinessLogic, holds Presenter as XPresentationLogic,
                    holds Worker as XWorkerProtocol)
     → Presenter (conforms to XPresentationLogic, holds weak displayLogic: XDisplayLogic?)
     → Worker (conforms to XWorkerProtocol, does the real network I/O via
               RequestBuilder + APIClient)
```

One-way flow, same as UIKit VIP: the View never reads the Interactor directly, the
Interactor never returns a value to its caller (it always calls
`presenter.present(response:)`/`presenter.present(error:)`), and the Presenter never
calls back into the Interactor. The ViewModel contains **no formatting and no
business logic** — its only job is holding `@Observable` state and conforming to
`XDisplayLogic`.

`XDisplayLogic` ends up with two methods instead of classic VIP's one:
`display(viewState:)` and `display(errorMessage:)`. `XBusinessLogic.load(request:)`
is `async` with no `throws`, so the Interactor catches its own errors and reports
them through `presenter.present(error:)` — that failure path needs its own way to
reach the display layer, and folding it into the success-shaped `ViewState` would
give every successful load a dead `error` field. A second, symmetric display method
keeps each Presenter method doing exactly one job. See the longer comment in
`feature/Presenter.swift.template` for the full reasoning.

## Naming collision — two different "Router"s

VIP's per-scene `<Name>Router.swift` (`feature/Router.swift.template`) is **not**
the app-wide navigation Router. It decides *where a given scene goes next* and
hands that decision off to whichever app-wide mechanism `app-shell/Router.swift`
owns (the `NavigationPath`, shared with the MVVM combo). The starter feature ships
with zero `Route` cases to push to — same honest starting state as the MVVM combo —
so this file is deliberately small: a capability protocol (`XPushing`) the app-wide
`Router` conforms to for free, plus a `TODO(agent)` stub.

## Composition wiring — the integration contract this folder doesn't automate

Unlike MVVM (whose composition is a `FACTORY_SNIPPET` baked into `new_feature.sh`
itself), this combo's per-scene wiring lives nowhere but this README, because it
has one step MVVM's factory doesn't: a post-construction `weak` assignment. Whoever
wires `new_feature.sh` (or a project's own composition root) up for this combo needs
exactly this shape, per feature, in the app's composition root
(`app-shell/App.swift`'s `make<Feature>View()` factory):

```swift
private func make<Feature>View() -> <Feature>View {
    let presenter = <Feature>Presenter()
    let worker = <Feature>Worker(requestBuilder: requestBuilder, apiClient: apiClient)
    let interactor = <Feature>Interactor(presenter: presenter, worker: worker)
    let viewModel = <Feature>ViewModel(interactor: interactor)
    presenter.displayLogic = viewModel   // weak — must be set after both exist
    return <Feature>View(viewModel: viewModel)
}
```

The `presenter.displayLogic = viewModel` line has to come *after* both are
constructed, and it's the one line with no MVVM analogue — MVVM's Repository never
holds a weak back-reference to anything. Miss it and the Presenter's `displayLogic`
stays `nil` forever, silently: the Interactor/Worker/Presenter chain still runs, but
nothing ever reaches the ViewModel.

Rendered-file → generated-file mapping, for the same reason (VIP's isn't 1:1 with
MVVM's naming):

| Template | Generates | Notes |
|---|---|---|
| `View.swift.template` | `<Feature>View.swift` | |
| `ViewModel.swift.template` | `<Feature>ViewModel.swift` | declares `XBusinessLogic` |
| `Interactor.swift.template` | `<Feature>Interactor.swift` | declares `XPresentationLogic`, `XWorkerProtocol` |
| `Presenter.swift.template` | `<Feature>Presenter.swift` | declares `XDisplayLogic` |
| `Router.swift.template` | `<Feature>Router.swift` | declares `XPushing` |
| `Worker.swift.template` | `<Feature>Worker.swift` | |
| `ModelsExtra.swift.template` | appended into `Models/<Feature>Models.swift` | after the generated entity struct |
| `Tests.swift.template` | `<Feature>InteractorTests.swift` | note: `InteractorTests`, not `...ViewModelTests` like MVVM's — it tests the Interactor, since that's where VIP's actual logic lives |

## Token convention

Same tokens as `mvvm-swiftui-navigationstack` — reused exactly:

| Token | Replaced with | Example |
|---|---|---|
| `__FEATURE__` | PascalCase feature name | `Home` |
| `__FEATURE_LOWER__` | lowerCamelCase feature name | `home` |
| `__MODULE_LOWER__` | lowercase target-module name, for L10n namespacing | `app` |
| `__MODULE_IMPORTS__` | tier-dependent import lines (empty at T1) | `import Models` |
| `__APP_NAME__` | the app's type-name-safe display name | `MyApp` |
| `__TESTABLE_IMPORT__` | the test target's `@testable import` line | `@testable import MyApp` |
| `__FAKE_MODEL_LIST__` | a fake `[<Feature>Model]` literal for the generated test | `[HomeModel(title: "test")]` |

## Layout

- `feature/` — View, ViewModel, Interactor, Presenter, Router, Worker, a
  `ModelsExtra.swift.template` (the nested Request/Response/ViewState namespace
  appended after the generated `<Name>Model` entity struct in
  `Models/<Name>Models.swift` — §3.3), and a test. Each file declares the protocol
  for the capability it *consumes* and the concrete type for the capability it
  *implements* — never both for the same capability (§8.2):
  - `ViewModel.swift.template` declares `XBusinessLogic` (consumed by the
    ViewModel) and conforms to `XDisplayLogic`.
  - `Interactor.swift.template` declares `XPresentationLogic` and
    `XWorkerProtocol` (both consumed by the Interactor) and conforms to
    `XBusinessLogic`.
  - `Presenter.swift.template` declares `XDisplayLogic` (consumed by the
    Presenter) and conforms to `XPresentationLogic`.
  - `Worker.swift.template` conforms to `XWorkerProtocol`.
  - `Router.swift.template` declares `XPushing`, a narrow capability the
    app-wide `Router` conforms to for free.
- `app-shell/` — **identical, byte-for-byte, to `mvvm-swiftui-navigationstack`'s
  `app-shell/`.** Both combos share the same SwiftUI + `NavigationStack`
  navigation backbone and the same shared UI/networking primitives
  (`ColorTokens`, `Typography`, `LoadingView`, `ErrorView`, `EmptyStateView`,
  `RequestBuilder`, `APIClient`, `Debouncer`, `Route`, `Router`, `App`) — none of
  it is architecture-specific. Rendered exactly once, by `/start`, to bootstrap
  the very first app. `/new-feature` never touches these again except to insert
  a new `Route` case and `navigationDestination` arm at the marked insertion
  points.
