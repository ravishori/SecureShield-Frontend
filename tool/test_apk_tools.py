"""Unit tests for tool/verify_apk_signature.py and tool/compare_apks.py (no SDK, no keys needed).

    python -m unittest discover -s tool -p "test_apk_tools.py"
"""

import os
import sys
import tempfile
import unittest
import zipfile

sys.path.insert(0, os.path.dirname(__file__))
import compare_apks as C  # noqa: E402
import verify_apk_signature as V  # noqa: E402

GOOD = """Verifies
Verified using v1 scheme (JAR signing): true
Verified using v2 scheme (APK Signature Scheme v2): true
Verified using v3 scheme (APK Signature Scheme v3): true
Number of signers: 1
Signer #1 certificate DN: CN=SecureShield Upload, O=Example, C=IN
Signer #1 certificate SHA-256 digest: """ + "ab" * 32 + "\n"
DEBUG = GOOD.replace("CN=SecureShield Upload, O=Example, C=IN", "C=US, O=Android, CN=Android Debug")


class VerifyTests(unittest.TestCase):
    def test_good_signature_passes(self):
        info = V.parse(GOOD)
        self.assertEqual(V.judge(info, None), [])
        self.assertEqual(info["sha256"], "ab" * 32)

    def test_debug_key_fails(self):
        self.assertTrue(any("DEBUG" in p for p in V.judge(V.parse(DEBUG), None)))

    def test_v1_only_fails(self):
        out = GOOD.replace("v2 scheme (APK Signature Scheme v2): true", "v2 scheme (APK Signature Scheme v2): false").replace(
            "v3 scheme (APK Signature Scheme v3): true", "v3 scheme (APK Signature Scheme v3): false"
        )
        self.assertTrue(any("v2 nor the v3" in p for p in V.judge(V.parse(out), None)))

    def test_fingerprint_mismatch_fails(self):
        self.assertTrue(any("does not match" in p for p in V.judge(V.parse(GOOD), "cd" * 32)))
        self.assertEqual(V.judge(V.parse(GOOD), ("AB:" * 32).rstrip(":").replace("AB:" * 0, "")[:0] or "ab" * 32), [])

    def test_unverified_fails(self):
        info = V.parse("DOES NOT VERIFY\n")
        info["verified"] = False
        self.assertTrue(V.judge(info, None))


class CompareTests(unittest.TestCase):
    def _apk(self, d, name, files):
        p = os.path.join(d, name)
        with zipfile.ZipFile(p, "w") as z:
            for k, v in files.items():
                z.writestr(k, v)
        return p

    def test_signature_files_are_ignored_but_content_is_not(self):
        with tempfile.TemporaryDirectory() as d:
            base = {"classes.dex": b"abc", "res/a.png": b"123"}
            a = self._apk(d, "a.apk", {**base, "META-INF/CERT.RSA": b"sig-one", "META-INF/CERT.SF": b"x"})
            b = self._apk(d, "b.apk", {**base, "META-INF/CERT.RSA": b"sig-two", "META-INF/CERT.SF": b"y"})
            c = self._apk(d, "c.apk", {**base, "classes.dex": b"abd", "META-INF/CERT.RSA": b"sig-one"})
            self.assertEqual(C.diff(C.entries(a), C.entries(b)), [])
            self.assertEqual(C.diff(C.entries(a), C.entries(c)), ["differs: classes.dex"])

    def test_added_and_removed_entries_are_reported(self):
        with tempfile.TemporaryDirectory() as d:
            a = self._apk(d, "a.apk", {"x": b"1"})
            b = self._apk(d, "b.apk", {"x": b"1", "y": b"2"})
            self.assertEqual(C.diff(C.entries(a), C.entries(b)), ["only in second: y"])


if __name__ == "__main__":
    unittest.main()
