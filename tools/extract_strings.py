#!/usr/bin/env python3
"""Collect every player-facing English string into assets/lang/strings.csv.

Godot translates Control/Label3D text automatically when a translation is
loaded, using the English text itself as the key. So translating the game
later = add a column (e.g. "es") to strings.csv, let Godot import it, and add
the generated .translation file under Project Settings > Localization.

Usage: python3 tools/extract_strings.py
"""
import csv
import os
import re

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "assets", "lang", "strings.csv")
PATTERNS = [
    re.compile(r'(?:big_button|small_button|label|title|say)\(\s*"((?:[^"\\]|\\.)+)"'),
    re.compile(r'\.text\s*=\s*"((?:[^"\\]|\\.)+)"'),
    re.compile(r'"(?:text|start|name)":\s*"((?:[^"\\]|\\.)+)"'),
    re.compile(r'"(?:storm|done|flush)":\s*\[([^\]]+)\]'),
    re.compile(r'add_item\(\s*"((?:[^"\\]|\\.)+)"'),
]


def main():
    found = []
    for folder in ("scripts/ui", "scripts/levels", "scripts/plumbing", "scripts/gravity", "scripts/items"):
        for dirpath, _, files in os.walk(os.path.join(ROOT, folder)):
            for fn in sorted(files):
                if not fn.endswith(".gd"):
                    continue
                text = open(os.path.join(dirpath, fn), encoding="utf-8").read()
                for rx in PATTERNS:
                    for m in rx.finditer(text):
                        chunk = m.group(1)
                        items = re.findall(r'"((?:[^"\\]|\\.)+)"', chunk) if chunk.count('"') >= 2 else [chunk]
                        for s in items:
                            s = s.encode().decode("unicode_escape")
                            if "%" in s or len(s) < 2 or s.startswith("res://"):
                                continue
                            if s not in found:
                                found.append(s)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["keys", "en"])
        for s in found:
            w.writerow([s, s])
    print("Wrote %d strings to %s" % (len(found), os.path.relpath(OUT, ROOT)))


if __name__ == "__main__":
    main()
