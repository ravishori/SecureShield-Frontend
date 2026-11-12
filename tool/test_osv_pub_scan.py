"""Offline tests for tool/osv_pub_scan.py (the lockfile parser)."""

import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(__file__))
import osv_pub_scan as S  # noqa: E402

LOCK = '''# generated
packages:
  dio:
    dependency: "direct main"
    description:
      name: dio
      sha256: abc
      url: "https://pub.dev"
    source: hosted
    version: "5.7.0"
  flutter:
    dependency: "direct main"
    description: flutter
    source: sdk
    version: "0.0.0"
  intl:
    dependency: transitive
    description:
      name: intl
      sha256: def
      url: "https://pub.dev"
    source: hosted
    version: "0.20.0"
sdks:
  dart: ">=3.0.0"
'''


class ParseTests(unittest.TestCase):
    def test_only_hosted_packages_are_returned(self):
        self.assertEqual(S.parse_lock(LOCK), [("dio", "5.7.0"), ("intl", "0.20.0")])

    def test_real_lockfile_parses_if_present(self):
        path = os.path.join(os.path.dirname(__file__), "..", "pubspec.lock")
        if os.path.exists(path):
            pkgs = S.parse_lock(open(path, encoding="utf-8").read())
            self.assertGreater(len(pkgs), 50)


if __name__ == "__main__":
    unittest.main()
