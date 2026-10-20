#!/usr/bin/env python3
"""Collects every translatable text and checks the translations.

Run from the project root:  python3 tools/i18n.py
- writes locale/messages.pot (template for new languages)
- lists texts missing from (or no longer used in) each locale/*.po

Translatable texts are tr("...") / tr_n("...", "...", n) calls in scripts/, plus item,
behaviour, job, career, coziness and goal texts in scripts/catalog.gd.
"""
import glob
import os
import re

ROOT = os.path.join(os.path.dirname(__file__), "..")
STR = r'"((?:[^"\\]|\\.)*)"'
# Shown through tr(variable), so they can't be found from tr("...") calls.
EXTRA = ["Goals", "Behaviours", "Photos", "Bubák", "Training", "Grooming", "Shows", "Trophies",
         "1st", "2nd", "3rd", "4th"]


def extract():
    singles, plurals = [], []
    for path in sorted(glob.glob(os.path.join(ROOT, "scripts", "**", "*.gd"), recursive=True)):
        src = open(path, encoding="utf-8").read()
        singles += re.findall(r'\btr\(\s*' + STR + r'\s*\)', src)
        plurals += re.findall(r'\btr_n\(\s*' + STR + r'\s*,\s*' + STR, src)
        if path.endswith("catalog.gd"):
            singles += re.findall(r'"(?:name|desc|title|text)":\s*' + STR, src)
            tabs = src[src.index("const SHOP_TABS"):]
            tabs = tabs[:tabs.index("}")]
            singles += re.findall(STR + r':\s*\[', tabs)
    singles += EXTRA
    seen, out = set(), []
    for s in singles:
        if s not in seen:
            seen.add(s)
            out.append(s)
    return out, list(dict.fromkeys(plurals))


def read_po(path):
    """Returns the set of msgids that have a non-empty translation."""
    text = open(path, encoding="utf-8").read()
    done = set()
    for block in text.split("\n\n"):
        m = re.search(r'^msgid ' + STR, block, re.M)
        if not m or m.group(1) == "":
            continue
        translated = re.findall(r'^msgstr(?:\[\d\])? ' + STR, block, re.M)
        if translated and all(t != "" for t in translated):
            done.add(m.group(1))
    return done


def main():
    singles, plurals = extract()
    pot = ['msgid ""', 'msgstr ""', '"Content-Type: text/plain; charset=UTF-8\\n"', ""]
    for s in singles:
        pot += [f'msgid "{s}"', 'msgstr ""', ""]
    for s, p in plurals:
        pot += [f'msgid "{s}"', f'msgid_plural "{p}"', 'msgstr[0] ""', 'msgstr[1] ""', ""]
    with open(os.path.join(ROOT, "locale", "messages.pot"), "w", encoding="utf-8") as f:
        f.write("\n".join(pot))
    wanted = set(singles) | {s for s, _ in plurals}
    print(f"{len(wanted)} translatable texts")
    ok = True
    for po in sorted(glob.glob(os.path.join(ROOT, "locale", "*.po"))):
        have = read_po(po)
        missing = [s for s in singles + [s for s, _ in plurals] if s not in have]
        unused = sorted(have - wanted)
        name = os.path.basename(po)
        print(f"{name}: {len(wanted) - len(missing)}/{len(wanted)} translated")
        for s in missing:
            print(f"  MISSING  {s}")
        for s in unused:
            print(f"  UNUSED   {s}")
        ok = ok and not missing
    raise SystemExit(0 if ok else 1)


if __name__ == "__main__":
    main()
