---
name: status
description: Report this project's topology, module graph, lint health, and open follow-ups — computed fresh every call, no cached summary. Use for "/status" or "what's the state of this project".
---

# /status

## Precondition

Check for `ios-skeleton.config.json` first. Missing → refuse: *"This project
hasn't been initialized yet — run `/start` first."*

## What to compute, fresh, every call — never reuse a previous answer

1. **Topology tier and module graph.** Read `ios-skeleton.config.json`; for
   each app/module report its kind and who depends on it (walk each spec's
   `dependencies:`/`.package(path:)` entries, don't just trust the config —
   the config records intent, the specs record what's actually wired).
2. **Features per module.** Count `Features/*` folders (and grouped
   subfolders, per §3.2) under each app.
3. **Lint health.** Run `Scripts/lint.sh`; report pass/fail, not just "ran".
4. **Open `TODO.md` items.** List them, don't just count them.
5. **Orphan/unreferenced check.** Any module directory not referenced by any
   consumer's spec, and (at T3) any project directory not listed in the
   workspace file — this is the characteristic T3 failure mode (modules are
   cheap to add, nobody deletes them).
6. **Scheme sharing.** Every app's scheme should be under
   `xcshareddata/xcschemes/` and committed — flag any that isn't (the most
   common "works locally, fails in CI" cause).
7. **`Package.resolved` location.** Should sit at the tier-correct path (root
   project's `xcshareddata/swiftpm/` at T1/T2, the workspace's at T3) — flag if
   it's anywhere else, which usually means a stale copy from before a topology
   migration.

## What NOT to do

- **No full build/test unless asked.** This Skill reports state; it doesn't
  run the suite unless the developer explicitly wants that too.
- Don't summarize from memory of a previous `/status` call in this
  conversation — re-derive everything; the whole point is that this is
  computed fresh.
