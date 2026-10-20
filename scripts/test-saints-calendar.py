#!/usr/bin/env python3
"""Offline parser regression checks: python3 scripts/test-saints-calendar.py."""
import importlib.util
from pathlib import Path
import subprocess
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("saints", Path(__file__).with_name("build-saints-calendar.py"))
saints = importlib.util.module_from_spec(spec)
spec.loader.exec_module(saints)


class SaintsImportTests(unittest.TestCase):
    def read(self, key, html, names=None):
        index = {key: {"linked": True, "names": names or []}}
        with patch.object(saints, "fetch", return_value=html):
            return saints.read_byzantine_day(key, Path("/unused"), index)[1]

    def test_service_headings_end_biography_even_in_unclosed_blockquote(self):
        rows = self.read("12-31", """<h1>December 31</h1><blockquote>
            <p><strong>Melany</strong> Lived in Jerusalem.</p>
            <h2>At Vespers</h2><p><strong>Tone 2</strong> A hymn.</p></blockquote>""")
        self.assertEqual([row["name"] for row in rows], ["Melany"])
        self.assertEqual(rows[0]["_description"], "Lived in Jerusalem.")

    def test_alternative_spelling_is_one_saint_group(self):
        rows = self.read("08-26", """<h1>August 26</h1><blockquote>
            <p><strong>Adrian and Natalie [</strong><em>or: </em><strong>Natalia]</strong>
            They were married.</p></blockquote>""")
        self.assertEqual(len(rows), 1)
        self.assertIn("Natalia", rows[0]["name"])
        self.assertEqual(rows[0]["_description"], "They were married.")

    def test_index_only_saint_is_not_lost(self):
        rows = self.read("07-17", """<h1>July 17</h1><blockquote>
            <p><strong>Marina</strong> A martyr.</p></blockquote>""",
            ["Marina", "Paul Gojdič"])
        self.assertEqual([row["name"] for row in rows], ["Marina", "Paul Gojdič"])
        self.assertEqual(rows[1]["_description"], "")
        self.assertTrue(rows[1]["sourceURL"].endswith("/index.html"))

    def test_unlinked_existing_day_is_used(self):
        with patch.object(saints, "fetch", return_value="""<h1>October 11</h1>
                <blockquote><p><strong>Philip</strong> A deacon.</p></blockquote>"""):
            rows = saints.read_byzantine_day("10-11", Path("/unused"),
                                            {"10-11": {"linked": False, "names": ["Philip"]}})[1]
        self.assertEqual(rows[0]["_description"], "A deacon.")

    def test_only_confirmed_missing_unlinked_pages_allow_fallback(self):
        index = {"10-12": {"linked": False, "names": ["Martyrs"]}}
        for status, message, expected_fallback in [(22, b"returned error: 404", True),
                                                  (56, b"returned error: 404", True),
                                                  (28, b"timed out", False),
                                                  (22, b"returned error: 503", False)]:
            with self.subTest(status=status, message=message):
                with patch.object(saints, "fetch", side_effect=subprocess.CalledProcessError(
                        status, "curl", stderr=message)):
                    if expected_fallback:
                        rows = saints.read_byzantine_day("10-12", Path("/unused"), index)[1]
                        self.assertEqual(rows[0]["name"], "Martyrs")
                    else:
                        with self.assertRaises(subprocess.CalledProcessError):
                            saints.read_byzantine_day("10-12", Path("/unused"), index)


if __name__ == "__main__":
    unittest.main()
