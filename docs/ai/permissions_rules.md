# Permissions Rules

Shipped as-is. Governs `/add-permission` (§4.4) and any manual permission work.

## The non-negotiables

- **Never add a permission without a non-empty usage string.** A blank
  `NSXxxUsageDescription` is worse than not declaring the permission — App Store
  review and, more importantly, users see the blank string. `/add-permission`
  always inserts a real, reviewable string marked
  `// TODO: confirm exact wording with product/legal` — never leaves it empty.
- **Never add a permission without a named app target.** A framework cannot
  declare a permission — `Info.plist` keys are app-target-only (§3.11). If the
  requesting code lives in a shared module, the key still goes in **every app**
  that ships that module, and `/add-permission` says so explicitly rather than
  picking one app silently.
- **Never add a permission without a `docs/PERMISSIONS.md` entry.** The
  permission, its justification, and which app(s) it applies to get appended
  every time — this file is the running source of truth for what the app asks
  users for and why.

## Capabilities beyond `Info.plist`

Push notifications, HealthKit, Sign in with Apple, and background modes need a
Capability toggle in addition to the `Info.plist` key, plus a matching entry in
that app's `.entitlements` file. `/add-permission` flags these explicitly and
tells the developer the manual toggle is still required — it is not something
any script in this template can do for them.

## Per-app, always

Multiple apps in one repo (T3) do not share a permission set implicitly. Adding
a permission for one app's feature never silently adds it to a second app that
doesn't request it.

## After adding a permission: regenerate

An `Info.plist` usage-description key is declared in the app target's
`info.properties` in `project.yml`, and the `Info.plist` Xcode builds from is
generated from it. Run `xcodegen generate` (or `tuist generate`) for each affected
app before testing — without it the key isn't in the built app and the permission
request crashes at the moment it's made.

Never hand-edit a generated `Info.plist`: the next regenerate discards it.

For an app shipping more than one language, usage strings are localized in an
`InfoPlist.xcstrings` catalog in the app target — the system reads these, not
`L10n`, so they don't live in the module's `Localizable.xcstrings`.
