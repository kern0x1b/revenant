#!/usr/bin/env python3
"""Ask the pre-repair fixture whether it accepts a tree, using the real script's own hits.

The fixture beside this file holds one function, `what_this_row_should_say`, from the guard as it was
before r4. This program asks it about every implemented row of a registry, computing the hits with
`coverage.py`'s own `subjects` and `tokens` so the two cannot disagree about what is covered - and it
exits 0 **only** if the fixture is satisfied by every row.

That is the r3 bug stated as a fact: the fixture is satisfied by a tree where the covered rows claim
no measurement, and the real guard is not.

    usage: coverage-fixture-check.py <fixture.py> <coverage.py> <registry.json>
"""
import importlib.util
import json
import os
import re
import sys


def load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main(argv):
    if len(argv) != 3:
        sys.exit("usage: coverage-fixture-check.py <fixture.py> <coverage.py> <registry.json>")
    fixture_path, coverage_path, registry = argv
    fixture = load(fixture_path, "charon_coverage_guard_pre_repair")
    coverage = load(coverage_path, "charon_coverage")

    checks = coverage.subjects(coverage.DIFFERENTIAL)
    rows = [e for e in json.load(open(registry, encoding="utf-8"))["entries"]
            if e.get("status") == "implemented"]
    satisfied = 0
    unsatisfied = []
    for entry in rows:
        # the hit the r3 script built: the token in slot 0, which is what made the covered branch dead
        hit = None
        for token in coverage.tokens(entry["api"]):
            for number, subject in checks:
                if token.lower() in subject.lower():
                    hit = (token, number, subject)
                    break
            if hit:
                break
        if hit is None:
            hit = ("decl only", None, None)
        said = entry.get("source", "")
        should = fixture.what_this_row_should_say(hit)
        if said == should:
            satisfied += 1
        else:
            unsatisfied.append((entry["api"], said, should))
    print("%d of %d rows the pre-repair guard accepts" % (satisfied, len(rows)))
    for api, said, should in unsatisfied[:3]:
        print("  %s\n    says: %s\n    the fixture expects: %s" % (api[:64], said[:100], should[:100]))
    return 0 if not unsatisfied else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
