#!/bin/sh
# mutation.sh - can the MPSMatrix solve/decomposition differential fail, and do these mutations make it fail?
#
# A green differential says nothing unless it CAN be red, so each of this object's claims is defended by
# a mutation that breaks exactly that claim and nothing else. They are the three places where the walk
# could be wrong in a way every case shares, which is why they are the right three and not three
# arbitrary edits:
#
#   cholesky-order     the factorization walks row r and column c in the ORDER the dependencies allow.
#                      L(r,c) needs L(r,k) and L(c,k) for k < c, so a walk that visits (1,1) before
#                      (1,0) subtracts nothing. This is the defect the first version of this file had,
#                      and the round trip caught it: L came out [2 1 1; 0 2.236 0.447; 0 0 2.449].
#   solves-transpose   the Cholesky solve substitutes through the factor AS STORED and then through its
#                      TRANSPOSE. Reading the stored triangle twice is the other reading of op(A) and it
#                      solves a different system - measured, it answered (1, 0.75, 1.4) for a system
#                      whose solution is (-0.075, 0.75, 1.4).
#   lu-unit-diagonal   L's diagonal is all ones, so the LU solve's forward pass multiplies where the
#                      mutation divides by U's value on that diagonal.
#   lu-singular-status a column with nothing under the diagonal has NO factorization, and the header's
#                      own Singular status (:39) is the answer. Dropping it divides by a zero pivot.
#   cholesky-positive  the Cholesky needs a POSITIVE DEFINITE source (:141-143), so a non-positive pivot
#                      is the header's own status (:40) and not a square root of a negative number.
#
# Every anchor is resolved before the first harness run, in one python process that prints a line per
# site and a count, and exits non-zero naming any that does not resolve exactly once - so a stale anchor
# is found in a second rather than in the middle of a campaign.
#
# The library is copied under .agent-work and the run is pointed at the copy with MPS=, so no tracked
# file is written and a run interrupted between a mutation and its restore leaves the tree alone.
#
#     CAMPAIGN=one|all    one runs one site, all runs every site (the default)
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../../.." && pwd)
work=${MUTATION_BUILD:-$root/.agent-work/runs/host/mpsmatrixsolve-mutation}
mps=$work.mps
pristine=$work.mps.pristine
rm -rf "$mps" "$pristine"
mkdir -p "$mps" "$pristine"
cp "$root/packages/a/apple-backports/MetalPerformanceShaders/"*.m "$mps"/
cp "$root/packages/a/apple-backports/MetalPerformanceShaders/"*.h "$mps"/
cp "$mps"/* "$pristine"/
export MPS="$mps"
echo "mutating a copy: $mps"

MUTANTS_DIR=$here/mutants
export MUTANTS_DIR
restore_file() { cp "$pristine/$1" "$mps/$1"; }

campaign=${CAMPAIGN:-all}
case "$campaign" in
    one|all) ;;
    *) echo "CAMPAIGN is one of one, all; not '$campaign'" >&2; exit 2 ;;
esac

anchor_check() {
    python3 - "$mps" "$MUTANTS_DIR" <<'PYEOF'
import os, sys
mps, mutants = sys.argv[1], sys.argv[2]
sites = [("MPSMatrixSolve11.m", "cholesky-order"),
         ("MPSMatrixSolve11.m", "solves-transpose"),
         ("MPSMatrixSolve11.m", "lu-unit-diagonal"),
         ("MPSMatrixSolve11.m", "lu-singular-status"),
         ("MPSMatrixSolve11.m", "cholesky-positive")]
bad = []
for name, site in sites:
    try:
        anchor = open(os.path.join(mutants, site + ".anchor")).read()
        text = open(os.path.join(mps, name)).read()
    except OSError as e:
        bad.append("%s: %s" % (site, e))
        print("anchor check: %-16s NO FILE (%s)" % (site, e))
        continue
    if anchor.endswith("\n"):
        anchor = anchor[:-1]
    n = text.count(anchor)
    print("anchor check: %-16s %d occurrence(s) in %s" % (site, n, name))
    if n != 1:
        bad.append("%s occurs %d times in %s, and a mutation needs exactly one" % (site, n, name))
print("anchor check: %d sites compared, %d not resolving exactly once" % (len(sites), len(bad)))
for line in bad:
    sys.stderr.write(line + "\n")
sys.exit(1 if bad else 0)
PYEOF
}
anchor_check || { echo "the campaign is not startable: an anchor does not resolve exactly once" >&2; exit 1; }

# The count the run compared. A run that compared nothing is not a green run, and the harness refuses
# that itself; this prints the comparison so the refusal cannot be read as a pass.
count() {
    BUILD="$work" sh "$here/run.sh" 2>&1 | grep -E '^(PASS: |compared )' | tail -2
}

mutate() {
    python3 - "$mps/$1" "$MUTANTS_DIR/$2.anchor" "$MUTANTS_DIR/$2.repl" <<'PYEOF'
import sys
path, anchor_path, repl_path = sys.argv[1], sys.argv[2], sys.argv[3]
anchor = open(anchor_path).read()
repl = open(repl_path).read()
if anchor.endswith("\n"):
    anchor = anchor[:-1]
if repl.endswith("\n"):
    repl = repl[:-1]
text = open(path).read()
n = text.count(anchor)
if n != 1:
    print("the anchor occurs %d times in %s, so the mutation is not startable" % (n, path))
    sys.exit(1)
open(path, 'w').write(text.replace(anchor, repl))
print("mutated %s at %s" % (path.rsplit('/', 1)[-1], sys.argv[3].rsplit('/', 1)[-1]))
PYEOF
}

FILE=MPSMatrixSolve11.m
check_red() {
    site=$1
    # a mutant must make the run RED. The run's own verdict line is what decides, and the comparison is
    # printed so a red that compared nothing cannot be read as a red that caught the mutation.
    # The transcript goes OUTSIDE $work: run.sh does `rm -rf "$build"` on its BUILD directory, so a file
    # written inside it is deleted by the very run whose verdict is being recorded.
    local_text=$work.text
    rm -rf "$local_text"
    mkdir -p "$local_text"
    if BUILD="$work" sh "$here/run.sh" > "$local_text/$site.txt" 2>&1; then
        echo "NOT CAUGHT: $site left the differential GREEN"
        return 1
    fi
    grep -E '^(FAIL: |compared )' "$local_text/$site.txt" | tail -2 | sed "s/^/  $site: /"
    return 0
}

echo "baseline: $(count)"

caught=0
failed=0
for site in cholesky-order solves-transpose lu-unit-diagonal lu-singular-status cholesky-positive; do
    [ "$campaign" = one ] && [ "$failed" -gt 0 ] && break
    restore_file "$FILE"
    mutate "$FILE" "$site"
    if check_red "$site"; then
        echo "caught: $site"
        caught=$((caught + 1))
    else
        failed=$((failed + 1))
    fi
    restore_file "$FILE"
done

# The pristine copy must be green again, or a restore did not happen and the next run inherits a mutant.
restore_file "$FILE"
final=$(count)
echo "restored: $final"
case "$final" in
    *PASS*) ;;
    *) echo "NOT RESTORED: the library is still mutated" >&2; exit 1 ;;
esac

echo "campaign: $caught caught, $failed not caught"
[ "$failed" -eq 0 ] || exit 1