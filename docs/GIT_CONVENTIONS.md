# Git Conventions

Shipped as-is. The message format below is mechanically checked by
`.githooks/commit-msg` (§7, §10 — resolved: this used to be documentation
only). What that hook can't check — whether a commit is genuinely
feature-based/one-coherent-change, whether the ticket ID is present when a
tracker issues one — stays a review concern.

## Commits

- **Feature-based commits.** A commit corresponds to one coherent change — one
  `/new-feature` scaffold, one bug fix, one refactor — not a mix of unrelated
  edits swept up together.
- **Message format (checked by `.githooks/commit-msg`):** `<type>: <summary>`,
  where `<type>` is one of `feat`, `fix`, `refactor`, `test`, `docs`, `chore`.
  Ticket ID first if your tracker issues one: `PROJ-123 feat: add Home feature`.
  The hook checks this shape; it can't tell a well-written summary from a lazy
  one, only that the format is there.
- Carry the tracker ticket ID in the commit when one exists — this is what a
  long-lived, multi-app codebase actually relies on in practice (§8.8). The
  hook accepts a commit without one (it can't know whether your tracker issues
  one), so this part stays convention, not enforcement.

## Branches (optional — adopt if your team wants named branches)

- `feature/<ticket-or-short-name>` for new features.
- `fix/<ticket-or-short-name>` for bug fixes.
- Topology migrations (§3.10) are large enough to deserve their own branch —
  never land a T1→T2 or T2→T3 move in the same branch as unrelated feature
  work.

## Pull requests

- Land through review, even solo — a PR is a checkpoint where SwiftLint,
  `check_hardcoded_colors.sh`, and `check_strings.sh` all get a chance to run
  in CI before merge (§8.7), and where a topology or architecture change gets
  a second pair of eyes given how much it touches (§3.10, §2.4).
