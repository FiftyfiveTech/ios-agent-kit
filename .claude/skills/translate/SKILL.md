---
name: translate
description: Draft target-locale Localizable.strings entries from a module's base locale, marked for human review. Use for "/translate <locale-code> [locale-code...]" or "add Spanish/French/... strings".
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
2. **Read that module's base locale** — `Localization/en.lproj/Localizable.strings`
   (the only locale `/new-feature`/`/add-permission` write new keys to). This
   is the source of truth; never draft *from* a non-base locale.
3. **Run `Scripts/check_strings.sh`** and inspect its output for this module.
   For each requested locale code:
   - **Doesn't exist yet under `Localization/`:** create
     `<locale>.lproj/Localizable.strings` from scratch, one drafted line per
     base-locale key.
   - **Already exists:** add only the keys `check_strings.sh` reports as
     `MISSING in <that locale's file>` — never touch a key that's already
     present, translated or not. A key already there (even if still an
     obvious placeholder a human wrote) is not this Skill's to overwrite.
4. **Translate each new line yourself** (you're an LLM — draft a real
   translation of the base English string, not a copy of the English text),
   and mark every drafted line, in-file, as needing review:
   ```
   /* NEEDS_REVIEW */ "home.title" = "Início";
   ```
   so `grep -rn NEEDS_REVIEW` finds every unreviewed line across the whole
   repo and a reviewer can delete the marker comment once they've checked a
   line. Never leave a key both marked-reviewed (no comment) and untranslated
   — if you can't produce a real translation for a key, still add the line
   with the English text and the `NEEDS_REVIEW` marker rather than skipping
   it silently; a missing key breaks `check_strings.sh`'s parity check.
5. **Re-run `Scripts/generate_strings.sh <module>`** afterward so the new
   locale's keys are covered by the same `L10n.swift` accessor as every other
   locale. `/translate` only adds *strings* — it never changes what `L10n`
   exposes, since the base locale's key set is unchanged.

## What this Skill does not do

- **Does not decide which locales a project ships.** The locale list is an
  explicit argument every invocation, never a guessed default, and it is not
  part of `/start`'s Setup Questionnaire. If the project tracks its shipped
  locale list somewhere (`docs/PROJECT_MAP.md` is the natural place), record
  it there yourself if it isn't already — this Skill only fills in what's
  asked for.
- **Does not replace human review.** Every drafted line carries `NEEDS_REVIEW`
  for exactly this reason — an LLM-drafted translation is a draft, not a
  shipped string.

## Refuses to run if

- `ios-skeleton.config.json` is missing (§1.3's shared precondition).
- The base locale itself has keys `Scripts/check_strings.sh` reports as
  inconsistent (extra/duplicate) — fix the source of truth before drafting
  more locales from it, rather than propagating a bad base key everywhere.
