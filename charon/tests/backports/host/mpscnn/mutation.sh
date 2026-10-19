#!/bin/sh
# mutation.sh - can the CNN differential fail, and does the port's own image make it fail?
#
# Two assertions are defended here and each is defended with a control, because "the case is green" says
# nothing about whether the case can be red:
#
#   pooling-divisor   the average's divisor is the window's area, and the zero edge mode's hanging
#                     windows are not divided by a smaller number. A divisor one short makes the
#                     padded case differ.
#   image-zero-fill   a fresh image reads as zeros. The port zeroes a texture it made; a mutation that
#                     leaves it with whatever the texture held is the defect a caller sees when an image
#                     is read before it is written.
#
# Every anchor is resolved before the first harness run, in one python process that prints a line per
# site and a count, and exits non-zero naming the ones that do not resolve exactly once: a campaign
# where one site costs three full harness runs should find a stale anchor in a second and not in fifteen
# minutes, and on 2026-09-29 a tenth site in the mpsmatrix campaign was found the expensive way.
#
# The library is copied under .agent-work and the run is pointed at the copy with MPS=, so no tracked
# file is written and a run interrupted between a mutation and its restore leaves the tree alone.
#
#     CAMPAIGN=one|all    one runs one site, all runs every site (the default)
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../../.." && pwd)
work=${MUTATION_BUILD:-$root/.agent-work/runs/host/mpscnn-mutation}
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
import os
import sys
mps, mutants = sys.argv[1], sys.argv[2]
sites = [("MPSCNNPooling10.m", "pooling-divisor"),
         ("MPSImage13.m", "image-zero-fill")]
bad = []
for name, site in sites:
    try:
        anchor = open(os.path.join(mutants, site + ".anchor")).read()
        text = open(os.path.join(mps, name)).read()
    except OSError as e:
        bad.append("%s: %s" % (site, e))
        print("anchor check: %-22s NO FILE (%s)" % (site, e))
        continue
    if anchor.endswith("\n"):
        anchor = anchor[:-1]
    n = text.count(anchor)
    print("anchor check: %-22s %d occurrence(s) in %s" % (site, n, name))
    if n != 1:
        bad.append("%s occurs %d times in %s, and a mutation needs exactly one" % (site, n, name))
print("anchor check: %d sites compared, %d not resolving exactly once" % (len(sites), len(bad)))
for line in bad:
    sys.stderr.write(line + "\n")
sys.exit(1 if bad else 0)
PYEOF
}
anchor_check || { echo "the campaign is not startable: an anchor does not resolve exactly once" >&2; exit 1; }

# The count a mutant has to move, and the sentence that says how many cases the run compared. A run
# that compared nothing is not a green run: the guard in the case file refuses that, and this prints the
# comparison so the refusal cannot be read as a pass.
count() {
    line=$(BUILD="$work" sh "$here/run.sh" 2>&1 | grep -E '^(cases: |differing cases: |compared: )' | tr '\n' ' ')
    if [ -z "$line" ]; then
        echo "the harness produced no count, so the copy does not build or the run refused:" >&2
        return 1
    fi
    printf '%s\n' "$line"
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
    sys.stderr.write("the anchor of %s occurs %d times in %s, and a mutation needs exactly one\n"
                     % (sys.argv[1], n, path))
    sys.exit(1)
open(path, "w").write(text.replace(anchor, repl, 1))
print("mutated: %s" % path)
PYEOF
}

campaign_run() {
    _what=$1; _file=$2; _site=$3
    _before=$(count)
    mutate "$_file" "$_site"
    _during=$(count)
    restore_file "$_file"
    _after=$(count)
    printf '%-20s before   %s\n' "$_what" "$_before"
    printf '%-20s mutated  %s\n' "$_what" "$_during"
    printf '%-20s reverted %s\n' "$_what" "$_after"
    if [ "$_before" = "$_during" ] || [ "$_during" = "$_after" ]; then
        echo "the $_what mutation did not move the comparison; the case is not measuring this port" >&2
        return 1
    fi
}

case "$campaign" in
    one) campaign_run "pooling divisor" MPSCNNPooling10.m pooling-divisor ;;
    all)
        campaign_run "pooling divisor" MPSCNNPooling10.m pooling-divisor
        campaign_run "image zero fill" MPSImage13.m image-zero-fill
        ;;
esac

echo ""
echo "the mutants that ran moved the comparison and their reverts moved it back, in a copy of the library"
echo "and with no tracked file written: the CNN differential can fail, over the port's own MPSImage"
