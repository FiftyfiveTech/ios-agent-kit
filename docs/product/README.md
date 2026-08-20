# Product context — PRD, SRS and everything else the code can't tell you

This folder is the project's **domain slot**. The rest of this template describes
*how* an iOS app here is built — topology, architecture, theming, localization.
Nothing in it knows *what* the app is for. That knowledge lives here, and it is
the one part of the repo the template never generates, never renders and never
overwrites.

Drop the real documents in as they arrive:

```
docs/product/
├── README.md        # this file — shipped by the template, safe to edit
├── PRD.md           # what the product is, who it's for, what ships when
├── SRS.md           # functional/non-functional requirements
├── API.md           # endpoint contracts, auth model, error shapes
└── <anything else>  # glossary, user research, flows, decision log
```

None of those filenames are required. Any Markdown file in this folder counts as
product context; the list above is just the shape most projects converge on.

## These are living documents — treat them that way

Requirements are never final. A PRD is rewritten mid-sprint, an SRS grows a
section the week after sign-off, an endpoint changes shape twice before launch.
Three rules follow from that, and they apply to humans and agents equally:

- **Re-read before acting, every time.** An agent working on a feature reads the
  relevant document at the start of that task — not from memory, not from a
  summary someone pasted into `CLAUDE.md` months ago. `CLAUDE.md` deliberately
  carries only a *pointer* to this folder, never a digest of it, because a digest
  goes stale exactly as fast as the source changes.
- **Incomplete is the normal state.** A `TBD`, an open question, a section that
  contradicts last month's version — none of these are errors to fix before work
  can start. When a requirement an agent needs is genuinely missing or
  ambiguous, it asks rather than inventing one, and records the answer here.
- **Nothing here is generated.** `/start` creates this folder and this file and
  stops. No Skill renders a template into it, no re-run overwrites it, and an
  adopted project's existing product docs are left exactly where they are.

## How this connects to the rest of the repo

| When | What reads this folder |
|---|---|
| `/new-feature` | Before proposing field names and Swift types, it checks here for the requirement that describes the screen — a spec'd field list beats an inferred one, and the confirmation step says which document it used |
| Any agent implementing a feature | Business rules, validation, copy, edge cases and error states come from here, not from the code's existing shape |
| Code review | "Does this match the requirement?" is answerable only if the requirement is written down somewhere both sides can point at |

Traceability is deliberately lightweight: a feature notes which requirement it
came from in its own commit message or in `docs/PROJECT_MAP.md`. There is no
generated requirement-to-code matrix, because keeping one accurate by hand is
work no one does twice.

## Writing them so an agent can actually use them

Not a style guide — four things that measurably change the quality of generated
code:

- **State field names and types where you know them.** "Release year (integer,
  4 digits)" saves a round of questions and a wrong `String`.
- **Say what the screen does on failure and on empty**, not just on success. Every
  generated screen has loading/error/empty states; if the document is silent, the
  agent picks a default and you inherit it.
- **Name the API endpoint** a screen depends on, or say explicitly that it doesn't
  exist yet.
- **Date the changes.** "Updated 2026-03-04: pricing moved to server-side" tells an
  agent which of two contradicting paragraphs is current.
