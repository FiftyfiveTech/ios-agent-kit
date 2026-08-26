# UI Rules

Shipped as-is — applies regardless of chosen architecture or UI framework.

## Every SwiftUI view

- **Mandatory `#Preview`.** A view with no preview is a view nobody looked at
  before committing it. `/new-feature`'s generated `<Name>View.swift` always
  includes one, wired to a fake/preview dependency — never the live network stack.
- **No hardcoded strings.** Every user-facing string goes through the owning
  module's `L10n.<key>` accessor (§3.7, §3.11) — never a raw catalog key, and
  never a literal in `Text(...)`/`UILabel.text`. The strings themselves live in
  that module's `Localization/Localizable.xcstrings` String Catalog: one file
  per module holding every locale, with translation state (`translated` /
  `needs_review` / `new`) recorded in the file itself. Add a key there and run
  `Scripts/generate_strings.sh <module>` — adding a key or a whole locale needs
  no project regeneration, because the catalog is already a referenced file.
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

## Shared views

Every list/detail screen uses `LoadingView`, `ErrorView` (with retry), and
`EmptyStateView` from the shared module's `DesignSystem/Views/` folder — never a re-implemented
spinner or "no results" label (§3.6). UIKit screens use `UIView` subclasses of the
same names from the same folder — same rule, same location, different concrete
type.

Those three are the first instance of a general rule, not a special case:

- **A view used by more than one screen belongs in `DesignSystem/Views/`.** Buttons with
  the app's styling, labelled rows, card containers, section headers, badges — if
  a second screen needs it, it is shared, in SwiftUI and UIKit alike.
- **Promote, don't copy.** When a new screen needs something an existing screen
  already has, move that view into `DesignSystem/Views/` and have both consume it. A
  near-identical view in two feature folders is the failure this prevents, and it
  is the normal way a design system stops being one. In a multi-app repo the same
  rule applies one level up: a component library serving exactly one app may live
  in that app, and it moves down into the shared module when a second app needs
  it — moved, never copied into both.
- **Parameterize with the theme, not with a fork.** A shared view that needs to
  look different in another app takes its colors and fonts from the theme tokens
  (`docs/ai/theming_rules.md`), which already have a per-app override layer. A
  second copy of the view is never the answer.
- **New shared views get a `#Preview` covering their states** — a shared
  component with one preview of one state is how the other states rot.
- **`DesignSystem/Views/` groups by component, never by layer.** A component
  stays a loose file for as long as it is one file (`LoadingView.swift`,
  `ErrorView.swift`, `CommonSwitch.swift`). It gets its own folder the moment it
  has a companion — its own view model, its own style, a subcomponent only it
  uses: `CommonLabel/CommonLabel.swift` + `CommonLabel/LabelViewModel.swift`,
  `Buttons/`, `Dropdown/`. A thematic group (`Molecules/Cards/`) is fine once
  several components belong to the same family. What's banned is exactly what's
  banned inside a feature folder: layer-named subfolders. (This mirrors a shipped
  app of this shape, whose shared folder carries ~20 loose components beside ~15
  component folders and not one layer-named subfolder.)

Nothing enforces this mechanically (unlike colors) — it's a review gate.

## Feature-scoped views

The shared-view rule above has an exact counterpart: **a view used by exactly one
screen stays with that screen.** It moves up through three shapes, and only when
it earns the move:

1. **A `private` view type in the screen's own file.** A header, a row, a footer,
   a small styled container — it lives at the bottom of `HomeView.swift`, or of the
   screen's `UIViewController` file in UIKit as a `private` `UIView` subclass. This is
   the default and most subviews never leave it. One file per subview is how a
   feature folder grows to fifteen files without becoming clearer.
2. **Its own file in the same feature folder** — `Features/Home/HomeHeaderView.swift`
   — once it stops being a small presentation helper: it owns state, it handles
   its own loading/error, a second file inside the feature needs it, or the screen
   file has grown far enough to trip SwiftLint's `file_length` (warning at 400
   lines). The first three are the real signals; the fourth is the backstop.
3. **Its own child-screen folder beside the parent's layer files** —
   `Features/Home/HomeDetail/`, generated with `/new-feature Home/HomeDetail` (name
   it uniquely app-wide — its models land in the shared `Models/` namespace, which
   nesting doesn't scope) — once it is really a second *screen* rather than a
   component: its own data source, its own
   navigation entry, its own tests. Layer-named subfolders (`Views/`, `Domain/`)
   inside a screen's folder stay banned at any depth.

The moment a **second screen** needs it, none of the three apply — it moves to
`DesignSystem/Views/` per the rule above, which outranks all of this.

## Icons and images

- **SF Symbols over imported icon assets, wherever a suitable symbol exists.**
  `Image(systemName:)` (SwiftUI) / `UIImage(systemName:)` (UIKit) — one bundled
  system resource instead of a growing set of PDF/SVG assets per icon, free
  light/dark and Dynamic Type behavior, and nothing for `check_hardcoded_colors.sh`
  to enforce against in the first place. Reserve `Assets.xcassets` for genuinely
  custom iconography/artwork a symbol can't express.
- **`AsyncImage` is the default for remote images** (avatars, thumbnails, hero
  art) — no third-party image-loading/caching library by default, matching this
  template's networking default (plain `URLSession`). Upgrade to a caching
  library (Nuke, Kingfisher) only once a project's image volume or caching needs
  justify the dependency — that's an explicit project decision, not something
  `/start` defaults into.

## Interface Builder

Generated UIKit screens lay out in code: no storyboard, no XIB, no
`Main.storyboard`, and the launch screen is the `UILaunchScreen` Info.plist
dictionary rather than a storyboard file. This is a decision about what the
template generates — the reasoning (unstable file text, opaque identifiers,
`@IBOutlet` wiring that fails at runtime rather than at build time, verbose
constraint XML) is recorded in the spec's architecture-pattern section.

A project is free to add storyboards or XIBs for hand-authored screens; they're
picked up on the next project regeneration. What no Skill will do is generate or
edit one — expect those screens to be built by a person in Xcode, with the agent
working on the code around them.

## Navigation

Whichever mechanism Q6 selected is the **only** one in the app. A view never
constructs a second `NavigationStack` or pushes via both `NavigationLink` and a
Coordinator (§2.3, §3.4).

## Dynamic Type and dark mode

Every screen `/new-feature` generates should remain legible at larger Dynamic
Type sizes and pass VoiceOver navigation — treat this as a merge gate, not a
follow-up (§8.9). Dark mode is guaranteed by construction as long as every color
goes through `docs/ai/theming_rules.md`'s light/dark token pairs.
