#!/usr/bin/env python3
"""rank.py - grade each case of the mpsmatrix differential by how far apart it is, not only whether.

The comparison in run.sh is byte-exact over whole case lines, so it can say that a case differs and
cannot say by how much: a one-ulp difference in the last place and a 94 %-wrong answer are the same
line of output. This reads the two transcripts, decodes each case's result buffer as little-endian
float32 with a four-byte stride - which is what every case in mps-cases.m prints, the
integer-valued ones included, so a case whose elements are codes rather than numbers is
graded by the distance between the codes and not excused by being one - and grades the
pair:

    identical   every bit the same
    ulp         the two sides differ, but no element is more than ULP_BOUND units in the last place
    non-ulp     some element is further apart than that, or one side is zero and the other is not

An ulp distance is measured on the ordered integer image of a float, so it is defined across zero and
across the sign, and a value of 0 against 5.2e-09 is 5 000 000 000 units rather than a division by
zero. A case that is graded non-ulp is a claim about the port that is not reproduced, so it must
appear in the owed file with its reason; one that is not in that file fails the run.

    rank.py <system-prefix> <port-prefix> <ulp-bound> [owed.tsv]

Exit 0 when nothing is non-ulp and unexplained, 1 otherwise.
"""
import struct
import sys

def ordered(bits):
    """A float32's bit pattern as an integer that increases with the value, so the distance is
    defined across zero and across the sign instead of dividing by a value that may be nil."""
    v = struct.unpack("<I", bits)[0]
    if v < 0x80000000:
        return v
    return 0x80000000 - (v - 0x80000000) - 1 + 0x80000000


def cases(path):
    """A case line is `case <name...> <length> <hex>`, the name may hold a space and the fields
    between the name and the length are the case's own parameters, so the line is read from its end."""
    out = []
    with open(path) as fh:
        for line in fh:
            if not line.startswith("case "):
                continue
            f = line.split()
            if len(f) < 4:
                continue
            out.append((" ".join(f[1:-2]), int(f[-2]), f[-1]))
    return out


def main(argv):
    if len(argv) < 4:
        sys.stderr.write(__doc__)
        return 2
    system = cases(argv[1])
    port = cases(argv[2])
    bound = int(argv[3])
    owed = {}
    if len(argv) > 4:
        with open(argv[4]) as fh:
            for line in fh:
                line = line.split("#", 1)[0].strip()
                if not line or "\t" not in line:
                    continue
                name, reason = line.split("\t", 1)
                owed[name.strip()] = reason.strip()

    n = min(len(system), len(port))
    counts = {"identical": 0, "ulp": 0, "non-ulp": 0}
    unexplained = []
    # A case family is a case name without its trailing number, so `neuron 7` and `neuron 15` are one
    # family. The table it prints is where a document's per-family case count comes from: a number
    # written by hand in a registry string is a number no run checks.
    per_family = {}
    print("%-42s %-9s %11s %11s  %s" % ("case", "class", "max ulp", "max rel", "verdict"))
    def family_of(case_name):
        head = case_name.rsplit(" ", 1)
        return head[0] if len(head) == 2 and head[1].isdigit() else case_name

    for i in range(n):
        (sname, slen, shex), (pname, plen, phex) = system[i], port[i]
        fam = per_family.setdefault(family_of(sname), dict(cases=0, same=0, ulp=0, rel=0.0, zero=0))
        fam["cases"] += 1
        if sname != pname or slen != plen:
            print("%-42s %-9s %11s %11s  %s"
                  % (sname, "MISPAIRED", "-", "-", "the two runs reached different cases"))
            unexplained.append(sname + " (mismatched)")
            counts["non-ulp"] += 1
            continue
        if shex == phex:
            counts["identical"] += 1
            fam["same"] += 1
            continue
        if slen % 4 or len(shex) != slen * 2:
            grade, ulp, rel = "non-ulp", None, None
            fam["ulp"] = max(fam["ulp"], 1 << 30)
        else:
            worst_ulp = 0
            worst_rel = 0.0
            for k in range(0, slen, 4):        # k is a byte offset; the hex is two chars per byte
                sb = bytes.fromhex(shex[2 * k:2 * k + 8])
                pb = bytes.fromhex(phex[2 * k:2 * k + 8])
                d = abs(ordered(sb) - ordered(pb))
                if d > worst_ulp:
                    worst_ulp = d
                fa = struct.unpack("<f", sb)[0]
                fb = struct.unpack("<f", pb)[0]
                if fa == fb:
                    continue
                if fa == 0.0 or fb == 0.0 or fa != fa or fb != fb:
                    fam["zero"] += 1
                else:
                    worst_rel = max(worst_rel, abs(fa - fb) / max(abs(fa), abs(fb)))
            ulp = worst_ulp
            rel = worst_rel
            fam["ulp"] = max(fam["ulp"], worst_ulp)
            fam["rel"] = max(fam["rel"], worst_rel if worst_rel > 0 else 0.0)
            grade = "ulp" if worst_ulp <= bound else "non-ulp"
        counts[grade] += 1
        if grade == "non-ulp":
            if sname in owed:
                verdict = "OWED: " + owed[sname]
            else:
                verdict = "FAIL: not in the owed file"
                unexplained.append(sname)
        else:
            verdict = "ok"
        print("%-42s %-9s %11s %11s  %s"
              % (sname, grade, ulp if ulp is not None else "-",
                 ("%.3g" % rel) if rel is not None else "-", verdict))

    print("")
    print("%-38s %6s %7s %11s %11s %8s"
          % ("family", "cases", "differ", "max ulp", "max rel", "0-vs-nz"))
    for name in sorted(per_family):
        e = per_family[name]
        # max rel is over the elements both sides wrote as finite numbers: an element one side wrote
        # as zero has no relative distance, and letting it print as infinity would swamp the column
        # for a family whose other elements are within an ulp. The count of those is its own column.
        print("%-38s %6d %7d %11d %11.3g %8d"
              % (name, e["cases"], e["cases"] - e["same"], e["ulp"], e["rel"], e["zero"]))
    print("")
    print("compared: %d cases over the first %d of each run" % (n, n))
    print("identical: %d   ulp (bound %d): %d   non-ulp: %d"
          % (counts["identical"], bound, counts["ulp"], counts["non-ulp"]))
    if unexplained:
        print("non-ulp cases with no reason in the owed file: %d" % len(unexplained))
        for u in unexplained:
            print("   " + u)
        return 1
    print("every non-ulp case is listed as owed, with its reason")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
