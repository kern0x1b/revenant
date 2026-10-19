#!/bin/sh
# run.sh - the body's joints: the port's ARSkeletonDefinition against this Mac's own ARKit.
#
# The host has ARKit (it is in this machine's dyld shared cache, and dlopen by path answers a handle),
# and its ARSkeletonDefinition answers the default two-dimensional definition. So the port's table is
# compared with the host's, name by name and parent by parent, in one process.
#
# The port's class is compiled *into* this harness with the class name renamed, so what runs is the
# port's own code; the host's class is reached through objc_msgSend, so nothing here needs ARKit's
# headers -- they are the iPhoneOS ones and do not compile into a macOS build.
#
# `--mutants` changes one thing at a time in a *copy* of the port's sources under .agent-work and
# requires the run to go red. The checkout is never touched.
#
# What is compared: jointCount, every joint name in order, every parent index in order, and
# `indexForJointName:` for every name in the table plus one that is in none of it -- a harness that
# only ever asked for names in the table could not tell a right answer from a lucky one.

set -eu
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../../../.." && pwd)
ARKit=$repo/packages/a/apple-backports/ARKit
runs=${RUNS:-$repo/.agent-work/runs/arkit-skeleton-host}
mkdir -p "$runs"

renames="-DARSkeletonDefinition=CharonPortARSkeletonDefinition \
         -DARSkeleton=CharonPortARSkeleton \
         -DARSkeleton2D=CharonPortARSkeleton2D \
         -DARSkeletonJointName=CharonPortARSkeletonJointName"

# Two steps, because the port's class is renamed but the host's is not: the port's object is compiled
# on its own with the renames, and the harness is compiled against the two declarations it needs --
# the host's under the name the runtime has it by, the port's under the name it was renamed to.
build() {
    src=$1
    xcrun clang -fobjc-arc -w -O1 $renames -I"$src" -c "$src/ARSkeletonDefinition13.m" -o "$runs/port.o"
    xcrun clang -fobjc-arc -w -O1 -I"$src" -I"$here" \
        "$here/differential.m" "$runs/port.o" \
        -framework Foundation -o "$runs/diff"
}

port() {
    build "$ARKit"
    "$runs/diff"
}

port | tee "$runs/plain.txt"
grep -q '^VERDICT ok' "$runs/plain.txt" || { echo "FAIL: the differential is not green"; exit 1; }
[ "${1:-}" = "--mutants" ] || { echo "ok the joints and their parents are the host's own"; exit 0; }

survived=0
mutant() {
    label=$1; from=$2; to=$3
    copy="$runs/mutant"
    rm -rf "$copy"; mkdir -p "$copy"
    cp "$ARKit/ARSkeletonDefinition13.m" "$ARKit/CharonARKitSkeleton.h" "$copy/"
    python3 - "$copy/ARSkeletonDefinition13.m" "$from" "$to" <<'PY' || { echo "MUTANT NOT APPLIED: $label"; survived=$((survived + 1)); return; }
import sys
path, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
text = open(path).read()
if old not in text:
    sys.exit(1)
open(path, "w").write(text.replace(old, new, 1))
PY
    if build "$copy" >/dev/null 2>&1 && "$runs/diff" > "$runs/mutant.txt" 2>&1 && grep -q '^VERDICT ok' "$runs/mutant.txt"; then
        echo "MUTANT SURVIVED: $label"
        survived=$((survived + 1))
    else
        echo "ok mutant killed: $label"
        grep '^FAIL' "$runs/mutant.txt" 2>/dev/null | head -2 | sed 's/^/    /'
    fi
}

# Two joints swapped: the names are in one order and the harness reads them in another.
mutant "left_forearm and left_hand swapped" \
    '                   @"left_forearm_joint",
                   @"left_hand_joint",' \
    '                   @"left_hand_joint",
                   @"left_forearm_joint",'
# One parent changed: the count still matches and every name is still right, so only the parents can
# see it.
mutant "left_leg's parent is left_upLeg's neighbour" \
    '@11, @12, @0, @0, @(-1)' \
    '@12, @11, @0, @0, @(-1)'

if [ "$survived" -eq 0 ]; then
    echo "ok every mutant is killed: the differential can fail, and it fails for the right reason"
else
    echo "FAIL: $survived mutant(s) survived"
fi
exit "$survived"
