# Theming Rules

Shipped as-is — not rendered from a template, applies to every project regardless
of chosen architecture (§6).

## The one explicit deviation from stock Xcode convention

**Never define colors as Asset Catalog color sets.** Every color and font is a
Swift value in a `Theme/` directory:

```swift
enum ThemeColor {
    static let primary = Color(
        light: UIColor(red: 0.09, green: 0.45, blue: 0.91, alpha: 1),
        dark:  UIColor(red: 0.36, green: 0.65, blue: 0.98, alpha: 1)
    )
}
```

**Why:** one typed, compiler-checked source of truth usable from both SwiftUI and
UIKit, instead of string-keyed Asset Catalog lookups that fail silently on a
typo. It's also what makes `Scripts/check_hardcoded_colors.sh` mechanically
enforceable, and keeps light/dark handling a one-file change. A Swift token
crosses a framework boundary as a `public static let`; an Asset Catalog color
needs the right bundle at every lookup site and fails at runtime when it doesn't
get one.

## Base vs. override (from T2 onward — §3.11)

- **Base tokens** — the full palette, type scale, spacing — live in the shared
  module's `Theme/` (`DesignSystem/Theme/` at T2, the shared framework's `Theme/`
  at T3).
- **Each app's own `Theme/`** overrides only what actually differs (brand color,
  maybe a font family) and adds nothing else.
- `/update-theme` asks which layer a token belongs in and refuses to write an
  app-specific value into the shared module. It also warns when an app override
  shadows a base token it doesn't actually differ from.
- At T1 there is one layer and nothing to decide.

Two apps that each redefine the whole palette are not sharing a design system —
they're maintaining two.

## Scope

Applies to **colors and typography**, mandatorily. A spacing scale
(`Spacing.swift`) is optional — add it the same way once a team wants one (§10).

## Enforcement

`Scripts/check_hardcoded_colors.sh` scans staged Swift files for
`UIColor(red:`/`Color(red:`/hex-literal construction outside any `Theme/`
directory and blocks the commit. It does not catch a duplicated token (the same
color redefined under a different name) — that's a review concern, not a tooled
one (§10).
