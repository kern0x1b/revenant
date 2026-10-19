#!/usr/bin/env python3
"""
Does api-ledger-swift.py read the same index out of its cache as it reads out of the digester?

The cache is the reader's own, keyed over the module, the digester, the overlay and this file. On a
hit the digester is not run at all, so everything the index records has to come out of the cache
file instead -- the name index AND the conformances, because api-ledger.py places a row naming an
operator Swift synthesises (`X.==`, `X.<`) from a conformance and from nothing else. A hit that
returns the name index and drops the conformances produces an index that places fewer rows than the
run before it, for no stated reason, and the only symptom is a number that looks plausible.

Two runs over the same module and the same cache: the first misses and calls the digester, the
second hits and must not. A stub stands in for the digester and fails loudly if it is called on the
second run, so "the hit path ran" and "the hit path read the whole record" are both observable.

    python3 selftest-api-ledger-swift-cache.py

Exit 0 when every check holds. The module, the digester and the index are all written by this file,
so nothing on this machine can make it pass or fail.
"""
import json
import os
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.realpath(__file__))
TOOL = os.path.join(HERE, "api-ledger-swift.py")

# What the stub writes: one type with two conformances and one member. The conformances are the
# point -- they are what a hit that forgets to merge them throws away.
DUMP = {"ABIRoot": {"kind": "Root", "printedName": "", "children": [
    {"kind": "TypeDecl", "printedName": "Demo",
     "conformances": [{"printedName": "Swift.Equatable"}, {"printedName": "Swift.Comparable"}],
     "children": [{"kind": "Function", "printedName": "placed(x:)", "children": []}]}]}}

STUB = """#!/usr/bin/env python3
import json, os, sys
marker = os.environ["STUB_MARKER"]
out = sys.argv[sys.argv.index("-o") + 1]
with open(marker, "a") as f:
    f.write("called\\n")
if os.environ.get("STUB_MUST_NOT_RUN"):
    sys.stderr.write("the digester ran on a cache hit\\n")
    sys.exit(3)
with open(out, "w") as f:
    json.dump(%s, f)
""" % json.dumps(DUMP)

failures = []


def check(what, got, want):
    if got == want:
        print("ok   %s" % what)
    else:
        print("FAIL %s\n       got  %r\n       want %r" % (what, got, want))
        failures.append(what)


def names_of(entry):
    """The name index of one module, whichever of the two shapes it is stored in."""
    if isinstance(entry, dict) and "names" in entry and isinstance(entry["names"], dict):
        entry = entry["names"]
    return entry


root = tempfile.mkdtemp(prefix="selftest-swift-cache-")
try:
    modules = os.path.join(root, "lib", "swift", "iphoneos")
    binary = os.path.join(modules, "Demo.swiftmodule", "armv7-apple-ios.swiftmodule")
    os.makedirs(os.path.dirname(binary))
    with open(binary, "wb") as f:
        f.write(b"not a real swiftmodule: this reader never looks inside it")
    marker = os.path.join(root, "digester-calls")
    stub = os.path.join(root, "stub-digester")
    with open(stub, "w") as f:
        f.write(STUB)
    os.chmod(stub, 0o755)
    sdk = os.path.join(root, "sdk")
    os.makedirs(sdk)
    vfs = os.path.join(root, "vfs.yaml")
    open(vfs, "w").write("{}\n")

    def run(out, forbid=False):
        env = dict(os.environ, STUB_MARKER=marker)
        if forbid:
            env["STUB_MUST_NOT_RUN"] = "1"
        result = subprocess.run(
            [sys.executable, TOOL, "--out", out, "--sdk", sdk, "--vfs", vfs, "--digester", stub,
             "--module-dirs", "selftest=%s" % modules, "--cache-dir", os.path.join(root, "cache"),
             "--shims-modulemap", os.path.join(root, "no-such-modulemap")],
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, errors="replace", env=env,
            cwd=root)
        with open(os.path.join(out, "swift-modules.json"), encoding="utf-8") as f:
            return result, json.load(f)

    miss_result, miss = run(os.path.join(root, "cold"))
    check("the cold run succeeds", miss_result.returncode, 0)
    check("the cold run called the digester once",
          open(marker).read().count("called"), 1)
    check("the cold run indexed Demo", names_of(miss["modules"]["Demo"]).get("Demo"), "TypeDecl")
    check("the cold run recorded Demo's conformances",
          miss["conformances"].get("Demo"), ["Swift.Comparable", "Swift.Equatable"])

    hit_result, hit = run(os.path.join(root, "warm"), forbid=True)
    check("the warm run succeeds", hit_result.returncode, 0)
    check("the warm run did not call the digester",
          open(marker).read().count("called"), 1)
    check("the warm run indexed Demo", names_of(hit["modules"]["Demo"]).get("Demo"), "TypeDecl")
    check("the warm run's name index is the cold run's",
          names_of(hit["modules"]["Demo"]), names_of(miss["modules"]["Demo"]))
    check("the warm run recorded Demo's conformances",
          hit["conformances"].get("Demo"), ["Swift.Comparable", "Swift.Equatable"])
    check("the warm run's conformances are the cold run's",
          hit["conformances"], miss["conformances"])
    check("the warm run reported no failure", hit["failures"], [])
    check("the warm run recorded the module's source",
          hit["sources"]["Demo"]["owner"], "selftest")

    # A digester that fails is the case this reader exists to report. The run must end with a line
    # in `failures` and an index on disk; it must not raise, because a traceback writes no index at
    # all and a module that would not load becomes invisible rather than reported.
    broken = os.path.join(root, "broken-digester")
    with open(broken, "w") as f:
        f.write("#!/bin/sh\necho 'error: missing required modules' >&2\nexit 1\n")
    os.chmod(broken, 0o755)
    fail_out = os.path.join(root, "failing")
    result = subprocess.run(
        [sys.executable, TOOL, "--out", fail_out, "--sdk", sdk, "--vfs", vfs, "--digester", broken,
         "--module-dirs", "selftest=%s" % modules, "--cache-dir", os.path.join(root, "cache2"),
         "--shims-modulemap", os.path.join(root, "no-such-modulemap")],
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, errors="replace", cwd=root)
    check("a digester that fails does not take the run down", result.returncode, 0)
    check("and no traceback reaches the log", "Traceback" in result.stdout, False)
    written = os.path.join(fail_out, "swift-modules.json")
    if not os.path.exists(written):
        # No index at all: the run died where it was supposed to report. Said as a failure rather
        # than an exception, so the count below is the number of checks that ran.
        check("an index is written even when a module fails", "written", "not written")
        check("the failure is reported in the index", "failures", "failures")
    else:
        check("an index is written even when a module fails", True, True)
        with open(written, encoding="utf-8") as f:
            broken_index = json.load(f)
        check("the failure is reported in the index",
              len(broken_index["failures"]), 1)
        check("and it carries what the digester said",
              "missing required modules" in broken_index["failures"][0], True)
        check("and the module is not indexed as declaring nothing",
              "Demo" in broken_index["modules"], False)
finally:
    shutil.rmtree(root, ignore_errors=True)

print("\n%d checks, %d failures" % (14 + len(failures), len(failures)))
sys.exit(1 if failures else 0)