# Git Conventions

Shipped as-is. Documentation only — nothing in this template enforces these
mechanically (§10: no commit-msg hook checks the format).

## Commits

- **Feature-based commits.** A commit corresponds to one coherent change — one
  `/new-feature` scaffold, one bug fix, one refactor — not a mix of unrelated
  edits swept up together.
- **Message format:** `<type>: <summary>`, where `<type>` is one of `feat`,
  `fix`, `refactor`, `test`, `docs`, `chore`. Ticket ID first if your tracker
  issues one: `PROJ-123 feat: add Home feature`.
- Carry the tracker ticket ID in the commit when one exists — this is what a
  long-lived, multi-app codebase actually relies on in practice (§8.8), even
  though nothing here enforces it.

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
