#!/usr/bin/env python3
"""Read and write String Catalogs (.xcstrings) for the template's localization scripts.

A String Catalog is JSON: one file per resource-owning module holding every
locale, every translation state, and every plural variation (§8.5). This module
is the single place that knows that format — `generate_strings.sh`,
`check_strings.sh` and `/translate` all go through it rather than each growing
their own JSON handling.

Subcommands:
    l10n <catalog> <module> <bundle-strategy>  emit that module's L10n.swift
    keys <catalog>                             one localization key per line
    locales <catalog>                          one locale code per line
    report <catalog>                           parity/state report, TSV
    set <catalog> <locale> <key> <value>       write one entry as needs_review
    migrate <catalog> <base> <locale>=<file>…  build a catalog from .strings files
    add <catalog> <key> <value> [comment]     add a source-language key, creating
                                              the catalog if it does not exist
"""

from __future__ import annotations

import json
import sys

# Xcode's own on-disk style for .xcstrings. Matching it means a file this script
# writes and a file Xcode rewrites produce no spurious diff against each other.
_DUMP_KWARGS = dict(indent=2, sort_keys=True, ensure_ascii=False,
                    separators=(",", " : "))

SWIFT_RESERVED = {
    "default", "class", "struct", "enum", "func", "var", "let", "if", "else",
    "for", "while", "return", "in", "import", "protocol", "extension", "case",
    "switch", "static", "public", "private", "internal", "self", "super",
    "true", "false", "nil", "where", "as", "is", "do", "try", "catch", "throw",
    "guard", "repeat", "break", "continue", "defer", "init", "deinit", "any",
}


def load(path):
    """Parse a String Catalog, failing with a readable message rather than a traceback."""
    try:
        with open(path, encoding="utf-8") as handle:
            return json.load(handle)
    except FileNotFoundError:
        sys.exit(f"xcstrings.py: no String Catalog at {path}")
    except json.JSONDecodeError as error:
        sys.exit(f"xcstrings.py: {path} is not valid JSON — {error}")


def save(path, catalog):
    """Write a String Catalog back in Xcode's own formatting."""
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(catalog, handle, **_DUMP_KWARGS)
        handle.write("\n")


def source_language(catalog):
    """The catalog's base locale — the one translations are drafted from."""
    return catalog.get("sourceLanguage", "en")


def entries(catalog):
    """Every localization key in the catalog, sorted."""
    return sorted(catalog.get("strings", {}).keys())


def locales(catalog):
    """Every locale code appearing anywhere in the catalog, plus the source language."""
    found = {source_language(catalog)}
    for entry in catalog.get("strings", {}).values():
        found.update(entry.get("localizations", {}).keys())
    return sorted(found)


def state_of(catalog, key, locale):
    """Translation state of one key in one locale, or None when the entry is absent.

    A String Catalog records state per entry: `translated`, `needs_review`, or
    `new` (Xcode's marker for a key it extracted but nobody has translated).
    Both `new` and a missing entry mean the same thing to a user — they'd see
    the source-language string — so callers treat them alike.
    """
    entry = catalog.get("strings", {}).get(key, {})
    unit = entry.get("localizations", {}).get(locale, {}).get("stringUnit")
    if unit is None:
        # A key with plural/device variations has no top-level stringUnit but is
        # still localized; treat the presence of any variation as translated.
        variations = entry.get("localizations", {}).get(locale, {}).get("variations")
        return "translated" if variations else None
    return unit.get("state")


def swift_safe(name):
    """Turn one dot-separated key component into a legal Swift identifier."""
    cleaned = "".join(char if char.isalnum() or char == "_" else "_" for char in name)
    if not cleaned or cleaned[0].isdigit():
        cleaned = "_" + cleaned
    if cleaned in SWIFT_RESERVED:
        return f"`{cleaned}`"
    return cleaned


def build_tree(keys):
    """Nest dot-separated keys into the enum tree L10n exposes."""
    tree = {}
    for key in keys:
        node = tree
        parts = key.split(".")
        for index, part in enumerate(parts):
            current = node.setdefault(part, {"__children__": {}})
            if index == len(parts) - 1:
                current["__key__"] = key
            node = current["__children__"]
    return tree


def emit_tree(tree, indent, out):
    """Render one level of the enum tree — leaves become computed properties."""
    pad = "    " * indent
    for name in sorted(tree.keys()):
        node = tree[name]
        children = node["__children__"]
        if "__key__" in node and children:
            # `home` and `home.title` cannot both exist in Swift — one wants to be
            # a property, the other an enum of the same name. The enum wins; say so.
            print(f"xcstrings.py: key '{node['__key__']}' is also a key prefix — "
                  "skipped in L10n, rename one of them.", file=sys.stderr)
        if "__key__" in node and not children:
            escaped = node["__key__"].replace("\\", "\\\\").replace('"', '\\"')
            out.append(f'{pad}static var {swift_safe(name)}: String {{ L10n.tr("{escaped}") }}')
        else:
            out.append(f"{pad}enum {swift_safe(name)} {{")
            emit_tree(children, indent + 1, out)
            out.append(f"{pad}}}")


