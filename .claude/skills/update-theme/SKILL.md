---
name: update-theme
description: Add or edit a color/typography token in the correct Theme/ layer (shared base vs. per-app override) — never Assets.xcassets. Use for "/update-theme" or "change the primary color" / "add a new theme token".
---

# /update-theme `[--layer base|app --app <A>]`

## Precondition

Check for `ios-skeleton.config.json` first. Missing → refuse: *"This project
hasn't been initialized yet — run `/start` first."*

## Steps

1. **Resolve the layer.** From T2 onward, base tokens live in the shared
   module's `Theme/`; each app has its own thin `Theme/` that overrides only
   what differs. Ask which layer this token belongs in if `--layer`/`--app`
   weren't given and it isn't obvious from context (a brand color is almost
   always an app override; a semantic token like "danger" is almost always
   base). At T1 there's one layer — skip this question.
2. **Refuse to write an app-specific value into the shared module.** If the
   developer asks for an app override to be added to the base tokens instead,
   say why that's wrong (two apps sharing a base token they don't actually
   share is not a design system, it's a bug waiting to diverge) and confirm
   before proceeding if they insist.
3. **Write the token as a Swift value**, never as an Asset Catalog color set —
   `ColorTokens.swift`/`Typography.swift`, not `Assets.xcassets`. Every color
   token is a light/dark pair exposed as both `Color` and `UIColor` from the
   same underlying value (see `docs/ai/theming_rules.md`).
4. **Warn on a redundant override.** If an app's override value is identical
   to the base token it's supposedly overriding, flag it — that's not an
   override, it's dead code that will silently drift later.

## What NOT to do

- Never touch `Assets.xcassets` for a color or font — that's the one explicit
  deviation from stock Xcode convention this template makes, and it's load-
  bearing for `Scripts/check_hardcoded_colors.sh`.
