#!/bin/sh
# mutation.sh - can the MPSImageStatistics differential fail, and do these mutations make it fail?
#
# A green differential says nothing unless it CAN be red, so each of this object's claims is defended by
# a mutation that breaks exactly that claim and nothing else. They are the three places where the walk
# could be wrong in a way every case shares, which is why they are the right three and not three
# arbitrary edits:
#
#   extrema-seed  the minimum and the maximum are seeded from +/-INFINITY, so they are answers about the
#                 whole window rather than about whatever value happened to be seen first. Seeding both
#                 from zero answers the first pixel's value twice on any window whose values are not
#                 around zero, which is why two of the three 3x3 sources are negative.
#   variance-form the variance is the mean of the SQUARED DEVIATIONS, sum((x - mean)^2) / count. The form
#                 this replaces it with - the mean of the squares, without subtracting the mean's own
#                 square - is the other thing "the variance" is sometimes written as, and it differs on
#                 every source here.
#   mean-divisor  the count a mean divides by is the count of VALUES read, pixels times channels, and not
#                 the count of pixels. A kernel that divided by the pixel count answers a different
#                 number on exactly the two-channel source and on nothing else, which is why that
#                 source is in the cases at all.
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
work=${MUTATION_BUILD:-$root/.agent-work/runs/host/mpsstatistics-mutation}
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
sites = [("MPSImageStatistics11.m", "extrema-seed"),
         ("MPSImageStatistics11.m", "variance-form"),
         ("MPSImageStatistics11.m", "mean-divisor")]
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

FILE=MPSImageStatistics11.m
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
for site in extrema-seed variance-form mean-divisor; do
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