#!/usr/bin/env python3
"""Checks runtime/int128.c against Python integers: unsigned and signed quotient and remainder of edge
values and random ones of every width. INT128_MIN / -1 is left out, being overflow in C."""
import itertools, os, random, subprocess, sys, tempfile

here = os.path.dirname(os.path.abspath(__file__))
BITS = 128
MASK = (1 << BITS) - 1

def signed(x):
    return x - (1 << BITS) if x >> (BITS - 1) else x

edges = [0, 1, 2, 3, 7, MASK, MASK - 1, 1 << 63, (1 << 63) - 1, (1 << 64), (1 << 64) - 1, (1 << 64) + 1,
         1 << 127, (1 << 127) - 1, (1 << 127) + 1, 1 << 100]
rng = random.Random(20260927)
def random_value():
    return rng.getrandbits(rng.choice([1, 8, 31, 32, 63, 64, 65, 100, 127, 128]))
values = edges + [random_value() for _ in range(int(sys.argv[1]) if len(sys.argv) > 1 else 3000)]
pairs = [(a, b) for a, b in itertools.product(edges, edges) if b] + \
        [(random_value(), random_value() or 1) for _ in range(len(values) * 4)]

def trunc_div(a, b):
    q = abs(a) // abs(b)
    return q if (a < 0) == (b < 0) else -q

lines, expected = [], []
for a, b in pairs:
    for op in "uUdm":
        if op in "dm" and signed(a) == -(1 << 127) and signed(b) == -1:
            continue
        lines.append("%s %016x %016x %016x %016x" % (op, a >> 64, a & (2**64 - 1), b >> 64, b & (2**64 - 1)))
        if op == "u":
            r = a // b
        elif op == "U":
            r = a % b
        elif op == "d":
            r = trunc_div(signed(a), signed(b)) & MASK
        else:
            r = (signed(a) - trunc_div(signed(a), signed(b)) * signed(b)) & MASK
        expected.append("%032x" % r)

with tempfile.TemporaryDirectory() as tmp:
    binary = os.path.join(tmp, "driver")
    subprocess.run(["cc", "-O1", "-w", os.path.join(here, "driver.c"), "-o", binary], check=True)
    got = subprocess.run([binary], input="\n".join(lines) + "\n", capture_output=True, text=True, check=True).stdout.split()
if len(got) != len(expected):
    sys.exit("FAIL: %d results for %d cases" % (len(got), len(expected)))
bad = [(l, e, g) for l, e, g in zip(lines, expected, got) if e != g]
for l, e, g in bad[:5]:
    print("FAIL:", l, "expected", e, "got", g)
print("%d cases, %d wrong" % (len(lines), len(bad)))
sys.exit(1 if bad else 0)
