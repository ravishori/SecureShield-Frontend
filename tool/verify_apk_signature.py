"""Verify that a release APK is signed with a real (non-debug) key and print its public certificate fingerprint.

    python tool/verify_apk_signature.py build/app/outputs/flutter-apk/app-release.apk [--expect-sha256 <hex>]

Exit codes: 0 verified and acceptable, 1 not acceptable (debug key, invalid signature, fingerprint mismatch), 2 tooling error.
Uses `apksigner` from the Android SDK build-tools (ANDROID_HOME / ANDROID_SDK_ROOT / default Windows location). Only public
information (certificate subject and SHA-256 fingerprint) is printed; no key or password is read or shown.
"""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
from pathlib import Path


def find_apksigner() -> Path | None:
    roots = [os.environ.get("ANDROID_HOME"), os.environ.get("ANDROID_SDK_ROOT"), str(Path(os.environ.get("LOCALAPPDATA", "")) / "Android" / "Sdk"), str(Path.home() / "Android" / "Sdk")]
    for root in filter(None, roots):
        bt = Path(root) / "build-tools"
        if not bt.is_dir():
            continue
        versions = sorted((d for d in bt.iterdir() if d.is_dir()), key=lambda d: [int(x) if x.isdigit() else 0 for x in re.split(r"[.\-]", d.name)], reverse=True)
        for v in versions:
            for name in ("apksigner.bat", "apksigner"):
                if (v / name).exists():
                    return v / name
    return None


def parse(output: str) -> dict:
    info: dict = {"verified": "Verifies" in output, "schemes": {}, "dn": None, "sha256": None}
    for m in re.finditer(r"Verified using (v[\d.]+) scheme \(([^)]*)\): (true|false)", output):
        info["schemes"][m.group(1)] = m.group(3) == "true"
    m = re.search(r"Signer #1 certificate DN: (.+)", output)
    info["dn"] = m.group(1).strip() if m else None
    m = re.search(r"Signer #1 certificate SHA-256 digest: ([0-9a-fA-F]{64})", output)
    info["sha256"] = m.group(1).lower() if m else None
    return info


def judge(info: dict, expect_sha256: str | None) -> list[str]:
    problems = []
    if not info["verified"]:
        problems.append("apksigner did not verify the signature")
    if not info["schemes"].get("v2") and not info["schemes"].get("v3"):
        problems.append("neither the v2 nor the v3 signature scheme is verified")
    dn = (info["dn"] or "")
    if not dn:
        problems.append("no signer certificate found")
    if "android debug" in dn.lower():
        problems.append("signed with the Android DEBUG key (CN=Android Debug): not valid for distribution")
    if expect_sha256 and info["sha256"] != expect_sha256.lower().replace(":", ""):
        problems.append("certificate SHA-256 does not match the expected upload-key fingerprint")
    return problems


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("apk")
    ap.add_argument("--expect-sha256")
    args = ap.parse_args()
    apk = Path(args.apk)
    if not apk.is_file():
        print(f"ERROR: {apk} not found")
        return 2
    signer = find_apksigner()
    if signer is None:
        print("ERROR: apksigner not found (set ANDROID_HOME)")
        return 2
    proc = subprocess.run([str(signer), "verify", "--verbose", "--print-certs", str(apk)], capture_output=True, text=True)
    out = proc.stdout + proc.stderr
    info = parse(out if proc.returncode == 0 else out)
    info["verified"] = proc.returncode == 0
    print(f"APK: {apk}")
    print(f"signature verifies: {info['verified']}  schemes: {info['schemes']}")
    print(f"signer: {info['dn']}")
    print(f"certificate SHA-256: {info['sha256']}")
    problems = judge(info, args.expect_sha256)
    for p in problems:
        print(f"FAIL: {p}")
    print("RESULT:", "PASS" if not problems else "FAIL")
    return 0 if not problems else 1


if __name__ == "__main__":
    sys.exit(main())
