#!/usr/bin/env python3
"""Does the built armv7 module still carry what the facts say it carries?

The corpus is Apple's side: `coordination/corpus/sdk-26.2-surface.tsv` was built by
`corpus-tools/swiftinterface-surface.py` from the 26.2 SDK's own `.swiftinterface` files, and
the same parser reads the `.swiftinterface` the toolchain synthesises out of the module we
built. Both sides are therefore spelled the way the corpus spells them, and a row is covered
when the same (kind, api) pair is declared in both.

The facts file states how many rows are covered and how many are not, broken down by family.
Those numbers were written by hand; this recomputes them and fails on a mismatch, because a
stale number in a facts file is a claim the next round reads as a measurement.

    coverage.py <corpus.tsv> <fork Sources dir> <ours.swiftinterface> --facts <facts.md>

`--apple-sdk` is the 26.2 SDK, read to check that the corpus still describes the Combine
whose rows these are.
"""
import collections
import os
import re
import sys
import importlib.util

# The label each family has in the facts file's table, and the predicate that puts a row in
# it. The label is the join: the facts state a number for each of these, and the check fails
# when a number and a count disagree.
FAMILIES = [
    (("Optional.", "Result."), "optional and result publisher members"),
    (("CombineIdentifier.==", "CombineIdentifier.hash", "CombineIdentifier.hashValue",
      "Subscribers.Demand.==", "Subscribers.Demand.hash", "Subscribers.Demand.hashValue",
      "AnyCancellable.hashValue", "Stride.=="), "witnesses the compiler derives"),
    (("__AsyncSequence_Failure", "__AsyncIteratorProtocol_Failure"),
     "async typealiases the compiler synthesises"),
    (("Record.encode", "Record.init(from:)", "Stride.encode", "Stride.init(from:)"),
     "coding witnesses the compiler synthesises"),
    (("Record.Recording.output", "Record.Recording.completion", "Subscribers.Assign.object"),
     "private(set) accessors where Apple declares a getter"),
    (("Published.wrappedValue",), "Published.wrappedValue"),
]


def family(api):
    for needles, name in FAMILIES:
        if any(api.startswith(n) or n in api for n in needles):
            return name
    return "other"


def stated(facts, pattern):
    """The number the facts file states for `pattern`, or None when it states none."""
    with open(facts) as f:
        for line in f:
            hit = re.search(pattern, line)
            if hit:
                return int(hit.group(1))
    return None


def main():
    args = sys.argv[1:]
    corpus, sources, interface = args[0], args[1], args[2]
    facts = args[args.index("--facts") + 1] if "--facts" in args else None
    apple_sdk = args[args.index("--apple-sdk") + 1] if "--apple-sdk" in args else None

    tool = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "..",
                        "corpus-tools", "swiftinterface-surface.py")
    tool = os.path.expanduser(tool)
    if not os.path.exists(tool):
        tool = os.path.expanduser("~/Git/projects/ios/coordination/corpus-tools/swiftinterface-surface.py")
    spec = importlib.util.spec_from_file_location("sis", tool)
    sis = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(sis)

    problems = []
    ours = list(sis.parse(interface, "Combine", (
        "Combine", "_Concurrency", "_StringProcessing", "_SwiftConcurrencyShims", "Darwin",
        "Swift", "Foundation", "Dispatch"), problems))
    for p in problems:
        print("parse problem: " + p, file=sys.stderr)
    mine = set((r["kind"], r["api"]) for r in ours)

    want = []
    with open(corpus) as f:
        head = f.readline().rstrip("\n").split("\t")
        ci = {n: i for i, n in enumerate(head)}
        for line in f:
            c = line.rstrip("\n").split("\t")
            if c[ci["framework"]] == "Combine":
                want.append((c[ci["kind"]], c[ci["api"]]))
    covered = [r for r in want if r in mine]
    missing = [r for r in want if r not in mine]

    print("corpus rows for Combine: %d" % len(want))
    print("covered by the built armv7 module: %d" % len(covered))
    print("not covered: %d" % len(missing))
    by_kind = collections.Counter(k for k, _ in want)
    got_kind = collections.Counter(k for k, _ in covered)
    for k in sorted(by_kind):
        print("  %-10s %5d / %5d" % (k, got_kind[k], by_kind[k]))

    parts = collections.Counter(family(a) for _, a in missing)
    print("not covered, by family:")
    for _, name in FAMILIES:
        print("  %-52s %5d" % (name, parts[name]))
    if parts["other"]:
        print("  %-52s %5d" % ("other", parts["other"]))
        for _, a in sorted(missing):
            if family(a) == "other":
                print("    " + a)

    if apple_sdk:
        apple_interface = os.path.join(
            apple_sdk, "System/Library/Frameworks/Combine.framework/Modules/"
            "Combine.swiftmodule/arm64e-apple-ios.swiftinterface")
        apple_rows = list(sis.parse(apple_interface, "Combine", (
            "Combine", "_Concurrency", "_StringProcessing", "_SwiftConcurrencyShims", "Darwin",
            "Swift", "Foundation", "Dispatch"), problems))
        apple = set((r["kind"], r["api"]) for r in apple_rows)
        print("the 26.2 SDK's own Combine declares %d of the corpus's rows" % len(apple & set(want)))

    if not facts:
        return 0 if not missing else 1

    # The facts file's table, read by the label each family has there.
    bad = []
    said = {}
    with open(facts) as f:
        for line in f:
            hit = re.match(r"\|\s*([^|*]+?)\s*\|\s*(\d+)\s*\|", line)
            if hit:
                said[hit.group(1).strip().lower()] = int(hit.group(2))
    for _, name in FAMILIES:
        if name.lower() not in said:
            bad.append("the facts file states no number for %r" % name)
        elif said[name.lower()] != parts[name]:
            bad.append("the facts say %d rows for %r, there are %d"
                       % (said[name.lower()], name, parts[name]))
    if "total" in said and said["total"] != len(missing):
        bad.append("the facts' total is %d, there are %d rows not covered"
                   % (said["total"], len(missing)))

    if bad:
        print("the facts file is stale:")
        for b in bad:
            print("  " + b)
        print("  " + facts)
        return 1
    print("the facts file agrees: %d covered, %d not covered" % (len(covered), len(missing)))
    return 0


sys.exit(main())
