# Coding Standards

Shipped as-is in every project this template generates. Separates what
SwiftLint enforces from what's convention-only.

## Tool-enforced (`.swiftlint.yml`, `Scripts/lint.sh --strict`)

- Line length, type/function/file length — see `.swiftlint.yml` for the exact
  thresholds.
- No `try!` (`custom_rules.no_force_try`) — handle or propagate the error
  explicitly.
- No `print()` outside test targets (`custom_rules.no_print_statements`) — log
  through `Core/Logging/Log.swift`'s `Logging` protocol, rendered into every
  project by `/start` (§8.6). Inject it where a type is testable; use the
  `log` default directly only from composition roots and top-level error paths.
  Never log a token, credential or personal data.
- No raw string literal directly inside `Text(...)` in a `*View.swift` file
  (`custom_rules.no_hardcoded_localized_string_literal`) — route through
  `L10n.<key>` instead.
- `Scripts/check_hardcoded_colors.sh` blocks a commit that constructs a color
  outside a `Theme/` directory (§6) — run in the pre-commit hook, not SwiftLint
  itself.
- `Scripts/check_strings.sh` blocks a commit with a localization key parity
  mismatch or a cross-module key duplicate (§8.5).

## Convention-only (reviewed, not tooled)

- **Force-unwrap policy:** avoid `!` outside of test code and the small set of
  cases where a crash on failure genuinely is the correct behavior (e.g.
  unwrapping a `URLComponents`-built `URL` immediately after constructing it
  from known-valid input). Prefer `guard let`/`if let`/`??`.
- **`// MARK:` organization:** one `// MARK: -` per logical section in a file
  over ~40 lines — typically `// MARK: - Properties`, `// MARK: - Lifecycle`,
  `// MARK: - Actions`. Generated feature files follow this once they grow
  past the initial scaffold.
- **Naming:** types are `UpperCamelCase`; properties, functions, and cases are
  `lowerCamelCase`. A generated file is always `<Feature><Layer>.swift`
  (`HomeViewModel.swift`, never `ViewModel-Home.swift` or similar).
- **No hardcoded user-facing strings.** Route through the owning module's
  `L10n.<key>` — see `docs/ai/ui_rules.md`. Not mechanically enforceable
  everywhere (§10), so this is a review gate.

## Protocol-boundary rules (§8.2) — the discipline that outlives everything else here

- A module's public surface is a set of **protocols**; concrete types
  satisfying them are injected by whoever composes the app. A shared module
  never branches on which app is running (`if app == .x` inside shared code
  has already failed — the next difference adds a second branch).
- Every `Service`/`Repository`/`Interactor` is a **protocol plus a concrete
  implementation**, and the consumer depends on the protocol.
- **A protocol is owned by the module that consumes it, not the one that
  implements it.** This is what keeps the dependency arrow pointing the right
  way (app → shared → leaf) and lets a leaf module be swapped without
  touching its callers.
- Protocol names state a **capability** (`SystemRepository`,
  `AnalyticsReporting`), not a pattern (`HomeInteractorProtocol`) — a name that
  only exists to distinguish itself from its own implementation usually means
  the abstraction shouldn't exist yet.
- Don't abstract on speculation. The threshold for a protocol existing at all
  is a **second real conformance** — a test fake counts, a hypothetical future
  backend does not.
- Keep protocols narrow enough that a fake is a few lines. A 20-method service
  protocol is a strong signal the module is doing more than one thing.

## Dependency injection — when to move off manual (§8.4)

Manual initializer injection is the default at every tier — dependency-free,
and every construction site is visible by reading the code. The signal to
introduce a container isn't module count on its own, it's when a composition
root's constructor call has grown past what's readable at a glance (rule of
thumb: more than ~6-8 positional dependencies threaded through, or the same
dependency re-threaded through 3+ layers just to reach a leaf that needs it).
When that happens, introduce a lightweight container (e.g. Factory) **at the
composition root only** — it should never leak into `Features/`, where
constructor injection stays the rule regardless of what wires it at the top.
This is a project opting in later, not something `/start`/`/add-module`
generate.

## Configuration and secrets (§8.3)

- **Nothing that varies by environment is a literal in Swift.** (An offline,
  `networking: none` project has no base URL to configure — everything below
  still applies to whatever else varies by environment.) `Secrets.xcconfig`
  (gitignored) holds it; `Secrets.xcconfig.example` (committed) records which
  keys exist; the app target's build configurations include the former, and the
  composition root passes the resolved values into `Networking/RequestBuilder`'s
  `baseURL`/headers. A `Service` never constructs a URL from a string literal.
