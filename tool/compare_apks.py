"""Compare two APKs ignoring the signature files, to check build reproducibility.

    python tool/compare_apks.py a.apk b.apk

Entries under META-INF/ that carry the signature (*.SF, *.RSA, *.DSA, *.EC, MANIFEST.MF) differ between signings and are ignored; every other
entry must have the same name, size and CRC32. Exit 0 = identical content, 1 = differences (listed), 2 = usage error.
NOTE: Flutter/Gradle builds are not guaranteed bit-for-bit reproducible (embedded timestamps, build paths); a mismatch lists exactly what differs.
"""

from __future__ import annotations

import re
import sys
import zipfile

SIG = re.compile(r"^META-INF/(.*\.(SF|RSA|DSA|EC)|MANIFEST\.MF)$", re.IGNORECASE)


def entries(path: str) -> dict[str, tuple[int, int]]:
    with zipfile.ZipFile(path) as z:
        return {i.filename: (i.file_size, i.CRC) for i in z.infolist() if not SIG.match(i.filename) and not i.filename.endswith("/")}


def diff(a: dict, b: dict) -> list[str]:
    out = []
    for name in sorted(set(a) | set(b)):
        if name not in a:
            out.append(f"only in second: {name}")
        elif name not in b:
            out.append(f"only in first: {name}")
        elif a[name] != b[name]:
            out.append(f"differs: {name}")
    return out


def main() -> int:
    if len(sys.argv) != 3:
        print(__doc__)
        return 2
    d = diff(entries(sys.argv[1]), entries(sys.argv[2]))
    for line in d[:50]:
        print(line)
    print(f"{len(d)} difference(s)")
    print("RESULT:", "IDENTICAL" if not d else "DIFFERENT")
    return 0 if not d else 1


if __name__ == "__main__":
    sys.exit(main())
