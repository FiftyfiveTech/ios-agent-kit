---
name: update-app-icon
description: Replace an app's icon from a single 1024x1024 PNG (no alpha), or regenerate every legacy icon size via sips. Use for "/update-app-icon <path-to-1024-png>" or "update the app icon".
---

# /update-app-icon `[--app <A>] <path-to-1024-png>`

## Precondition

Check for `ios-skeleton.config.json` first. Missing → refuse: *"This project
hasn't been initialized yet — run `/start` first."*

## Steps

1. **Validate the source.** Require exactly one 1024×1024 PNG with **no alpha
   channel** (`sips -g hasAlpha -g pixelWidth -g pixelHeight`). Refuse and
   report the actual dimensions/alpha state if it doesn't match — never
   silently resize or strip alpha and proceed.
2. **Resolve which app.** If the config declares more than one app, `--app`
   is **required** — never silently re-icon all of them. If there's exactly
   one app, it needs no flag.
3. **Replace or regenerate.**
   - Modern single-size `AppIcon.appiconset`: replace the one image entry.
   - Legacy multi-size iconset present: regenerate every required size from
     the 1024px source via `sips -z <h> <w>`.
4. **Scope.** Touch only that one app's `AppIcon.appiconset` — never any other
   asset in the catalog, and never a second app's icon.

## What NOT to do

- Don't accept a PNG with alpha "because it looks fine" — App Store Connect
  rejects icons with an alpha channel at upload, and this Skill exists
  specifically to catch that before it gets that far.
- Don't guess which app when more than one is declared — ask.
