---
name: add-permission
description: Add an Info.plist usage-description entry for a plain-language permission (camera, location, etc.), flag Capability/entitlement requirements, and log it to docs/PERMISSIONS.md. Use for "/add-permission <permission>" or "this feature needs camera access".
model: inherit
---

# /add-permission `[--app <A>] <permission>`

## Precondition

Check for `ios-skeleton.config.json` first. Missing → refuse: *"This project
hasn't been initialized yet — run `/start` first."*

## Steps

1. **Map the plain-language permission to its exact key(s).** e.g. "camera" →
   `NSCameraUsageDescription`; "location" → `NSLocationWhenInUseUsageDescription`
   and/or `NSLocationAlwaysAndWhenInUseUsageDescription` depending on what the
   feature actually needs — ask if ambiguous rather than adding both blindly.
2. **Resolve which app.** A framework/package **cannot** declare a permission
   — `Info.plist` keys are app-target-only. If the requesting code lives in a
   shared module, the key still goes in **every app** that ships it, and say
   so explicitly rather than picking one app silently. With more than one app
   declared and no `--app`, ask which app(s) before writing anything, unless
   the shared-module case above already answers it (all of them).
3. **Insert a real, reviewable usage string** — never blank — marked
   `// TODO: confirm exact wording with product/legal`. The key goes in the
   app target's `info.properties` in `project.yml`, which is where its
   `Info.plist` is generated from — editing a generated `Info.plist` directly
   is overwritten on the next regenerate.
   If the app ships more than one language, the usage strings are localized in
   an `InfoPlist.xcstrings` catalog in the app target, not in the module's
   `Localizable.xcstrings` — they're read by the system, not by `L10n`.
4. **Flag Capability-gated permissions.** Push notifications, HealthKit, Sign
   in with Apple, and background modes need a Capability toggle **in addition
   to** the `Info.plist` key, plus a matching entry in that app's
   `.entitlements` file. Tell the developer this needs a manual toggle — no
   script in this template can do it for them.
5. **Run `xcodegen generate`** (or `tuist generate`) for each affected app.
   The permission is an edit to `project.yml`, and the `Info.plist` Xcode builds
   from is generated from it — without the regenerate, the key isn't in the app
   and the permission prompt crashes at request time.
6. **Append to `docs/PERMISSIONS.md`** (create it on first use): the
   permission, the justification, and which app(s) it applies to.

## What NOT to do

- Never leave the usage string blank "to fill in later" — write a real one now
  and mark it for legal/product review instead.
- Never add a permission to an app that doesn't actually request it, even if
  it shares a module with an app that does.
