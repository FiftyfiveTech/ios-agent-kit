---
name: add-app
description: Add a second (or Nth) app to a T3 workspace, reusing existing shared modules by extending their base views — never by copying screens. Use for "/add-app <name>" or "we need a second app sharing this codebase".
---

# /add-app `<name>`

## Precondition

Check for `ios-skeleton.config.json` first. Missing → refuse: *"This project
hasn't been initialized yet — run `/start` first."*

## Steps

1. **Require T3.** If the current topology isn't T3, offer the T2→T3
   migration first (spec edit for the new framework project, workspace
   generation, `Package.resolved` relocation, scheme re-sharing) — **never
   perform it silently** as a side effect of adding an app.
2. **Ask for the new app's identity** (display name, bundle ID, team — same
   shape as Q12 in `/start`'s questionnaire).
3. **Create the app project**: spec file, shared scheme, `Info.plist`,
   `.entitlements`, and an asset catalog with a placeholder icon.
   **Wire configuration into it the way `/start` §1.5a did for app one** —
   configuration files are per app target, so the new spec needs its own
   `configFiles:` entry pointing at the repo-root `Secrets.xcconfig`. On a
   networked project its `Info.plist` also needs `APIBaseURL` = `$(API_BASE_URL)`;
   skip that and the new app's composition root `preconditionFailure`s on first
   launch with the "missing from this target's `Info.plist`" message — which is
   worded for exactly this mistake, since app one works and only the new target
   is unwired. On a `networking: none` project, neither the key nor the reader
   exists — don't add either. If the app
   needs a *different* base URL from app one, that's the point a per-app key
   (`APP_TWO_API_BASE_URL`) or a real `AppEnvironment` type earns its place —
   add the key to `Secrets.xcconfig.example` in the same change — `check_secrets.sh`
   fails on a key that exists in one file and not the other, and a per-app URL
   still needs a scheme and a host to clear the launch guard.
4. **Declare dependencies on the existing shared modules**, and generate the
   app shell **by extending the shared base views** — run the same
   `Scripts/new_feature.sh` path `/start` used for the first app's starter
   feature, so the sharing seam is exercised immediately rather than asserted
   in a doc.
5. **Wire the new app's composition root the way `/start` wired the first one.**
   Render the same combo's `app-shell/` templates, resolving both marker families
   against the recorded config: `__IF_PERSISTENCE__`/`__ELSE_PERSISTENCE__`/
   `__END_PERSISTENCE__` against Q4, and `__IF_NETWORKING__`/`__END_NETWORKING__`
   against Q7 — `networking: none` means the whole networking block goes, so the
   new app gets no `RequestBuilder` and needs no `APIBaseURL` plist key (which is
   also why step 3's wiring is conditional) — with a persistence stack, the new
   app needs its own `PersistenceController` property in the composition root, or
   the factory `new_feature.sh` writes for its starter feature won't compile.
   `Core/Logging/Log.swift` is already shared; nothing to re-render for it.
6. **Create the app's own theme override layer** (§3.11) and its own
   `.lproj` set, seeded from the shared module's key list — not copied
   verbatim, seeded (empty values where the new app's copy genuinely differs).
7. **Add the project to the workspace** and regenerate; re-run
   `Scripts/generate_workspace.sh`.
8. **Append manual follow-ups to `TODO.md`**: signing, App Store Connect
   record, push certs — per-app, every time.

## The one rule that matters most here

**Never copy features from the existing app.** If the new app needs the same
screen as an existing one, that screen belongs in a shared module — say this
explicitly rather than duplicating it. A copied screen is the fastest way to
lose the entire value of T3: two apps that started sharing a spine end up
maintaining two copies of the same logic that will silently diverge.