- **`Secrets.xcconfig` is never committed.** `/start` copies a `.gitignore` that
  already excludes it. If you add a key, add it to `.example` in the same commit
  — a key that exists only on your machine breaks CI and every new hire.
  `Scripts/check_secrets.sh` enforces that parity in both directions, and treats
  a key the example carries *commented out* as permitted but not required.
- **A blank value is a hard failure, not a default.** `$(KEY)` expands to an
  empty string, so an unset key reaches Swift indistinguishably from a missing
  one. Nothing in this template papers over that with a fallback: on a networked
  project the composition root stops the app at launch. Run
  `Scripts/check_secrets.sh` to catch an empty — or `//`-truncated — value before
  you build.
- **Treat "in the binary" as "public".** An `Info.plist` value or a compiled-in
  string is extractable from the IPA. Client-side keys go in `Secrets.xcconfig`
  only when the vendor's threat model allows a public key; anything genuinely
  sensitive stays server-side behind an endpoint you control.
- One `AppEnvironment` type resolving base URL and endpoints is the right shape
  **once a second configuration exists**. Before that, the `Info.plist` key plus
  `RequestBuilder`'s injected `baseURL` is already the seam, and a wrapper type
  adds indirection without a second case to justify it (same threshold as the
  protocol rule in §8.2).

### Writing a URL in xcconfig — how the `$()` escape works

`//` starts a comment in an xcconfig file, and there is **no way to escape it**,
because xcconfig has no escape character and no string literals. A value is raw
text from `=` to end-of-line with everything after the first `//` discarded. That
is the whole grammar. So `API_BASE_URL = https://host` gives you `https:`.

`$()` is not an escape sequence — nothing in xcconfig escapes anything. It works
because the file is processed in **two passes**, and it slips between them:

1. **Parse.** The line is split into key and value and the comment is stripped.
   The scanner is looking for the literal two characters `//`. In
   `https:/$()/host` the slashes are separated by three other characters, so
   there is no comment to find and the whole value survives.
2. **Expand.** `$(NAME)` substitutes the build setting `NAME`. Here the name is
   *empty*, so it substitutes nothing and disappears, leaving `https://host`.

The `//` is therefore never adjacent at the moment anything is looking for it,
and is fully formed by the time anything uses it. `${}` is the same trick with
the brace form of substitution and works identically. Both are verified below.

**This means quoting cannot help, and neither can backslashes.** Quotes are
ordinary characters to xcconfig — there is no string type for them to delimit —
so they neither hide the `//` from pass 1 nor get removed in pass 2. Each row
here is what `xcodebuild -showBuildSettings` actually resolved:

| Written in `Secrets.xcconfig` | Resolves to | |
| --- | --- | --- |
| `https:/$()/api.example.com` | `https://api.example.com` | correct |
| `https:/${}/api.example.com` | `https://api.example.com` | correct |
| `https://api.example.com` | `https:` | truncated at the comment |
| `"https://api.example.com"` | `"https:` | truncated, plus a stray quote |
| `'https://api.example.com'` | `'https:` | same — quotes are not syntax |
| `https:\/\/api.example.com` | `https:\/\/api.example.com` | literal backslashes in the value |
| `https://api.example.com // note` | `https:` | the first `//` wins — the one *inside* the URL |

Two things to take from the table. The backslash row is the dangerous one: it is
the only broken form that doesn't *look* truncated, so it survives a glance at
the file and fails later as a bad host. And the last row means you cannot put a
trailing comment on a line holding a URL at all — put the comment on its own line
above it. Every failing row is rejected by both `Scripts/check_secrets.sh` and
the composition root's launch guard.

Escaping is only a problem for values that contain `//` — which in practice means
URLs. A key, token or host without a scheme needs none of this.

## Choosing where data goes

Three stores, three jobs. Picking wrong is the most common source of both bugs
and security findings in an iOS codebase, so the rule is mechanical:

| Data | Store | Why |
|---|---|---|
| Small, non-sensitive app state and preferences — last selected tab, "seen onboarding", sort order, a feature-flag override | `UserDefaults` | Synchronous, plist-backed, survives launches. Not a database and not secure: it's a readable plist in the app container. |
| Domain records the app queries, lists, or works with offline | The project's Q4 store (SwiftData / Core Data) | Relationships, predicates, and a migration story. See the section below for how it's wired. |
| Tokens, refresh tokens, passwords, anything that would be a breach if leaked | Keychain | The only encrypted, hardware-backed option, and the only one excluded from unencrypted backups. |