def command_l10n(path, module, bundle_strategy):
    """Emit a module's bundle-aware L10n.swift from its String Catalog."""
    catalog = load(path)
    out = [
        "// Generated by Scripts/generate_strings.sh from Localizable.xcstrings. Do not edit by hand.",
        f"// Regenerate with: Scripts/generate_strings.sh {module}",
        "import Foundation",
        "",
    ]
    if bundle_strategy == "module":
        out += [
            "private extension Bundle {",
            "    /// This module's own resource bundle — never Bundle.main.",
            "    static let l10n = Bundle.module",
            "}",
        ]
    else:
        out += [
            "/// Anchors the bundle lookup below to this module's compiled bundle.",
            "private final class L10nBundleToken {}",
            "",
            "private extension Bundle {",
            "    /// This module's own resource bundle — never Bundle.main.",
            "    static let l10n = Bundle(for: L10nBundleToken.self)",
            "}",
        ]
    out += [
        "",
        "/// Typed accessors for this module's user-facing strings.",
        "///",
        "/// Every value resolves through this module's own bundle, so a shared module's",
        "/// strings still load correctly when consumed by an app target.",
        "enum L10n {",
        "    /// Looks one key up in this module's String Catalog.",
        "    fileprivate static func tr(_ key: String) -> String {",
        '        NSLocalizedString(key, bundle: .l10n, comment: "")',
        "    }",
        "}",
        "",
        "extension L10n {",
    ]
    emit_tree(build_tree(entries(catalog)), 1, out)
    out.append("}")
    print("\n".join(out))


def command_report(path):
    """Print a TSV parity/state report: one row per key/locale problem."""
    catalog = load(path)
    base = source_language(catalog)
    all_locales = [code for code in locales(catalog) if code != base]
    for key in entries(catalog):
        if state_of(catalog, key, base) is None:
            print(f"MISSING_BASE\t{base}\t{key}")
        for locale in all_locales:
            state = state_of(catalog, key, locale)
            if state is None or state == "new":
                print(f"MISSING\t{locale}\t{key}")
            elif state == "needs_review":
                print(f"NEEDS_REVIEW\t{locale}\t{key}")


def command_add(path, key, value, comment=None):
    """Add one source-language entry, creating the catalog if needed.

    Idempotent: an existing key keeps whatever value and translations it already
    has, so re-running a generator never clobbers edited text.
    """
    import os

    if os.path.exists(path):
        catalog = load(path)
    else:
        catalog = {"sourceLanguage": "en", "strings": {}, "version": "1.0"}

    base = source_language(catalog)
    entry = catalog.setdefault("strings", {}).setdefault(key, {})
    if comment and "comment" not in entry:
        entry["comment"] = comment
    localizations = entry.setdefault("localizations", {})
    if base not in localizations:
        localizations[base] = {"stringUnit": {"state": "translated", "value": value}}
    save(path, catalog)


def command_set(path, locale, key, value):
    """Write one translation as needs_review, creating the key if necessary."""
    catalog = load(path)
    strings = catalog.setdefault("strings", {})
    entry = strings.setdefault(key, {})
    entry.setdefault("localizations", {})[locale] = {
        "stringUnit": {"state": "needs_review", "value": value}
    }
    catalog.setdefault("version", "1.0")
    catalog.setdefault("sourceLanguage", "en")
    save(path, catalog)


def parse_strings_file(path):
    """Parse a legacy .strings file into an ordered list of (key, value, comment).

    Handles the two forms Xcode ever wrote: `/* comment */` above an entry, and
    `"key" = "value";` with C-style escapes. Anything else is skipped rather than
    guessed at — a migration that silently drops a malformed line is better than
    one that invents a translation for it.
    """
    import re

    with open(path, encoding="utf-8") as handle:
        text = handle.read()

    pattern = re.compile(
        r'(?:/\*(?P<comment>.*?)\*/\s*)?'
        r'"(?P<key>(?:[^"\\]|\\.)*)"\s*=\s*"(?P<value>(?:[^"\\]|\\.)*)"\s*;',
        re.DOTALL,
    )

    def unescape(raw):
        return (raw.replace('\\n', '\n').replace('\\t', '\t')
                   .replace('\\"', '"').replace('\\\\', '\\'))

    results = []
    for match in pattern.finditer(text):
        comment = match.group("comment")
        results.append((
            unescape(match.group("key")),
            unescape(match.group("value")),
            comment.strip() if comment else None,
        ))
    return results


def command_migrate(path, base, pairs):
    """Build one String Catalog from a set of per-locale .strings files."""
    catalog = {"sourceLanguage": base, "strings": {}, "version": "1.0"}
    for pair in pairs:
        locale, _, source = pair.partition("=")
        for key, value, comment in parse_strings_file(source):
            entry = catalog["strings"].setdefault(key, {})
            if comment and "comment" not in entry:
                entry["comment"] = comment
            # Everything already shipped is treated as translated. A migration is
            # not the moment to re-open every existing translation for review.
            entry.setdefault("localizations", {})[locale] = {
                "stringUnit": {"state": "translated", "value": value}
            }
    save(path, catalog)
    print(f"xcstrings.py: wrote {len(catalog['strings'])} keys to {path}")


def main(argv):
    if len(argv) < 2:
        sys.exit(__doc__)
    command, path = argv[0], argv[1]
    if command == "l10n":
        command_l10n(path, argv[2], argv[3])
    elif command == "keys":
        print("\n".join(entries(load(path))))
    elif command == "locales":
        print("\n".join(locales(load(path))))
    elif command == "report":
        command_report(path)
    elif command == "set":
        command_set(path, argv[2], argv[3], argv[4])
    elif command == "migrate":
        command_migrate(path, argv[2], argv[3:])
    elif command == "add":
        command_add(path, argv[2], argv[3], argv[4] if len(argv) > 4 else None)
    else:
        sys.exit(f"xcstrings.py: unknown command '{command}'")


if __name__ == "__main__":
    main(sys.argv[1:])
