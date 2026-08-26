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

## Inside `Theme/`

Start flat: `ColorTokens.swift` and `Typography.swift` are the whole layer on day
one, and two files need no folders.

**Split by token family once a family outgrows one file** — `Color/`, `Font/`,
`Size/`. A shipped app of this kind reaches four files of type handling
alone (the font family, the type scale, a scaled-font helper for Dynamic Type),
which is the point `Typography.swift` stops being one file. Colors follow the
same rule and usually later. Subfolders are safe for tooling:
`check_hardcoded_colors.sh` matches any path containing `Theme/`, at any depth.

The per-app override stays **one file**, named for the app — `Theme.<App>.swift`
in that app's own `Theme/`. If an app's overrides need a folder of their own, the
app is redefining the palette rather than overriding it, which is the failure the
base/override split exists to prevent.

## Per-component styling

A component's *look* — a button's fills, insets and typography per variant — is a
theme concern, not a view concern. It lives in `Theme/ComponentStyles/<Component>.swift`
and the component in `DesignSystem/Views/` reads it. That keeps a per-app restyle
in the override layer instead of forking the view (the rule in
`docs/ai/ui_rules.md`), and it keeps the style out of the view's own file where a
second app can't reach it.

**Name it `ComponentStyles/`, never `Theme/Views/`.** The shipped app that
provides this pattern calls it `Theme/Views/`, and the cost is two folders named
`Views` — one for real views and one for styles — which is exactly how a real
view ends up in the theme layer.

## Scope

Applies to **colors and typography**, mandatorily. A spacing scale
(`Spacing.swift`) is optional — add it the same way once a team wants one (§10).
Per-component styles are optional in the same sense: the first one appears when a
component's styling stops fitting in a token.

## Enforcement

`Scripts/check_hardcoded_colors.sh` scans staged Swift files for
`UIColor(red:`/`Color(red:`/hex-literal construction outside any `Theme/`
directory and blocks the commit. It does not catch a duplicated token (the same
color redefined under a different name) — that's a review concern, not a tooled
one (§10).