- **Never a credential in `UserDefaults`,** and never in a local database
  either — both are plaintext in the container and land in an unencrypted
  backup. This is the one hard line in this section.
- **`UserDefaults` is a dependency, not a global.** Wrap it behind a narrow
  protocol owned by its consumer (§8.2) so the feature is testable without
  mutating the simulator's defaults; use one type per concern rather than a
  `Settings` grab-bag. `@AppStorage` is fine directly in a View for view-local
  UI state, and wrong for anything a ViewModel or Interactor decides on.
- **Don't reach for `UserDefaults` as a cache.** Once a value has a lifetime,
  an eviction rule, or more than a handful of instances, it belongs in the Q4
  store — a plist read on every launch grows into a launch-time cost nobody
  attributes to it.
- **This template ships no Keychain wrapper** — auth/session handling is a
  documented non-goal (see `docs/ONBOARDING.md`). The selection rule above
  still holds: when the project grows a session layer, it goes behind a
  protocol like any other dependency, with Keychain as the concrete store.

## Local persistence, when the project has it (§3.8)

Only relevant if the project's Q4 answer isn't `None` — otherwise every feature
is remote-only and none of this applies.

- **The local store is a dependency like any other:** a protocol declared by the
  layer that consumes it (Repository for MVVM, Worker for VIP/VIPER, Service for
  MVC), a concrete `<Feature>LocalStore` implementing it, and injection from the
  composition root. Nothing below the composition root reaches for
  `PersistenceController.shared`.
- **A record type is a model.** SwiftData's `@Model` `<Feature>Record` lives in
  `Models/` beside the struct it mirrors — never in the feature folder, and never
  in place of that struct. The record is the storage shape, the struct is the
  domain shape, and the store maps between them. Nothing outside the store
  should traffic in records.
- **The generated read-through policy is a starting point.** Cache on success,
  read the cache only when the remote call failed, rethrow when the cache is
  empty. Rewrite that one method when a feature pages, syncs deltas or edits
  locally — don't add a second call path around it.

## Concurrency (§8.7) — structured, not GCD

- **The generated code is async/await end to end.** Every `Service`,
  `Repository`, `Worker` and `LocalStore` is `async throws`; `Debouncer` is an
  `actor`; UI-owning types (`Coordinator`, SwiftUI `ViewModel`s, generated test
  cases) are `@MainActor`. There is no `DispatchQueue` in any template, and new
  code shouldn't introduce one.
- **Reach for GCD only where an API forces it** — a completion-handler SDK with
  no async overload, or a `DispatchSourceTimer`-style primitive. Wrap it once in
  a `withCheckedThrowingContinuation` at the boundary and keep the async
  signature facing the rest of the app. Don't mix models inside one type.
- **Isolate shared mutable state with an `actor`, not a lock or a serial
  queue.** `Debouncer` is the shipped example. A `class` with a private
  `DispatchQueue` for synchronization is the pattern this replaces.
- **Hop to the main actor by annotation, not by dispatch.** Mark the type or
  method `@MainActor`; a `DispatchQueue.main.async` inside an async function is
  a sign the isolation is declared in the wrong place.
- **Never block a thread waiting on async work** — no semaphore-plus-`wait` to
  make an async call look synchronous. It deadlocks the cooperative pool under
  load, and it's an easy accident in an initializer.

## ARC and reference cycles

- **A closure that outlives the call needs `[weak self]`.** The rule that
  matters is ownership direction: escaping closures stored on a long-lived
  object (a `UIAction` handler, an observation, a retained callback) capture
  strongly and cycle. The generated `ViewController` retry handler shows the
  shape — `[weak self]`, then `self?`. A non-escaping closure (`map`, `forEach`,
  a `Task` whose lifetime is bounded by the call) does not need it, and adding
  it there is noise.
- **A back-reference up the ownership graph is always `weak`.** VIP's
  `Presenter.displayLogic` is the shipped case: the ViewModel owns the
  Interactor, the Interactor owns the Presenter, and the Presenter's pointer
  back at the display layer must be `weak` or the whole scene leaks. Wiring it
  after both objects exist is required, not stylistic — see the architecture
  combo's `README.md`.
