---
name: add-module
description: Create a new shared package/framework and wire it into every consumer that needs it — the additive half of the T1→T2/T2→T3 migration path. Use for "/add-module <name>" or "extract this into a shared module".
model: opus
effort: high
---

# /add-module `<name> [--kind framework|package] [--deps A,B]`

## Precondition

Check for `ios-skeleton.config.json` first. Missing → refuse: *"This project
hasn't been initialized yet — run `/start` first."*

## Steps

1. **Refuse at T1** with the reason: adding a module *is* the T1→T2 migration.
   Print those steps (spec edit, move files in, add `public`, regenerate,
   `import`, build/lint/test) and ask the developer to confirm the tier change
   first — don't perform it as a side effect of this Skill.
2. **Run the deterministic half:**
   ```
   Scripts/new_module.sh <name> [--kind framework|package] [--deps A,B] [--ui]
   ```
   This creates the module's folders, spec (`Package.swift`/`project.yml`),
   test target, and — with `--ui` — its `Localization/` + `Assets.xcassets` +
   bundle-aware `L10n.swift`. It also generates one real compiling type and
   one passing test, so the module is proven wired before anyone moves code
   into it. Pass `--ui` whenever the module will own any user-facing views or
   strings.
3. **Extracting `Logging` is the one named case of this.** `/start` puts
   `Log.swift` in `Core` at every tier (one file doesn't earn its own project).
   When a team wants it independently versioned, `/add-module Logging` creates
   the module, the file moves in unchanged, and `"role": "logging"` goes on the
   new module's config entry so `resolve_role` finds it there. Nothing else
   changes — it depends on nothing, which is what makes it a clean leaf.
4. **Wire it into each consumer's spec — this is your job, not the script's.**
   For every project/package that needs the new module, add the dependency to
   its `project.yml`/`Package.swift`, then regenerate (`xcodegen generate`/
   `tuist generate`). At T3, re-run `Scripts/generate_workspace.sh` afterward.
5. **Enforce the dependency rule.** A module may not depend on an app. A
   dependency cycle is a **hard refusal**, not a warning — check the existing
   graph in `ios-skeleton.config.json` before adding the edge.
6. **Record it.** Add the module, its kind, and its consumers to
   `ios-skeleton.config.json`'s `modules` array, and append a line to
   `docs/PROJECT_MAP.md`.

## What NOT to do

- Don't skip step 1's refusal at T1 even if it seems like "just this once" —
  the whole point is that this migration is deliberate and reviewable.
- Don't leave a module with zero consumers after creating it — if nothing
  wires into it yet, say so in `docs/PROJECT_MAP.md` rather than letting
  `/status` discover an orphan later.
