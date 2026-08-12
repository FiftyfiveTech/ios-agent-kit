# Coding Standards

Shipped as-is in every project this template generates. Separates what
SwiftLint enforces from what's convention-only.

## Tool-enforced (`.swiftlint.yml`, `Scripts/lint.sh --strict`)

- Line length, type/function/file length — see `.swiftlint.yml` for the exact
  thresholds.
- No `try!` (`custom_rules.no_force_try`) — handle or propagate the error
  explicitly.
- No `print()` outside test targets (`custom_rules.no_print_statements`) — use
  the Logging module (§8.6).
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
- Every `Service`/`Repository`/`UseCase` is a **protocol plus a concrete
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

## Force-unwrap and fatal error markers

`/new-feature`'s generated tests use `fatalError("TODO: provide a fake value
for <Type>")` deliberately, for exactly one purpose: an unrecognized custom
field type still compiles, but fails loudly the moment the test actually runs,
rather than silently guessing a wrong fake value (§4.1). This is the one
sanctioned use of `fatalError` as a placeholder — everywhere else, prefer a
real error path.