- **Prefer `weak` over `unowned`.** `unowned` is a crash where `weak` is a
  no-op; use it only when the referent provably outlives the reference and the
  optionality is genuinely in the way.
- **Delegates and parent pointers are `weak`, children are strong.** A
  `Coordinator` holding its child coordinators strongly while each child points
  back at its parent `weak` is the correct arrangement; reversing it leaks every
  screen the user visits.

## Structs or classes

Default to a `struct`. Reach for a `class` for a specific reason, and the
reasons are short:

- **Identity** — two instances with equal contents are not the same thing, or
  callers must observe one shared instance mutating. `AppCoordinator` and a
  `ViewModel` are classes for this reason; `Models/` records, `RequestBuilder`,
  `APIClient`'s conformances and every DTO are structs because they have none.
- **A framework requires it** — `UIViewController` subclasses, SwiftData
  `@Model` types, `NSObject` conformances, and anything that must be the target
  of a `weak` reference (which is why VIP's SwiftUI variant needs a
  reference-type ViewModel bridge at all — a `View` is a value type).
- **`@Observable`/`@MainActor` view state** — SwiftUI observation is built on
  reference semantics; a ViewModel is a `final class`.

Corollaries worth stating because they get missed:

- **Mark every class `final` unless something subclasses it today.** Subclassing
  is not a design goal here; protocols and injection are (§8.2).
- **A value type with a mutable reference-type property isn't a value type.** A
  `struct` holding a `class` shares that object across copies — the most common
  way "it's a struct, so it's safe to pass across tasks" turns out to be false.
- **Prefer `let` and a returned copy over `mutating`** in domain models. A
  `struct` whose whole surface is `mutating` methods usually wants to be an
  `actor` (shared state) or a `class` (identity) instead.
- Very large structs copied on every access are a real cost, but that's a
  profiler finding — don't pre-emptively make something a class for it.

## Force-unwrap and fatal error markers

`/new-feature`'s generated tests use `fatalError("TODO: provide a fake value
for <Type>")` deliberately, for exactly one purpose: an unrecognized custom
field type still compiles, but fails loudly the moment the test actually runs,
rather than silently guessing a wrong fake value (§4.1). This is the one
sanctioned use of `fatalError` as a placeholder — everywhere else, prefer a
real error path.

The second — and only other — sanctioned crash is the composition root's
`APIBaseURL` read (`App.swift`/`SceneDelegate.swift`), **on projects that have a
networking layer at all**: a missing or malformed base URL misconfigures every
request in the app, so `preconditionFailure` at launch is correct where a
fallback URL or a silently broken screen is not. This is the "a crash on failure
genuinely is the correct behavior" clause of the force-unwrap policy above.

**Three failure modes, three distinct messages**, because each one sends you to a
different file — the read is deliberately stricter than a plain optional check:

| What went wrong | What the message tells you to fix |
| --- | --- |
| The `APIBaseURL` key is absent from the target's `Info.plist` | the `/start`/`/add-app` wiring never happened for this target — add `APIBaseURL = $(API_BASE_URL)` |
| The value resolves to an empty string | `API_BASE_URL` in `Secrets.xcconfig`, which is either blank or absent — `$(API_BASE_URL)` expands to empty either way, so the message never claims which |
| The value parses but isn't an absolute URL | the value itself, with the offending text echoed and the xcconfig escape spelled out |

That third check tests `scheme` **and** `host`, not just that `URL(string:)`
returned something, and both halves are load-bearing. `//` starts a comment in
xcconfig, so an unescaped `https://host` arrives as the truncated `https:` —
which parses fine with a `nil` host. A scheme-less `host.example.com` parses as a
*relative* URL. Before those checks existed, both sailed through the guard and
broke every request at runtime instead, which is the exact silent failure the
crash is here to prevent.

`Scripts/check_secrets.sh` applies the same rules to `Secrets.xcconfig` at commit
time — including the comment-stripping the build does, so it sees what Swift will
see. Prefer finding this at commit rather than at launch.

The commonest way to trip the third check is xcconfig's comment syntax eating
your URL — see "Writing a URL in xcconfig" above for the mechanism and the full
table of what resolves to what.

Two limits on it. It is not a licence to extend the pattern to other
configuration reads — an absent optional feature flag has a default; a base URL
doesn't. And on a `networking: none` project the reader isn't rendered at all,
which is the right shape: an offline app has no `RequestBuilder` to feed, so the
answer is to omit the read, never to make it tolerant. If you find yourself
wanting a fallback URL, the value isn't optional — the layer is.
