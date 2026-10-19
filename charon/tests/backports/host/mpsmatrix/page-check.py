#!/usr/bin/env python3
"""page-check.py - every figure a document states about the last run, against that run.

A facts file that quotes a count is a claim, and a claim that a later run can falsify without anybody
noticing is not one anybody should make. The three figures the MPSImage/MPSMatrix pages state about the
mpsmatrix differential - the number of cases compared, the three grades, and the two distances that
bound the 64-unit threshold - are read out of the grader's own output here and compared with what the
page says. A figure that does not match fails the check and names both values, so a page cannot drift
away from its run without a red line.

    page-check.py <run-dir> <page> [page ...]

<run-dir> is where run.sh left system.prefix and port.prefix. The grader's verdict is recomputed here
rather than read from a log, so a page cannot be checked against a transcript that has since been
overwritten: this is the same arithmetic over the same two files, and it is a check that examined
nothing if either file is missing.
"""
import collections
import os
import re
import struct
import sys


def cases(path):
    out = []
    for line in open(path):
        if not line.startswith("case "):
            continue
        f = line.split()
        if len(f) < 4:
            continue
        out.append((" ".join(f[1:-2]), int(f[-2]), f[-1]))
    return out


def ordered(bits):
    v = struct.unpack("<I", bits)[0]
    if v < 0x80000000:
        return v
    return 0x80000000 - (v - 0x80000000) - 1 + 0x80000000


def measure(rundir, bound):
    system = cases(os.path.join(rundir, "system.prefix"))
    port = cases(os.path.join(rundir, "port.prefix"))
    n = min(len(system), len(port))
    identical = ulp = non_ulp = 0
    rounding = []            # the ulp distance of every case within the bound
    beyond = []              # the ulp distance of every case outside it
    for i in range(n):
        (sname, slen, shex), (pname, plen, phex) = system[i], port[i]
        if sname != pname or slen != plen:
            non_ulp += 1
            beyond.append((1 << 30, sname))
            continue
        if shex == phex:
            identical += 1
            continue
        worst = 0
        for k in range(0, slen, 4):
            sb = bytes.fromhex(shex[2 * k:2 * k + 8])
            pb = bytes.fromhex(phex[2 * k:2 * k + 8])
            if sb != pb:
                worst = max(worst, abs(ordered(sb) - ordered(pb)))
        if worst <= bound:
            ulp += 1
            rounding.append((worst, sname))
        else:
            non_ulp += 1
            beyond.append((worst, sname))
    return dict(compared=n, identical=identical, ulp=ulp, non_ulp=non_ulp,
                largest_rounding=max(rounding) if rounding else None,
                smallest_beyond=min(beyond) if beyond else None)


# (which figure of the run, and how the page writes it). A page that writes none of these states no
# figure about the run, and a check that examined nothing fails.
CLAIMS = [
    ("compared", r"compared: (\d+) cases"),
    (("identical", "ulp", "non_ulp"),
     r"identical: (\d+)\s+ulp \(bound \d+\): (\d+)\s+non-ulp: (\d+)"),
    ("largest_rounding", r"rounding is \*\*(\d+)\*\*"),
    ("smallest_beyond", r"that are not is \*\*(\d+)\*\*"),
]


# A registry effect that names the cases a family does not reproduce has to name exactly the ones the
# run found, by their own names: an ordinal ("the seventh case") is a position in a transcript that any
# later case moves, and a count written by hand is a number no run checks.
EFFECT_CLAIM = re.compile(r"`(fully-connected \d+)`")


