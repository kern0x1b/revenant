#!/bin/sh
# mutation.sh — can this harness fail, and can the grader rank? One term of the multiply accumulation
# is changed, the run is repeated, and the grader's own counts must move; the revert must move them
# back. A comparison that cannot fail is not a comparison, and one that cannot tell a one-unit
# difference from a 94 %-wrong answer is not a measurement either.
#
# Two things are true of the campaign and both were false of the one it replaces:
#
#   * It mutates a COPY of the library. The copy is made once under .agent-work, the run is pointed at
#     it with MPS=, and every restore is a copy out of a pristine one. No tracked file is written at
#     all: a run interrupted between a mutation and its restore used to leave the tree changed, and a
#     script that can leave the tree changed does not belong on a shared worktree.
#   * Every mutant is named. mutate.sh reads the anchor and the replacement from
#     mutants/<site>.anchor and mutants/<site>.repl, so no shell parses C source and no anchor in this
#     file can fall out of step with the file it names - which is what happened: the inline anchors this
#     replaces had drifted from MPSMatrixBatchNormalization12.m and the campaign could not start.
#
# The count a mutant has to move is the grader's summary line, not a byte-exact count of differing
# cases: that count read 58 before the SoftPlus fix and 58 after it, so a mutant wrong by 94 % did not
# move it. The line carries all three numbers - identical, within the bound, beyond it - and a mutant
# that is a wrong answer moves the third.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../../.." && pwd)
work=${MUTATION_BUILD:-$root/.agent-work/runs/host/mpsmatrix-mutation}
# Beside $work and not inside it: run.sh removes its own build directory at the start of every run, and
# $work is that directory, so a copy kept under it is gone before the first mutant is applied.
mps=$work.mps
pristine=$work.mps.pristine
rm -rf "$mps" "$pristine"
mkdir -p "$mps" "$pristine"
cp "$root/packages/a/apple-backports/MetalPerformanceShaders/"*.m "$mps"/
cp "$root/packages/a/apple-backports/MetalPerformanceShaders/"*.h "$mps"/
cp "$mps"/* "$pristine"/
export MPS="$mps"
echo "mutating a copy: $mps"

MUTANTS_DIR=${MUTANTS_DIR:-$here/mutants}
export MUTANTS_DIR
. "$here/mutate.sh"

restore() { cp "$pristine/$(basename "$1")" "$1"; }

# The grader's own summary line. run.sh's byte-exact "differing cases" count is gone, so a mutant read
# by this line has to move a number that means something.
count() {
    line=$(BUILD="$work" sh "$here/run.sh" 2>&1 | grep -E '^identical: ' | head -1)
    if [ -z "$line" ]; then
        echo "the harness produced no count, so the copy does not build or the run failed:" >&2
        return 1
    fi
    printf '%s\n' "$line"
}

# One campaign: name a site, count, mutate, count, restore, count. All three counts are printed and the
# middle one has to differ from the other two.
campaign_run() {
    _what=$1; _file=$2; _site=$3
    _before=$(count)
    mutate "$_file" "$_site" || return 1
    _during=$(count)
    restore "$_file"
    _after=$(count)
    printf '%-26s before   %s\n' "$_what" "$_before"
    printf '%-26s mutated  %s\n' "$_what" "$_during"
    printf '%-26s reverted %s\n' "$_what" "$_after"
    if [ "$_before" = "$_during" ] || [ "$_during" = "$_after" ]; then
        echo "the $_what mutation did not move the graded count; the harness is not measuring the library" >&2
        return 1
    fi
}

# How much of the campaign to run. Every mutant costs three full harness runs, and each run compiles
# the 50 sources twice, so the ten-site campaign is about fifty minutes: CAMPAIGN=one runs one site,
# derivatives runs the two the review found, all runs every site, and any other value is refused.
campaign=${CAMPAIGN:-all}
case "$campaign" in
    one|derivatives|all) ;;
    *) echo "CAMPAIGN is one of one, derivatives, all; not '$campaign'" >&2; exit 2 ;;
esac

sum=$mps/MPSMatrixSum11.m
forward=$mps/MPSMatrixBatchNormalization12.m
gradient=$mps/MPSMatrixBatchNormalizationGradient12.m
multiply=$mps/MPSMatrixMultiplication10.m
header=$mps/CharonMPS.h

# Every anchor resolved before a single harness run, in one python process, which prints one line per
# site and exits non-zero naming the ones that do not resolve exactly once. A campaign costs three
# full harness runs, so a stale anchor found this way is a second and found the expensive way is forty
# minutes - and the tenth mutant of this campaign used to be found the expensive way. The check reads
# the anchors and the files itself and prints what it compared, so a run that examined nothing cannot
# come back green: it has one line per site and a count at the end, and they are the only way out.
anchor_check() {
    python3 - "$mps" "$MUTANTS_DIR" <<'PYEOF'
import os
import sys
mps, mutants = sys.argv[1], sys.argv[2]
sites = [("MPSMatrixMultiplication10.m", "multiply-accumulation"),
         ("MPSMatrixBatchNormalization12.m", "forward-mean"),
         ("MPSMatrixSum11.m", "sum-transposed-clip"),
         ("MPSMatrixSum11.m", "sum-scale-index"),
         ("MPSMatrixBatchNormalizationGradient12.m", "gradient-per-parameter"),
         ("MPSMatrixSum11.m", "scale-guard-edge-one"),
         ("MPSMatrixSum11.m", "scale-guard-clamp-two"),
         ("MPSMatrixSum11.m", "neuron-application")]
bad = []
for name, site in sites:
    path = os.path.join(mps, name)
    try:
        anchor = open(os.path.join(mutants, site + ".anchor")).read()
    except OSError as e:
        bad.append("%s: no anchor file (%s)" % (site, e))
        print("anchor check: %-26s NO ANCHOR FILE" % site)
        continue
    if anchor.endswith("\n"):
        anchor = anchor[:-1]
    try:
        text = open(path).read()
    except OSError as e:
        bad.append("%s: no source (%s)" % (site, e))
        print("anchor check: %-26s NO SOURCE" % site)
        continue
    n = text.count(anchor)
    print("anchor check: %-26s %d occurrence(s) in %s" % (site, n, name))
    if n != 1:
        bad.append("%s occurs %d times in %s, and a mutation needs exactly one" % (site, n, name))
print("anchor check: %d sites compared, %d not resolving exactly once" % (len(sites), len(bad)))
for line in bad:
    sys.stderr.write(line + "\n")
sys.exit(1 if bad else 0)
PYEOF
}
anchor_check || { echo "the campaign is not startable: an anchor does not resolve exactly once" >&2; exit 1; }

case "$campaign" in
    one)
        campaign_run "multiply accumulation" "$multiply" multiply-accumulation
        ;;
    all)
        campaign_run "multiply accumulation" "$multiply" multiply-accumulation
        campaign_run "forward mean" "$forward" forward-mean
        campaign_run "sum transposed clip" "$sum" sum-transposed-clip
        campaign_run "sum scale index" "$sum" sum-scale-index
        campaign_run "gradient per-parameter" "$gradient" gradient-per-parameter
        campaign_run "scale guard, edge" "$sum" scale-guard-edge-one
        campaign_run "scale guard, clamp" "$sum" scale-guard-clamp-two
        campaign_run "neuron application" "$sum" neuron-application
        ;;
esac

if [ "$campaign" = derivatives ]; then campaign_end=1; fi

# The two neuron derivatives the review found, and the two that show the grader ranks rather than only
# detects: a mutant wrong by 94 % leaves a byte-exact count of differing cases exactly where it was.
# exp(fabs(b*x)) makes the softplus derivative even where the function is not; the clamp answers 0
# where the release answers the analytic a/((a*x+b) ln c). Both are written here rather than in
# mutants/ because each is a multi-line replacement of a block, and the two files here are the text.
[ "$campaign" = one ] && { echo ""; echo "one site ran: multiply accumulation"; exit 0; }

sp_before=$(count)
sed 's|        double t = b \* x;|        double e = exp(fabs(b * x)); return a * b * (e / (1.0 + e));|' \
    "$header" > "$header.new" && mv "$header.new" "$header"
sp_during=$(count)
restore "$header"
printf '%-26s before   %s\n' "softplus derivative" "$sp_before"
printf '%-26s mutated  %s\n' "softplus derivative" "$sp_during"
lg_before=$(count)
sed 's|        return a / (t \* log(c));|        return t <= 0.0 ? 0.0 : a / (t * log(c));|' \
    "$header" > "$header.new" && mv "$header.new" "$header"
lg_during=$(count)
restore "$header"
hdr_after=$(count)
printf '%-26s before   %s\n' "logarithm derivative" "$lg_before"
printf '%-26s mutated  %s\n' "logarithm derivative" "$lg_during"
printf '%-26s reverted %s\n' "both derivatives" "$hdr_after"
if [ "$sp_before" = "$sp_during" ] || [ "$lg_before" = "$lg_during" ] || [ "$lg_during" = "$hdr_after" ]; then
    echo "a neuron-derivative mutation did not move the graded count" >&2
    exit 1
fi

echo ""
# There is no tenth mutant here, and there was one until 2026-09-29. `metacharacter.anchor` carries
# "EOF / alpha (x) \"q\" $x / EOF alone", and it is the fixture tests/backports/host/mpsmatrix/
# mutate-selftest.sh hands to mutate() to prove the transport survives a delimiter, a quote and a
# dollar; it occurs **nowhere** in the library, so pointing a campaign at it could only fail, and
# `CAMPAIGN=all` did. The property it was standing for is carried twice over without it: three of the
# eight library anchors - forward-mean, neuron-application, sum-scale-index - already hold parentheses,
# and mutate-selftest.sh still tests the transport itself.
echo "the mutants that ran moved the graded counts and their reverts moved them back, in a copy of the"
echo "library and with no tracked file written: the harness can fail, and the grader ranks what it measured"
