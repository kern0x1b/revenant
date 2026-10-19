#!/usr/bin/env python3
"""
Does classify_swift's coverage branch tell a module that matched nothing from one that matched
something? It is the difference between `undecided` ("nothing on this machine can place this row")
and `missing` ("measured absent, the port has to write it"), and it decides 9801 rows.

The branch reads swift["matched-by-framework"], which only build()'s first pass can fill, because
only that pass knows which rows a framework's own module placed. This checks both halves of that:
a first pass that counts, and a second pass that reads the count.

    python3 selftest-api-ledger-coverage.py

Exit 0 when every check holds. The index here is written by this file, so nothing about the
machine's own modules can make it pass or fail.
"""
import importlib.util
import os
import sys

HERE = os.path.dirname(os.path.realpath(__file__))
spec = importlib.util.spec_from_file_location("api_ledger", os.path.join(HERE, "api-ledger.py"))
ledger = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ledger)

INDEX = {
    "target": "armv7-apple-ios6.1.3",
    "modules": {"Demo": {"Declared": "TypeNominal", "placed(_:)": "Function",
                         "alsoDeclared": "TypeNominal"}},
    "sources": {"Demo": {"owner": "selftest"}},
    "conformances": {}, "references": {},
}
PATH = os.path.join(os.environ.get("TMPDIR", "/tmp"), "selftest-swift-modules.json")
with open(PATH, "w", encoding="utf-8") as f:
    import json
    json.dump(INDEX, f)

failures = []


def check(what, got, want):
    if got == want:
        print("ok   %s" % what)
    else:
        print("FAIL %s\n       got  %r\n       want %r" % (what, got, want))
        failures.append(what)


swift = ledger.load_swift_modules(PATH)

# A row the module declares, and one it does not. Both are of framework Demo, which is also the
# name of the only module, so both reach the coverage branch or the implemented answer above it.
placed = {"kind": "class", "lang": "swift", "api": "Declared", "framework": "Demo"}
absent = {"kind": "class", "lang": "swift", "api": "NotDeclared", "framework": "Demo"}

check("load_swift_modules counts each module's declarations",
      swift["declaration-count"], {"Demo": 3})
check("a name the module declares is implemented",
      ledger.classify_swift("Declared", placed, swift)[0], "implemented")
check("a name no module declares, before the count is filled, stays undecided",
      ledger.classify_swift("NotDeclared", absent, swift)[0], "undecided")

# What build() does: one pass that counts, then the rows that took the branch again.
matched = {}
rows = [placed, absent]
results = [(r,) + ledger.classify_swift(r["api"], r, swift, matched) for r in rows]
check("the first pass counts the framework's own module", matched, {"Demo": 1})

# The shipped loop, not a copy of it: build() calls resolve_swift_coverage on exactly this shape.
again = ledger.resolve_swift_coverage(results, swift, matched)
check("the second pass has exactly one row to re-classify", again, 1)
check("with the count filled, the absent name is measured missing, not undecided",
      results[1][1], "missing")
check("and it says what is left to do", results[1][4], "code")
check("the reason names the module and what it declared",
      "module Demo, which declares 3 names and 1 of" in results[1][2], True)
check("the row the module declares is untouched", results[0][1], "implemented")

# A framework whose module placed nothing keeps the coverage answer: 0 matched is not evidence of
# a gap, it is evidence that the module does not cover the framework at all.
other = {"kind": "class", "lang": "swift", "api": "NotDeclared", "framework": "Other"}
nocover = [(other,) + ledger.classify_swift(other["api"], other, swift)]
check("a framework no module placed is not re-classified",
      ledger.resolve_swift_coverage(nocover, swift, matched), 0)
check("and stays undecided", nocover[0][1], "undecided")

os.unlink(PATH)
print("\n%d checks, %d failures" % (8 + len(failures), len(failures)))
sys.exit(1 if failures else 0)