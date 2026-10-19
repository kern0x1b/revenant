#!/bin/sh
# mutation.sh - can the MPSNNReduce differential fail, and do these mutations make it fail?
#
# A green differential says nothing unless it CAN be red, so each of this object's three claims is
# defended by a mutation that breaks exactly that claim and nothing else. They are the three places
# where the walk could be wrong in a way the twelve cases share, which is why they are the right three
# and not three arbitrary edits:
#
#   column-start   a COLUMN run starts at its own column's first pixel, not a row stride along. The
#                  first version multiplied by the window's width on both axes, so every column after
#                  the first walked a whole row late and the last two ran off the window; this is the
#                  regression for that, kept because the mistake is one multiplication away from right.
#   feature-step   a FEATURE-CHANNEL run is one pixel across its channels and its step is 0 pixels. With
#                  a step of 1 it walks pixels and channels together, and the first version did.
#   weight-default the weight's DEFAULT is 1.0, which is MPSNNReduce.h:418's own sentence and the one
#                  value this file writes from it. A base that started at anything else changes every
#                  feature-channel sum, so this is the claim a caller reads.
#
# There is a FOURTH claim this file makes that is deliberately NOT in this campaign, and the omission is
# the point: the weight applies to a sum and a mean and NOT to a minimum or a maximum
# (MPSNNReduce.h:414-420). That cannot be observed through the API, because `weight` is declared on
# MPSNNReduceFeatureChannelsSum alone and each kernel is its own object with its own copy of the base's
# storage - so there is no caller that sets a weight and then asks a minimum. A site for it here would
# pass for a reason that has nothing to do with the mutation, which is worse than no site: the campaign
# would report it caught. The scope is instead held by MPSNNReduce16.m's own comment and by the
# reference header, which is where a reader can check it.
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
work=${MUTATION_BUILD:-$root/.agent-work/runs/host/mpsnnreduce-mutation}
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
sites = [("MPSNNReduce16.m", "column-start"),
         ("MPSNNReduce16.m", "feature-step"),
         ("MPSNNReduce16.m", "weight-default")]
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

# All three sites are in the base, not in the twelve concrete classes: column-start and feature-step
# are two lines of the base's -encodeToCommandBuffer:sourceImage:destinationImage:, and weight-default
# is the base's -charon_nnReduceWithDevice:byColumn:byFeatureChannel:operation:. Splitting one object
# into MPSNNReduce16.m (the base) and MPSNNReduce12.m (the twelve concrete classes) moved all three
# into MPSNNReduce16.m, and anchor_check above is what finds that a site moved rather than that a
# mutation is wrong.
FILE=MPSNNReduce16.m
check_red() {
    site=$1
    # a mutant must make the run RED. The run's own exit code is the verdict, and the count line is
    # printed so a red that compared nothing cannot be read as a red that caught the mutation.
    out=$(BUILD="$work" sh "$here/run.sh" 2>&1 || true)
    line=$(printf '%s\n' "$out" | grep -E '^(PASS: |FAIL: )' | head -1)
    compared=$(printf '%s\n' "$out" | grep -oE 'compared [0-9]+ mismatches [0-9]+' | tail -1)
    if [ -z "$line" ]; then
        echo "  $site: NO VERDICT - the copy does not build or the run refused"
        printf '%s\n' "$out" | tail -5
        return 1
    fi
    case "$line" in
        FAIL*) printf '  %-14s %s (%s)\n' "$site" "red, as it must be" "$compared"
               printf '%s\n' "$out" | grep MISMATCH | head -2 | sed 's/^/      /'
               return 0 ;;
        *)    printf '  %-14s %s (%s) -- THE MUTANT WAS NOT CAUGHT\n' "$site" "$line" "$compared"
               return 1 ;;
    esac
}

echo
echo "the unmutated copy, which must be green:"
out=$(count)
printf '  %s\n' "$out"
case "$out" in
    *PASS*) ;;
    *) echo "the unmutated copy is not green, so a red below would prove nothing" >&2; exit 1 ;;
esac

failed=0
for site in column-start feature-step weight-default; do
    if [ "$campaign" = one ] && [ "$site" != "column-start" ]; then
        continue
    fi
    echo
    echo "$site:"
    restore_file "$FILE"
    mutate "$FILE" "$site"
    check_red "$site" || failed=$((failed + 1))
    restore_file "$FILE"
done

echo
if [ "$failed" -ne 0 ]; then
    echo "MUTATION CAMPAIGN FAILED: $failed site(s) were not caught"
    exit 1
fi
echo "MUTATION CAMPAIGN PASSED: every site was caught"
