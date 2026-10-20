#!/bin/sh
# run.sh - the header-declared surface of the Vision result classes iOS 14 added (the classes in surface.tsv) against the host's
# own Vision, member by member, in two processes: each class's superclass, the type encoding of each method it declares or
# inherits, and the attributes of each property, as the runtime answers.
#
#   1. probe.m is COMPILED against the host's Vision framework (a bare macOS tool) and fed surface.tsv
#   2. the same probe is COMPILED against the port's Vision sources, with no Vision framework linked, and fed the same file
#   3. the two outputs are compared line by line; any member that differs is named
#   4. a plant on a scratch copy of the port's Vision14_0.m - the getter of VNDetectedPoint's confidence given another return
#      type - must turn the comparison red
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
appledir=${APPLEDIR:-$here/../../../../packages/frameworks/apple-backports}
build=${BUILD:-$(runs_folder vision-results14)}
mkdir -p "$build"
vision="$appledir/Vision"
[ -f "$vision/Vision14_0.m" ] || { echo "no $vision/Vision14_0.m"; exit 1; }
libs="-framework Foundation -framework CoreGraphics -framework CoreVideo -framework CoreImage -framework CoreML -framework Accelerate"
members=$(wc -l < "$here/surface.tsv" | tr -d ' ')

xcrun clang -fobjc-arc -w -framework Foundation -framework Vision "$here/probe.m" -o "$build/host"
xcrun clang -fobjc-arc -w $libs -I"$vision" "$here/probe.m" "$vision/"*.m "$vision/"*.c -o "$build/port"
"$build/host" < "$here/surface.tsv" > "$build/host.txt"
"$build/port" < "$here/surface.tsv" > "$build/port.txt"

if [ "$(wc -l < "$build/host.txt" | tr -d ' ')" != "$members" ]; then
    echo "FAIL: the host answered $(wc -l < "$build/host.txt" | tr -d ' ') of $members members"; exit 1
fi
if grep -q "MISSING" "$build/host.txt"; then
    echo "FAIL: the host does not answer a member the headers declare:"; grep MISSING "$build/host.txt" | sed 's/^/    /'; exit 1
fi
if diff "$build/host.txt" "$build/port.txt" > "$build/diff.txt"; then
    echo "port: all $members declared members of the port's result classes are the host's, with their encodings"
else
    echo "FAIL: $(grep -c '^[<>]' "$build/diff.txt") answer(s) differ between the host and the port:"
    sed 's/^/    /' "$build/diff.txt" | head -40
    exit 1
fi

# The plant: VNDetectedPoint's confidence getter returns double instead of VNConfidence, in a scratch copy. The comparison must see it.
plant="$build/plant"
rm -rf "$plant"
mkdir -p "$plant"
cp "$vision/"*.m "$vision/"*.c "$vision/"*.h "$plant/"
sed 's/^- (VNConfidence)confidence$/- (double)confidence/' "$vision/Vision14_0.m" > "$plant/Vision14_0.m"
if cmp -s "$plant/Vision14_0.m" "$vision/Vision14_0.m"; then
    echo "FAIL: the plant did not change the file, so it proves nothing"
    exit 1
fi
xcrun clang -fobjc-arc -w $libs -I"$plant" "$here/probe.m" "$plant/"*.m "$plant/"*.c -o "$build/plant-bin"
"$build/plant-bin" < "$here/surface.tsv" > "$build/plant.txt"
if diff -q "$build/host.txt" "$build/plant.txt" > /dev/null; then
    echo "FAIL: the plant was not seen by the comparison"
    exit 1
fi
echo "plant: the changed member is seen: $(diff "$build/host.txt" "$build/plant.txt" | grep -c '^>') line(s) differ"
