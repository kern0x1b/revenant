#!/bin/sh
# rank-selftest.sh - can rank.py fail, and can it be asked the question its own help asks?
#
# Two things are checked here and neither is the harness's own run, so both are cheap and both are
# exact:
#
#   * the grader answers the **four-argument form** its help documents - `rank.py <system> <port>
#     <bound>` with no owed file - and the three counters it prints then describe the cases that were
#     compared. On 2026-09-29 it did not: a write-only dict was indexed by a name the loop never bound,
#     so the form with no owed file died with UnboundLocalError and the form with one printed a table
#     whose ulp column was always empty. Both are the control below, kept as the failure they were.
#   * the grader still fails when a case is not ulp-level and not named as owed, which is what makes
#     its zero a verdict and not a silence.
#
# The fixture is four cases over a two-word name each, so the name that carries the index is exercised:
#   sum 0       bit-identical
#   neuron 7    bit-identical
#   softmax 1   one unit in the last place apart, and inside a 64-unit bound
#   neuron 15   800 units apart, outside any bound a rounding argument would accept
set -eu
here=$(cd "$(dirname "$0")" && pwd)
work=${SELFTEST_BUILD:-$here/../../../.agent-work/runs/host/mpsmatrix-rank-selftest}
rm -rf "$work"
mkdir -p "$work"
echo "selftest work: $work"

python3 - "$work" <<'PYEOF'
import os
import struct
import sys

work = sys.argv[1]


def hx(x):
    """float32 as the bytes put() prints, little endian, two hex digits each"""
    return "".join("%02x" % b for b in struct.pack("<f", x))


def one_below(x):
    return "".join("%02x" % b for b in struct.pack("<I", struct.unpack("<I", struct.pack("<f", x))[0] - 1))


def line(name, hexes):
    return "case %s %d %s" % (name, 4 * len(hexes), "".join(hexes))


base = [hx(v) for v in (1.0, 2.0, 3.0, 4.0)]
same = [hx(v) for v in (0.5, 0.25, 0.125, 0.0625)]
far_system = [hx(v) for v in (-0.000331588089, 1.0, 2.0, 3.0)]
far_port = [hx(v) for v in (-0.000331564806, 1.0, 2.0, 3.0)]
ulp_system = [hx(v) for v in (0.1, 0.2, 0.3, 0.4)]
ulp_port = [hx(0.1), hx(0.2), hx(0.3), one_below(0.4)]

open(os.path.join(work, "system.prefix"), "w").write("\n".join([
    line("sum 0", base), line("neuron 7", same),
    line("neuron 15", far_system), line("softmax 1", ulp_system)]) + "\n")
open(os.path.join(work, "port.prefix"), "w").write("\n".join([
    line("sum 0", base), line("neuron 7", same),
    line("neuron 15", far_port), line("softmax 1", ulp_port)]) + "\n")
open(os.path.join(work, "owed.tsv"), "w").write("neuron 15\tthe fixture's one case the port does not reproduce\n")
print("fixture: 4 cases, 2 bit-identical, 1 at 1 ulp, 1 at 800")
PYEOF

counters='identical: 2   ulp (bound 64): 1   non-ulp: 1'
fail=0
say() { printf '%s\n' "$*"; }
expect() {
    if printf '%s\n' "$2" | grep -qF -- "$3"; then
        say "  ok    $1"
    else
        say "  FAIL  $1"
        say "        wanted to find: $3"
        say "        got:               $2"
        fail=1
    fi
}

# 1. the documented four-argument form: it must run, and its three counters must describe the fixture
out=$(python3 "$here/rank.py" "$work/system.prefix" "$work/port.prefix" 64 2>&1) && status=0 || status=$?
say "four-argument form, no owed file: exit $status"
if [ "$status" -eq 0 ]; then
    say "  FAIL  the form with no owed file passed, and it cannot: a case is not in the owed file"
    fail=1
else
    say "  ok    it failed, as it must: neuron 15 is not ulp-level and is not named as owed"
