---
name: translate
description: Draft target-locale entries into a module's String Catalog from its source language, marked needs_review for a human pass. Use for "/translate <locale-code> [locale-code...]" or "add Spanish/French/... strings".
model: inherit
---

# /translate `[--module <M>] <locale-code> [locale-code...]`

Resolves §10's former "no localization Skill" gap (§4.9). Drafts; never a
substitute for a human review pass before shipping.

## Precondition

Check for `ios-skeleton.config.json` first. Missing → refuse: *"This project
hasn't been initialized yet — run `/start` first."*

## What this Skill does

1. **Resolve the target module** the same way `/new-feature` does (§4.1): an
   explicit `--module` argument → the config's declared default → a single-
   module fallback → refuse and ask if more than one candidate exists.
2. **Read that module's String Catalog** — `Localization/Localizable.xcstrings`.
   One file holds every locale for the module. Its `sourceLanguage` (normally
   `en`) is the source of truth; never draft *from* a translated locale.
3. **Run `Scripts/check_strings.sh`** and read its output for this module, or
   go straight to the underlying report:

   ```bash
   python3 Scripts/lib/xcstrings.py report <module>/Localization/Localizable.xcstrings
   ```

   It prints one TSV row per problem — `MISSING <locale> <key>` for an entry
   that is absent or still in Xcode's `new` state, `NEEDS_REVIEW <locale> <key>`
   for one already drafted and awaiting a human.

   For each requested locale, draft **only** the keys reported `MISSING` for it.
   A locale that isn't in the catalog yet reports every key as missing, which is
   exactly the right behavior — there is no separate "create the locale" step,
   because a String Catalog has no per-locale file to create.

   Never touch an entry that already exists, whether it's `translated` or still
   `needs_review`. Someone else's draft is not this Skill's to overwrite.
4. **Write each drafted entry through the helper, never by hand-editing JSON:**

   ```bash
   python3 Scripts/lib/xcstrings.py set <catalog> <locale> <key> "<translation>"
   ```

   This writes `"state": "needs_review"` — the catalog's own review marker,
   which Xcode's String Catalog editor displays directly — and re-serializes the
   file in Xcode's own formatting, so the next time Xcode saves it there's no
   spurious diff. Hand-editing the JSON risks both.

   Translate properly: you're an LLM, so produce a real translation of the
   source string, not a copy of the English. If you genuinely can't for some
   key, still write the entry (English text is acceptable) rather than skipping
   it — a missing entry fails `check_strings.sh`'s parity check, and a silently
   absent key is worse than a visibly unreviewed one.
5. **Re-run `Scripts/generate_strings.sh <module>`** afterward. `/translate`
   only adds translations, never keys, so `L10n`'s surface is unchanged — but
   running it keeps the generated file honestly in sync and costs nothing.
6. **Don't regenerate the Xcode project.** Adding a locale to a String Catalog
   creates no file and no folder, so `xcodegen generate` isn't needed — the
   catalog is already a referenced source file and the next build compiles the
   new locale into the app. (This is a change from the older per-locale
   `.lproj/Localizable.strings` layout, where a new language *did* require a
   regenerate.)

## What this Skill does not do

- **Does not decide which locales a project ships.** The locale list is an
  explicit argument every invocation, never a guessed default, and it is not
  part of `/start`'s Setup Questionnaire. If the project tracks its shipped
  locale list somewhere (`docs/PROJECT_MAP.md` is the natural place), record
  it there yourself if it isn't already — this Skill only fills in what's
  asked for.
- **Does not replace human review.** Every drafted entry is written
  `needs_review` for exactly this reason — an LLM-drafted translation is a
  draft, not a shipped string. `check_strings.sh` reports the outstanding count
  on every run without failing, so the queue stays visible.
- **Does not migrate a project off `.strings`.** If the module has per-locale
  `Localizable.strings` and no catalog, `check_strings.sh` will say so and name
  `Scripts/migrate_strings_to_catalog.sh`. Run that first; this Skill only ever
  writes a String Catalog.

## Refuses to run if

- `ios-skeleton.config.json` is missing (§1.3's shared precondition).
- The base locale itself has keys `Scripts/check_strings.sh` reports as
  inconsistent (extra/duplicate) — fix the source of truth before drafting
  more locales from it, rather than propagating a bad base key everywhere.
