"""Unit tests of check_results.py on hand-made results and manifest files, run as a subprocess so that the exit status itself is checked."""

import json
import os
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))


def case(name, result=""):
    body = {"fail": "<failure message='x'/>", "skip": "<skipped/>", "": ""}[result]
    return f"<testcase name='{name}' classname='m'>{body}</testcase>"


class CheckResults(unittest.TestCase):
    def run_check(self, cases, tests, blocked=None, known=None, results_text=None, manifest_text=None, testcase=None):
        with tempfile.TemporaryDirectory() as d:
            results = os.path.join(d, "results.xml")
            manifest = os.path.join(d, "manifest.json")
            if results_text is not False:
                with open(results, "w") as f:
                    f.write(results_text if results_text is not None else "<testsuites><testsuite>" + "".join(cases) + "</testsuite></testsuites>")
            if manifest_text is not False:
                with open(manifest, "w") as f:
                    f.write(manifest_text if manifest_text is not None else json.dumps({"tests": tests, "blocked": blocked or {}}))
            argv = [sys.executable, os.path.join(HERE, "check_results.py"), results, manifest]
            if known is not None:
                with open(os.path.join(d, "known.txt"), "w") as f:
                    f.write(known)
                argv += ["--known", os.path.join(d, "known.txt")]
            env = dict(os.environ)
            env.pop("TESTCASE", None)
            if testcase:
                env["TESTCASE"] = testcase
            p = subprocess.run(argv, capture_output=True, text=True, env=env)
            return p.returncode, p.stdout + p.stderr

    def test_all_pass(self):
        rc, out = self.run_check([case("a"), case("b")], ["a", "b"])
        self.assertEqual(rc, 0, out)
        self.assertIn("PASS=2", out)

    def test_unlisted_failure(self):
        rc, out = self.run_check([case("a"), case("b", "fail")], ["a", "b"])
        self.assertEqual(rc, 1)
        self.assertIn("FAIL     b", out)

    def test_listed_failure_is_xfail(self):
        rc, out = self.run_check([case("a"), case("b", "fail")], ["a", "b"], known="# comment\nb  # why\n")
        self.assertEqual(rc, 0, out)
        self.assertIn("XFAIL    b", out)

    def test_stale_entry_is_xpass(self):
        rc, out = self.run_check([case("a"), case("b")], ["a", "b"], known="b\n")
        self.assertEqual(rc, 1)
        self.assertIn("XPASS    b", out)
        self.assertIn("remove it from the list", out)

    def test_entry_that_is_not_a_test(self):
        rc, out = self.run_check([case("a")], ["a"], known="nonexistent\n")
        self.assertEqual(rc, 1)
        self.assertIn("nonexistent is listed", out)

    def test_blocked_fails_the_command(self):
        rc, out = self.run_check([case("a"), case("b", "skip")], ["a", "b"], blocked={"b": "needs halted"})
        self.assertEqual(rc, 1)
        self.assertIn("BLOCKED  b", out)
        self.assertIn("needs halted", out)

    def test_blocked_test_run_anyway_stays_blocked(self):
        rc, out = self.run_check([case("b")], ["b"], blocked={"b": "needs halted"})
        self.assertEqual(rc, 1)
        self.assertIn("ran anyway and passed", out)

    def test_listed_and_blocked(self):
        rc, out = self.run_check([case("b", "skip")], ["b"], blocked={"b": "needs halted"}, known="b\n")
        self.assertEqual(rc, 1)
        self.assertIn("claims a failure nobody saw", out)

    def test_unexpected_skip(self):
        rc, out = self.run_check([case("a"), case("b", "skip")], ["a", "b"])
        self.assertEqual(rc, 1)
        self.assertIn("skipped without a recorded reason", out)

    def test_missing_result_for_registered_test(self):
        rc, out = self.run_check([case("a")], ["a", "b"])
        self.assertEqual(rc, 1)
        self.assertIn("b is registered but has no result", out)

    def test_selected_testcase_needs_no_other_results(self):
        rc, out = self.run_check([case("a")], ["a", "b"], testcase="a")
        self.assertEqual(rc, 0, out)

    def test_result_not_in_manifest(self):
        rc, out = self.run_check([case("a"), case("c")], ["a"])
        self.assertEqual(rc, 1)
        self.assertIn("c has a result but is not in the manifest", out)

    def test_empty_suite(self):
        rc, out = self.run_check([], [])
        self.assertEqual(rc, 1)
        self.assertIn("no test ran", out)

    def test_missing_results_file(self):
        rc, out = self.run_check([], ["a"], results_text=False)
        self.assertEqual(rc, 1)
        self.assertIn("cannot read results", out)

    def test_malformed_results_file(self):
        rc, out = self.run_check([], ["a"], results_text="<testsuites><testcase name='a'>")
        self.assertEqual(rc, 1)
        self.assertIn("cannot read results", out)

    def test_missing_manifest(self):
        rc, out = self.run_check([case("a")], ["a"], manifest_text=False)
        self.assertEqual(rc, 1)
        self.assertIn("cannot read manifest", out)

    def test_malformed_manifest(self):
        rc, out = self.run_check([case("a")], ["a"], manifest_text="{\"tests\": [")
        self.assertEqual(rc, 1)
        self.assertIn("cannot read manifest", out)


if __name__ == "__main__":
    unittest.main()
