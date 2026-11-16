"""Check every hosted package in pubspec.lock against OSV (osv.dev) and fail on any advisory.

    python tool/osv_pub_scan.py pubspec.lock

Only package names and versions are sent. Exit 0 = none found, 1 = advisories found, 2 = lockfile/network problem.
OSV's pub coverage is partial; this complements, not replaces, review of Gradle/AndroidX dependencies.
"""

from __future__ import annotations

import json
import re
import sys
import urllib.request


def parse_lock(text: str) -> list[tuple[str, str]]:
    body = text.split("\npackages:\n", 1)[1].split("\nsdks:", 1)[0]
    out = []
    for entry in re.split(r"\n(?=  [A-Za-z0-9_]+:\n)", "\n" + body):
        name = re.match(r"\s*([A-Za-z0-9_]+):\n", entry)
        src = re.search(r"^    source: (\w+)", entry, re.M)
        ver = re.search(r'^    version: "([^"]+)"', entry, re.M)
        if name and src and ver and src.group(1) == "hosted":
            out.append((name.group(1), ver.group(1)))
    return out


def query(pkgs: list[tuple[str, str]]) -> list[list[str]]:
    payload = {"queries": [{"package": {"name": n, "ecosystem": "Pub"}, "version": v} for n, v in pkgs]}
    req = urllib.request.Request("https://api.osv.dev/v1/querybatch", data=json.dumps(payload).encode(), headers={"Content-Type": "application/json"})
    res = json.load(urllib.request.urlopen(req, timeout=60))
    return [[v["id"] for v in r.get("vulns", [])] for r in res["results"]]


def main() -> int:
    try:
        pkgs = parse_lock(open(sys.argv[1], encoding="utf-8").read())
        found = query(pkgs)
    except Exception as exc:  # noqa: BLE001
        print(f"ERROR: {type(exc).__name__}: {exc}")
        return 2
    bad = [(p, ids) for p, ids in zip(pkgs, found) if ids]
    print(f"checked {len(pkgs)} hosted packages; {len(bad)} with advisories")
    for (n, v), ids in bad:
        print(f"  {n} {v}: {', '.join(ids)}")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
