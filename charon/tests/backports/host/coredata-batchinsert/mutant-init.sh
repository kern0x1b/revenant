#!/bin/sh
# The mutant for NSBatchInsertRequest: -init stops raising, and the per-initialiser listing must
# go red BECAUSE OF THAT and not because the mutant failed to build.
#
#   ./mutant-init.sh
#
# No tracked file is touched. The port's source is COPIED into a scratch directory under
# .agent-work/runs/mutant-init/, the copy is mutated by mutant-init.py, the copy is built, and the
# listing is run on the copy and diffed against the committed host reference. Two things this
# script checks that a red alone does not:
#
#   - the MUTANT BUILT. A compile failure is not a red: it is the failure mode that made an earlier
#     one-line sed useless, and it is reported as a failure of this script, not as a pass.
#   - the differing line is PRINTED, so the red names raised=0 against the reference's raised=1
#     instead of a bare "VERDICT: RED".
set -eu
here=$(cd "$(dirname "$0")" && pwd)
FP=${COREDATA:-$here/../../../../packages/a/apple-backports}
scratch="$here/../../../../.agent-work/runs/mutant-init"
rm -rf "$scratch"; mkdir -p "$scratch"

echo "=== 1. the mutant, and the one statement it replaces"
python3 "$here/mutant-init.py" "$FP/CoreData/NSBatchInsertRequest.m" "$scratch/port.m"

# The copy is for the HOST build, so the import the package's own header needs is gone and the
# class is renamed with -D: nothing links two definitions of NSBatchInsertRequest.
grep -v '#import "CharonCoreData.h"' "$scratch/port.m" > "$scratch/port.buildable.m"
mv "$scratch/port.buildable.m" "$scratch/port.m"

echo
echo "=== 2. the mutant BUILDS - a compile failure is not a red"
if xcrun clang -fobjc-arc -w -DNSBatchInsertRequest=CharonBatchInsertRequest \
       -I"$FP/CoreData" -c "$scratch/port.m" -o "$scratch/port.o"; then
    echo "BUILD OK  (the mutant compiles, so any red below is the behaviour and not the build)"
else
    rc=$?
    echo "BUILD FAILED with exit $rc - this is NOT a red mutant, it is a broken one, and this"
    echo "script fails. A mutant that does not compile proves nothing."
    exit 4
fi

xcrun clang -fobjc-arc -w -DNSBatchInsertRequest=CharonBatchInsertRequest \
    "$here/per-initializer.m" "$scratch/port.o" \
    -framework Foundation -framework CoreData -o "$scratch/perinit"

echo
echo "=== 3. the listing, against the committed host reference"
"$scratch/perinit" > "$scratch/port.txt" 2>/dev/null || true
lines=$(wc -l < "$scratch/port.txt" | tr -d ' ')
if [ "$lines" -lt 20 ]; then
    echo "NO ANSWER: the mutant's run printed $lines line(s) and twenty-two were asked for."
    exit 3
fi
if diff "$here/reference-host.tsv" "$scratch/port.txt" > "$scratch/diff"; then
    echo "MUTANT FAILED: the mutant's listing is IDENTICAL to the host's, so the mutation changed"
    echo "nothing the listing prints, and the check would have been green for the wrong reason."
    exit 2
fi
echo "the differing lines, and the reference's on the left:"
cat "$scratch/diff"
echo
echo "VERDICT: RED - $(wc -l < "$scratch/diff" | tr -d ' ') line(s) differ, and the mutant built"
