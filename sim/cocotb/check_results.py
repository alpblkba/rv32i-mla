"""Judges one cocotb run and exits nonzero on anything that is not a clean result.

Usage: check_results.py RESULTS MANIFEST [--known FILE] [--coverage CSV --out CSV]

RESULTS is the results file cocotb writes. MANIFEST is the JSON file the test module writes at import, with every test it registered and the reason each blocked test cannot run on this DUT. FILE is known_failures.txt, one test name per line, # starting a comment.

Each test gets one status. PASS and XFAIL (a listed test that ran and failed) are clean. FAIL (an unlisted failure), XPASS (a listed test that passed, so the list is stale) and BLOCKED (a test this DUT cannot run, so nothing was verified) are not. A missing or malformed file, a run with no test, a skip without a recorded reason, a listed name the manifest does not know, a listed test that is blocked, and a registered test without a result in a run without TESTCASE are errors too. cocotb 1.9 leaves make with status 0 when a test fails, so this script is what makes a failure fail the command.

With --coverage, the inventory gets a status column and is written to --out.
"""

import csv
import json
import os
import sys
import xml.etree.ElementTree as ET


def judge(results, manifest, known_path=None, testcase=None):
    """Returns (statuses, errors), statuses mapping each test that has a result to its status."""
    errors = []
    try:
        with open(manifest) as f:
            data = json.load(f)
        registered, blocked = data["tests"], data["blocked"]
    except (OSError, ValueError, KeyError, TypeError) as e:
        return {}, [f"cannot read manifest {manifest}: {e}"]
    known = set()
    if known_path:
        try:
            with open(known_path) as f:
                known = {line.split("#")[0].strip() for line in f} - {""}
        except OSError as e:
            return {}, [f"cannot read {known_path}: {e}"]
    for name in sorted(known - set(registered)):
        errors.append(f"{name} is listed in {known_path} but is not a test")
    try:
        cases = list(ET.parse(results).iter("testcase"))
    except (OSError, ET.ParseError) as e:
        return {}, errors + [f"cannot read results {results}: {e}"]
    if not cases:
        errors.append(f"no test ran ({results})")

    statuses = {}
    for case in cases:
        name = case.get("name")
        failed = case.find("failure") is not None or case.find("error") is not None
        if name not in registered:
            errors.append(f"{name} has a result but is not in the manifest")
        if name in statuses:
            errors.append(f"{name} has two results")
        if name in blocked:
            ran = "" if case.find("skipped") is not None else (", ran anyway and failed" if failed else ", ran anyway and passed")
            statuses[name] = "BLOCKED"
            errors.append(f"{name} is blocked: {blocked[name]}{ran}")
            if name in known:
                errors.append(f"{name} is listed in {known_path} but is blocked, so the list claims a failure nobody saw")
        elif case.find("skipped") is not None:
            statuses[name] = "SKIPPED"
            errors.append(f"{name} was skipped without a recorded reason")
        elif failed:
            statuses[name] = "XFAIL" if name in known else "FAIL"
            if name not in known:
                errors.append(f"{name} failed")
        else:
            statuses[name] = "XPASS" if name in known else "PASS"
            if name in known:
                errors.append(f"{name} passed but is listed in {known_path}; remove it from the list")
    if not testcase:
        for name in registered:
            if name not in statuses:
                errors.append(f"{name} is registered but has no result")
    return statuses, errors


def main(argv):
    args = argv[1:]
    opts = {}
    for flag in ("--known", "--coverage", "--out"):
        if flag in args:
            i = args.index(flag)
            opts[flag] = args[i + 1]
            del args[i:i + 2]
    results, manifest = args
    statuses, errors = judge(results, manifest, opts.get("--known"), os.environ.get("TESTCASE"))
    for name, status in statuses.items():
        print(f"{status:8} {name}")
    counts = {s: list(statuses.values()).count(s) for s in ("PASS", "FAIL", "XFAIL", "XPASS", "BLOCKED", "SKIPPED")}
    print(" ".join(f"{s}={n}" for s, n in counts.items()))
    if "--coverage" in opts:
        with open(opts["--coverage"]) as f:
            rows = list(csv.DictReader(f))
        with open(opts["--out"], "w", newline="") as f:
            w = csv.DictWriter(f, fieldnames=list(rows[0]) + ["status"], lineterminator="\n")
            w.writeheader()
            for row in rows:
                w.writerow(dict(row, status=statuses.get(row["test"], "NOT RUN")))
        print(f"coverage with status: {opts['--out']}")
    for e in errors:
        print(f"error: {e}", file=sys.stderr)
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
