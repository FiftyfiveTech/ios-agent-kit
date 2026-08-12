# UI Rules

Shipped as-is — applies regardless of chosen architecture or UI framework.

## Every SwiftUI view

- **Mandatory `#Preview`.** A view with no preview is a view nobody looked at
  before committing it. `/new-feature`'s generated `<Name>View.swift` always
  includes one, wired to a fake/preview dependency — never the live network stack.
- **No hardcoded strings.** Every user-facing string goes through the owning
  module's `L10n.<key>` accessor (§3.7, §3.11) — never `Localizable.strings`
  accessed by a raw string key, and never a literal in `Text(...)`/`UILabel.text`.
  There is no mechanical check for this (unlike colors, §10) — it's a review
  convention, because a blanket regex would false-positive heavily on legitimate
  non-UI string literals (log messages, format strings, identifiers).
- **Never `Bundle.main` from inside a framework or package.** A shared module's
  generated `L10n` and any resource lookup resolves through that module's own
  bundle (`Bundle.module` for a package, `Bundle(for:)` for a framework) — see
  `docs/ai/modularization.md`'s per-module localization rule. `Bundle.main` from
  inside a shared module compiles fine and returns the wrong string or nil image
  at runtime, in the *consuming* app only.
- **Real or explicit-`nil` accessibility labels.** Every interactive element and
  every meaningful image needs an accessibility label — either the real,
  localized label or an explicit `nil` (decorative, intentionally silent to
  VoiceOver). An accidentally-missing label is not the same as a decorative
  image, and both should be distinguishable in a diff.

## Shared states

Every list/detail screen uses `LoadingView`, `ErrorView` (with retry), and
`EmptyStateView` from the shared module's `SharedViews/` — never a re-implemented
spinner or "no results" label (§3.6).

## Navigation

Whichever mechanism Q6 selected is the **only** one in the app. A view never
constructs a second `NavigationStack` or pushes via both `NavigationLink` and a
Coordinator (§2.3, §3.4).

## Dynamic Type and dark mode

Every screen `/new-feature` generates should remain legible at larger Dynamic
Type sizes and pass VoiceOver navigation — treat this as a merge gate, not a
follow-up (§8.9). Dark mode is guaranteed by construction as long as every color
goes through `docs/ai/theming_rules.md`'s light/dark token pairs.
