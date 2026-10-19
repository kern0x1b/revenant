#!/usr/bin/env python3
"""The port's node tables against the QUADPACK originals, element by element.

Reads quadpack-data.txt - the DATA statements of netlib's dqng.f, dqk15.f, dqk21.f, dqk31.f,
dqk41.f, dqk51.f and dqk61.f, verbatim - and either prints the C tables that
packages/a/apple-backports/Accelerate/Quadrature10.m is built from, or with --check compares the
tables that file holds against them and exits nonzero on the first difference it finds.

The two are compared as doubles, not as text: what has to be right is the number, and the C file's
line breaking is its own business.

    python3 tables.py            print the C tables
    python3 tables.py --check    compare, and say what differs
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(HERE, "quadpack-data.txt")
PORT = os.path.join(HERE, "..", "..", "..", "..", "packages", "a", "apple-backports", "Accelerate",
                    "Quadrature10.m")

# The C table name, and the source file and array in quadpack-data.txt it is made of.
TABLES = [
    ("x1", "dqng.f", "x1"),
    ("x2", "dqng.f", "x2"),
    ("x3", "dqng.f", "x3"),
    ("x4", "dqng.f", "x4"),
    ("w10", "dqng.f", "w10"),
    ("w21a", "dqng.f", "w21a"),
    ("w21b", "dqng.f", "w21b"),
    ("w43a", "dqng.f", "w43a"),
    ("w43b", "dqng.f", "w43b"),
    ("w87a", "dqng.f", "w87a"),
    ("w87b", "dqng.f", "w87b"),
    ("k15_wg", "dqk15.f", "wg"),
    ("k15_wgk", "dqk15.f", "wgk"),
    ("k15_xgk", "dqk15.f", "xgk"),
    ("k21_wg", "dqk21.f", "wg"),
    ("k21_wgk", "dqk21.f", "wgk"),
    ("k21_xgk", "dqk21.f", "xgk"),
    ("k31_wg", "dqk31.f", "wg"),
    ("k31_wgk", "dqk31.f", "wgk"),
    ("k31_xgk", "dqk31.f", "xgk"),
    ("k41_wg", "dqk41.f", "wg"),
    ("k41_wgk", "dqk41.f", "wgk"),
    ("k41_xgk", "dqk41.f", "xgk"),
    ("k51_wg", "dqk51.f", "wg"),
    ("k51_wgk", "dqk51.f", "wgk"),
    ("k51_xgk", "dqk51.f", "xgk"),
    ("k61_wg", "dqk61.f", "wg"),
    ("k61_wgk", "dqk61.f", "wgk"),
    ("k61_xgk", "dqk61.f", "xgk"),
]

LITERAL = re.compile(r"-?\d\.\d+(?:[dDeE][-+]?\d+)?")


def data_values():
    """Every table in quadpack-data.txt, as a dict of (file, array) -> values in index order.

    netlib splits a constant's digits across the columns of the original, so all whitespace comes out
    of the block between the slashes before the literal is read.
    """
    source = None
    values = {}
    order = []
    block = None
    for line in open(DATA):
        if line.startswith("# --- "):
            source = line[len("# --- "):].strip()
        m = re.match(r"\s*data\s+(\w+)\s*\(\s*(\d+)\s*\)\s*/(.*)/\s*$", line)
        if not m:
            continue
        arr, first, body = m.group(1).lower(), int(m.group(2)), m.group(3)
        text = re.sub(r"\s+", "", body).replace("d", "e").replace("D", "e").replace("E", "e")
        found = {}
        for i, hit in enumerate(LITERAL.finditer(text)):
            found[first + i] = float(hit.group(0))
        key = (source, arr)
        if key not in values:
            values[key] = {}
            order.append(key)
        values[key].update(found)
    out = {}
    for key in order:
        got = values[key]
        out[key] = [got[k] for k in range(1, max(got) + 1)]
    return out


def port_values():
    """Every table in Quadrature10.m, as a dict of name -> values."""
    src = open(PORT).read()
    out = {}
    for name in re.findall(r"static const double (\w+)\[\d+\] = \{(.*?)\};", src, re.S):
        out[name[0]] = [float(v) for v in re.findall(r"-?\d\.\d+e[-+]\d+", name[1])]
    return out


def main(argv):
    check = "--check" in argv[1:]
    if not os.path.exists(DATA):
        print("missing %s" % DATA)
        return 2
    source = data_values()
    if check:
        if not os.path.exists(PORT):
            print("missing %s" % PORT)
            return 2
        port = port_values()
        bad = 0
        for name, src_file, arr in TABLES:
            want = source[(src_file, arr)]
            got = port.get(name)
            if got is None:
                print("FAIL %s is not in %s" % (name, os.path.basename(PORT)))
                bad += 1
                continue
            if len(got) != len(want):
                print("FAIL %s holds %d values, %s %s has %d" % (name, len(got), src_file, arr, len(want)))
                bad += 1
                continue
            for i, (g, w) in enumerate(zip(got, want)):
                if g != w:
                    print("FAIL %s[%d] is %.32e, %s %s(%d) is %.32e (ratio %.17g)"
                          % (name, i, g, src_file, arr, i + 1, w, g / w if w else float("nan")))
                    bad += 1
        if bad:
            print("%d of the %d tables differ from the DATA statements" % (bad, len(TABLES)))
            return 1
        print("all %d tables hold the %d values their DATA statements give" % (len(TABLES), sum(
            len(source[(f, a)]) for _, f, a in TABLES)))
        return 0
    for name, src_file, arr in TABLES:
        values = source[(src_file, arr)]
        body = []
        for i in range(0, len(values), 3):
            body.append("    " + ", ".join("%.32e" % v for v in values[i:i + 3]) + ",")
        print("static const double %s[%d] = {" % (name, len(values)))
        print("\n".join(body))
        print("};")
        print()
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))