# Git Conventions

**A suggested starting point, not a rule this template enforces.** Commit and
branch conventions differ from team to team and from client to client, so
nothing here is mechanically checked — adopt what fits, change what doesn't,
and delete the rest. If your project already has conventions, those win; edit
this file to say so, since `CLAUDE.md` points the agent here and this is what
it will follow.

## Commits

- **Feature-based commits.** A commit corresponds to one coherent change — one
  `/new-feature` scaffold, one bug fix, one refactor — not a mix of unrelated
  edits swept up together. This is the part worth keeping whatever message
  format you settle on.
- **A message format, if you want one.** `<type>: <summary>`, where `<type>` is
  one of `feat`, `fix`, `refactor`, `test`, `docs`, `chore`. Ticket ID first if
  your tracker issues one: `PROJ-123 feat: add Home feature`. Conventional
  Commits, a plain imperative summary, or your team's existing house style are
  all equally fine — pick one and write it down here.
- Carry the tracker ticket ID in the commit when one exists — this is what a
  long-lived, multi-app codebase actually relies on in practice (§8.8).

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