fi
expect "the four-argument form prints its three counters" "$out" "$counters"
expect "the four-argument form grades softmax 1 as ulp" "$out" "softmax 1                                  ulp                 1"
expect "the four-argument form grades neuron 15 as non-ulp" "$out" "neuron 15                                  non-ulp           800"
expect "the four-argument form counts the unexplained ones" "$out" "non-ulp cases with no reason in the owed file: 1"
expect "the four-argument form names the unexplained one" "$out" "   neuron 15"

# 2. the same fixture with the case named: the counters must not move and the run must pass
out=$(python3 "$here/rank.py" "$work/system.prefix" "$work/port.prefix" 64 "$work/owed.tsv" 2>&1) && status=0 || status=$?
say "four-argument form plus an owed file: exit $status"
[ "$status" -eq 0 ] || { say "  FAIL  it did not pass with its only non-ulp case named"; fail=1; }
expect "the counters are the same with an owed file" "$out" "$counters"
expect "the named case is printed as owed, with its reason" "$out" "OWED: the fixture's one case the port does not reproduce"

# 3. the control: the 2026-09-29 code, restored, must fail the form this file says is documented. A
#    check of a checker that has never been seen to fail is not a check, so the broken copy is made
#    here and run, and its failure is what this line asserts.
python3 - "$here/rank.py" "$work/rank-before.py" <<'PYEOF'
import sys
src, dst = sys.argv[1], sys.argv[2]
text = open(src).read()
# the two lines the review found, put back where they were
text = text.replace("""    def family_of(case_name):""",
                    """    graded = {}

    def family_of(case_name):""", 1)
text = text.replace("""        if grade == "non-ulp":
            if sname in owed:""",
                    """        graded[name] = (grade, ulp, rel)
        if grade == "non-ulp":
            if sname in owed:""", 1)
if "graded[name]" not in text:
    sys.stderr.write("the control could not be built: the two lines no longer go where the control puts them\n")
    sys.exit(1)
open(dst, "w").write(text)
print("control: the 2026-09-29 form of the grader, with the write-only dict and its assignment restored")
PYEOF
out=$(python3 "$work/rank-before.py" "$work/system.prefix" "$work/port.prefix" 64 2>&1) && status=0 || status=$?
say "the control on the four-argument form: exit $status"
if [ "$status" -eq 0 ]; then
    say "  FAIL  the control passed, so this file would not have caught the bug it exists to catch"
    fail=1
else
    say "  ok    it failed, which is the failure the review reported:"
    printf '%s\n' "$out" | tail -2 | sed 's/^/        /'
fi
# The other half of the control, and the reason the four-argument form is checked on its own: with an
# owed file the broken grader passes and prints the same counters, because the dict the line writes into
# is never read. The defect is invisible there, so a selftest that only ran the five-argument form would
# have been green over it.
out=$(python3 "$work/rank-before.py" "$work/system.prefix" "$work/port.prefix" 64 "$work/owed.tsv" 2>&1) && status=0 || status=$?
say "the control with an owed file: exit $status"
if [ "$status" -ne 0 ]; then
    say "  FAIL  the control failed here too, so the four-argument form is not the only thing this file covers"
    fail=1
else
    say "  ok    it passed with the same counters, which is why the four-argument form is a check of its own"
    printf '%s\n' "$out" | grep -E '^identical:' | sed 's/^/        /'
fi

# 4. and a check that examined nothing has to fail
out=$(python3 "$here/rank.py" "$work/system.prefix" "$work/does-not-exist" 64 "$work/owed.tsv" 2>&1) && status=0 || status=$?
say "a transcript that is not there: exit $status"
[ "$status" -ne 0 ] || { say "  FAIL  a missing transcript came back a pass"; fail=1; }

if [ "$fail" -ne 0 ]; then
    echo "rank-selftest: FAILED"
    exit 1
fi
echo "rank-selftest: 4 checks, the control included, all as they must be"