def check_effect(rundir, bound, registry, bad):
    import json
    doc = json.load(open(registry))
    entries = doc["entries"] if isinstance(doc, dict) else doc
    row = [e for e in entries if e["api"] == "MPSMatrixFullyConnected" and e.get("effect")]
    if not row:
        print("  FAIL  %s: no implemented MPSMatrixFullyConnected row carries an effect" % registry)
        return bad + 1
    said = set()
    for m in EFFECT_CLAIM.finditer(row[0]["effect"]):
        said.add(m.group(1))
    system = cases(os.path.join(rundir, "system.prefix"))
    port = cases(os.path.join(rundir, "port.prefix"))
    n = min(len(system), len(port))
    beyond = set()
    for i in range(n):
        (sname, slen, shex), (_, _, phex) = system[i], port[i]
        if sname != "fully-connected" and not sname.startswith("fully-connected "):
            continue
        if shex == phex:
            continue
        worst = 0
        for k in range(0, slen, 4):
            sb = bytes.fromhex(shex[2 * k:2 * k + 8])
            pb = bytes.fromhex(phex[2 * k:2 * k + 8])
            if sb != pb:
                worst = max(worst, abs(ordered(sb) - ordered(pb)))
        if worst > bound:
            beyond.add(sname)
    if said == beyond:
        print("  ok    %s: MPSMatrixFullyConnected names %s, which is what the run found"
              % (registry, ", ".join(sorted(said))))
        return bad
    print("  FAIL  %s: the effect names %s and the run's non-ulp fully-connected cases are %s"
          % (registry, ", ".join(sorted(said)) or "none", ", ".join(sorted(beyond)) or "none"))
    return bad + 1


def main(argv):
    if len(argv) < 3:
        sys.stderr.write(__doc__)
        return 2
    rundir = argv[1]
    pages = argv[2:]
    for name in ("system.prefix", "port.prefix"):
        if not os.path.exists(os.path.join(rundir, name)):
            sys.stderr.write("page-check: %s is not there, so nothing was measured and this check "
                             "cannot pass\n" % os.path.join(rundir, name))
            return 2
    bound = None
    for page in pages:
        text = open(page).read()
        m = re.search(r"ulp \(bound (\d+)\):", text)
        if m:
            bound = int(m.group(1))
            break
    if bound is None:
        sys.stderr.write("page-check: no page states the ulp bound the figures were measured against\n")
        return 2
    run = measure(rundir, bound)
    print("measured over %s: compared %d, identical %d, ulp(bound %d) %d, non-ulp %d"
          % (rundir, run["compared"], run["identical"], bound, run["ulp"], run["non_ulp"]))
    if run["largest_rounding"]:
        print("  the largest distance among the cases that are rounding: %d, in %s"
              % (run["largest_rounding"][0], run["largest_rounding"][1]))
    if run["smallest_beyond"]:
        print("  the smallest distance among the cases that are not:      %d, in %s"
              % (run["smallest_beyond"][0], run["smallest_beyond"][1]))

    bad = 0
    claims_made = 0
    for page in pages:
        text = open(page).read()
        for key, page_pattern in CLAIMS:
            m = re.search(page_pattern, text)
            if not m:
                continue
            claims_made += 1
            said = m.groups()
            if isinstance(key, tuple):
                mine = tuple(str(run[k]) for k in key)
            elif key in ("largest_rounding", "smallest_beyond"):
                entry = run[key]
                if entry is None:
                    print("  %s: the run has no such case, and the page states %s" % (page, said[0]))
                    bad += 1
                    continue
                mine = (str(entry[0]),)
            else:
                mine = (str(run[key]),)
            if tuple(said) == mine:
                print("  ok    %s: %s = %s" % (page, key, said[0] if len(said) == 1 else mine))
            else:
                print("  FAIL  %s: the page says %s and the run says %s"
                      % (page, tuple(said), mine))
                bad += 1
    for page in pages:
        if page.endswith(".json"):
            bad = check_effect(rundir, bound, page, bad)
            claims_made += 1
    if claims_made == 0:
        print("  FAIL  no figure was checked: a check that examined nothing has to fail")
        return 1
    print("%d figure(s) checked over %d page(s), %d wrong" % (claims_made, len(pages), bad))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
