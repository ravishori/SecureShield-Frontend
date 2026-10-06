"""Numeric localization coverage for the Flutter UI (run from flutter_app/):  python tool/l10n_coverage.py

Counts, over lib/features/**/*.dart and lib/core/widgets/**/*.dart:
  localized  = places that read AppLocalizations (a key is used)
  hardcoded  = user-visible English literals: Text('...'), labelText/hintText/tooltip/label/title/content: '...'
               containing at least one letter and 3+ characters (so icons, routes and numbers are ignored)
Coverage % = localized / (localized + hardcoded). It is a heuristic (some literals are brand names or debug text),
and it says nothing about translation QUALITY, which needs native-speaker review.
"""
import glob
import re
import sys

LIT = re.compile(r"""(?:\bText\(\s*(?:const\s+)?|\b(?:labelText|hintText|tooltip|label|title|content|helperText)\s*:\s*(?:const\s+)?(?:Text\(\s*(?:const\s+)?)?)(['"])((?:\.|(?!\1).)*?)\1""")
USE = re.compile(r"AppLocalizations\.of\(")
rows = []
loc = hard = 0
for p in sorted(glob.glob("lib/features/**/*.dart", recursive=True) + glob.glob("lib/core/widgets/**/*.dart", recursive=True)):
    s = open(p, encoding="utf8").read()
    u = len(USE.findall(s))
    h = sum(1 for m in LIT.finditer(s) if re.search(r"[A-Za-z]{3}", m.group(2)) and "$" not in m.group(2)[:1])
    if u or h:
        rows.append((h, u, p))
    loc += u
    hard += h
total = loc + hard
print(f"localized={loc} hardcoded={hard} coverage={100*loc/total:.1f}%")
if "-v" in sys.argv:
    for h, u, p in sorted(rows, reverse=True)[:25]:
        print(f"{h:4d} hardcoded {u:3d} localized  {p}")
