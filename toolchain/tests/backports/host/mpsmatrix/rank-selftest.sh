#!/bin/sh
# rank-selftest.sh - can rank.lua fail, and can it be asked the question its own help asks?
#
# Two things are checked here and neither is the harness's own run, so both are cheap and both are
# exact:
#
#   * the grader answers the **four-argument form** its help documents - `rank.lua <system> <port>
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
. "$here/../../common/runs.sh" "$here"
work=${SELFTEST_BUILD:-$(runs_folder host/mpsmatrix-rank-selftest)}
rm -rf "$work"
mkdir -p "$work"
echo "selftest work: $work"

runs_xmake l "$here/rank-selftest.lua" fixture "$work"

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

out=$(runs_xmake l "$here/rank.lua" "$work/system.prefix" "$work/port.prefix" 64 2>&1) && status=0 || status=$?
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

out=$(runs_xmake l "$here/rank.lua" "$work/system.prefix" "$work/port.prefix" 64 "$work/owed.tsv" 2>&1) && status=0 || status=$?
say "four-argument form plus an owed file: exit $status"
[ "$status" -eq 0 ] || { say "  FAIL  it did not pass with its only non-ulp case named"; fail=1; }
expect "the counters are the same with an owed file" "$out" "$counters"
expect "the named case is printed as owed, with its reason" "$out" "OWED: the fixture's one case the port does not reproduce"

runs_xmake l "$here/rank-selftest.lua" control "$here/rank.lua" "$work/rank-before.lua" "$runs_checkout/tests/backports/common"
out=$(runs_xmake l "$work/rank-before.lua" "$work/system.prefix" "$work/port.prefix" 64 2>&1) && status=0 || status=$?
say "the control on the four-argument form: exit $status"
if [ "$status" -eq 0 ]; then
    say "  FAIL  the control passed, so this file would not have caught the bug it exists to catch"
    fail=1
else
    say "  ok    it failed, which is the failure the review reported:"
    printf '%s\n' "$out" | tail -2 | sed 's/^/        /'
fi
out=$(runs_xmake l "$work/rank-before.lua" "$work/system.prefix" "$work/port.prefix" 64 "$work/owed.tsv" 2>&1) && status=0 || status=$?
say "the control with an owed file: exit $status"
if [ "$status" -ne 0 ]; then
    say "  FAIL  the control failed here too, so the four-argument form is not the only thing this file covers"
    fail=1
else
    say "  ok    it passed with the same counters, which is why the four-argument form is a check of its own"
    printf '%s\n' "$out" | grep -E '^identical:' | sed 's/^/        /'
fi

out=$(runs_xmake l "$here/rank.lua" "$work/system.prefix" "$work/does-not-exist" 64 "$work/owed.tsv" 2>&1) && status=0 || status=$?
say "a transcript that is not there: exit $status"
[ "$status" -ne 0 ] || { say "  FAIL  a missing transcript came back a pass"; fail=1; }

if [ "$fail" -ne 0 ]; then
    echo "rank-selftest: FAILED"
    exit 1
fi
echo "rank-selftest: 4 checks, the control included, all as they must be"
