# vip-uikit-coordinator templates

One of the fully-authored, deterministic combos (§1.4): **VIP (Clean Swift) + UIKit +
`UINavigationController`/Coordinator** — the classic five-layer VIP shape, at T1/T2
shape (T3 placement for this combo is best-effort, same caveat as the MVVM combo).

## The shape

```
ViewController (conforms to <Feature>DisplayLogic directly)
      │  interactor.load(request:)
      ▼
Interactor (conforms to <Feature>BusinessLogic)
      │  presenter.present(response:) / present(error:)
      ▼
Presenter (conforms to <Feature>PresentationLogic)
      │  displayLogic?.display(viewState:) / displayError(message:)
      ▼
ViewController (via weak displayLogic)
```

Interactor also holds a `Worker` (conforming to `<Feature>WorkerProtocol`) for the
actual network I/O. Strictly one-way: the ViewController never reads state off the
Interactor directly — it fires `load(request:)` and waits for a `display`/
`displayError` callback. The Interactor never returns a value. The Presenter never
calls back into the Interactor.

UIKit needs no ViewModel bridge the way the SwiftUI VIP combo does (§1.4) — a
`UIViewController` is already a reference type, so it can hold `weak var
displayLogic` itself (declared on the Presenter, pointing back at the
ViewController).

## The one correctness rule that matters most

**`Presenter.displayLogic` MUST be `weak`.** The Interactor holds its Presenter
strongly, and the Presenter points back at the ViewController that owns that same
Interactor. A strong `displayLogic` closes that into a retain cycle —
`ViewController → Interactor → Presenter → ViewController` — and leaks the entire
scene every time it's pushed and popped. See the comment directly on the
declaration in `feature/Presenter.swift.template`.

The Presenter also hops explicitly to the main actor before calling
`displayLogic?.display*`, since the Interactor/Worker chain runs off the main
actor — UIKit calls from `display(viewState:)` must land on the main thread. The
ViewController's own `display`/`displayError` methods are straight-line UIKit —
they trust that hop and don't hop a second time.

## Wiring `displayLogic` — the one assembly step every factory must include

None of the four layer files above can assign `presenter.displayLogic` themselves
— the Presenter is constructed before the ViewController exists, and the
Interactor only ever sees the Presenter through the narrow
`__FEATURE__PresentationLogic` protocol, which has no `displayLogic` member. The
assignment has to happen at the composition site: whatever factory
`/new-feature` inserts at `AppCoordinator`'s `new-feature-factory-insertion-point`
marker (mirroring the `make<Feature>View()` factory the MVVM combo inserts into
`App.swift.template`) must build the concrete `Presenter`, keep a reference to
it, construct the `ViewController`, and only then close the loop:

```swift
private func make__FEATURE__ViewController() -> __FEATURE__ViewController {
    let presenter = __FEATURE__Presenter()
    let interactor = __FEATURE__Interactor(
        presenter: presenter,
        worker: __FEATURE__Worker(requestBuilder: requestBuilder, apiClient: apiClient)
    )
    let viewController = __FEATURE__ViewController(interactor: interactor)
    presenter.displayLogic = viewController   // weak — see Presenter.swift.template
    return viewController
}
```

Skip that last line and `displayLogic` stays `nil` forever — the Interactor will
run, the Presenter will build a `ViewState`, and nothing will ever reach the
screen. This snippet is verified to compile (see this combo's verification run);
whoever extends `new_feature.sh` to render this combo's factory should reuse it
verbatim.

Also note: this combo's generated test file is `<Feature>InteractorTests.swift`
(it tests the Interactor), not `<Feature>ViewModelTests.swift` like MVVM's —
there is no ViewModel in this combo to test.

## Protocol ownership (§8.2 — declared where CONSUMED, not implemented)

| Protocol | Declared in | Consumed by | Conformed to by |
|---|---|---|---|
| `<Feature>BusinessLogic` | `ViewController.swift.template` | ViewController | Interactor |
| `<Feature>PresentationLogic` | `Interactor.swift.template` | Interactor | Presenter |
| `<Feature>WorkerProtocol` | `Interactor.swift.template` | Interactor | Worker |
| `<Feature>DisplayLogic` | `Presenter.swift.template` | Presenter | ViewController |

`ViewController.swift.template` routes its navigation title through
`L10n.__MODULE_LOWER__.__FEATURE_LOWER__.title` — the one key `new_feature.sh`
already writes for every combo (§5's `ui_rules.md`). The retry button's label is a
plain `"Retry"` literal, not a per-feature L10n key — it's generic UI chrome, not
feature content, matching the shared SwiftUI `ErrorView`'s own precedent
(`app-shell/ErrorView.swift.template` in the MVVM/VIP+SwiftUI combos hardcodes the
same word for the same reason). This combo has no separate empty-state copy and
folds its error message into the Worker/Presenter's `error.localizedDescription`
rather than a localized string.

## Two different "Router"s — don't conflate them (§3.4/§1.4)

`feature/Router.swift.template` is VIP's own **per-scene** Router — one of the five
classic VIP layer files. It decides *where* this specific scene goes next, and
hands the actual push off to `app-shell/AppCoordinator.swift.template`, the
**app-wide** navigation owner that holds the one `UINavigationController` for the
whole app. The per-scene Router owns navigation *decisions*; the Coordinator owns
navigation *state*. The starter feature has nowhere to navigate yet, so its Router
ships as a small honest stub — matching how the MVVM combo ships zero `Route`
cases.

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
| `__TESTABLE_IMPORT__` | `@testable import <module>`, feature-test only | `@testable import App` |
| `__FAKE_MODEL_LIST__` | a fake `[<Feature>Model]` literal, feature-test only | `[HomeModel(title: "test")]` |

## Layout

- `feature/` — the six flat per-feature layer files (`ViewController`,
  `Interactor`, `Presenter`, `Router`, `Worker`, plus `ModelsExtra` for the
  Request/Response/ViewState namespace) and a test, rendered once per
  `/new-feature` call. Each file declares the protocol for the capability it
  *consumes* and the concrete type for the capability it *implements* — never
  both for the same capability (§8.2). `ModelsExtra.swift.template` is appended
  alongside the flat `<Feature>Model` entity struct `new_feature.sh` already
  generates in `Models/<Feature>Models.swift` (§3.2) — the entity struct itself
  is not generated by this template folder.
- `app-shell/` — rendered exactly once, by `/start`, to bootstrap the very first
  app: `AppDelegate`/`SceneDelegate` (no Storyboard), `AppCoordinator` (composition
  root + navigation owner), base theme tokens, and the two Networking primitives.
  There is no shared `LoadingView`/`ErrorView`/`EmptyStateView` here the way the
  SwiftUI combo has — those are SwiftUI-specific. Each `ViewController` builds its
  own loading spinner, error label and retry button directly, in keeping with
  VIP's own philosophy that the View owns only rendering; a small shared UIKit
  helper across features is legitimate future work once more than one feature
  needs it; not part of this deterministic starter (§4.7 could add one later).
  `/new-feature` never touches `app-shell/` again except to insert a new factory
  method at `AppCoordinator`'s marked insertion point.
