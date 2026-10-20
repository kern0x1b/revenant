#!/bin/sh
# run.sh - the coordinate conversions iOS 14 and 15 added to Vision (VNNormalizedPointForImagePoint and the four
# region-of-interest functions) against the host's own Vision, answer by answer, in two processes.
#
#   1. probe.m is COMPILED against the host's Vision framework (a bare macOS tool) and run
#   2. the same probe is COMPILED against the port's Vision sources, with no Vision framework linked, and run
#   3. the two outputs are compared line by line, every double printed to 17 significant digits; any answer that differs is named
#   4. a plant on a scratch copy of the port's Vision15_0.m - one axis swapped in one function - must turn the comparison red
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
appledir=${APPLEDIR:-$here/../../../../packages/frameworks/apple-backports}
build=${BUILD:-$(runs_folder vision-coordinates15)}
mkdir -p "$build"
vision="$appledir/Vision"
[ -f "$vision/Vision15_0.m" ] || { echo "no $vision/Vision15_0.m"; exit 1; }
libs="-framework Foundation -framework CoreGraphics -framework CoreVideo -framework CoreImage -framework CoreML -framework Accelerate"

xcrun clang -fobjc-arc -w -framework Foundation -framework Vision "$here/probe.m" -o "$build/host"
xcrun clang -fobjc-arc -w $libs -I"$vision" "$here/probe.m" "$vision/"*.m "$vision/"*.c -o "$build/port"
"$build/host" > "$build/host.txt"
"$build/port" > "$build/port.txt"

count=$(wc -l < "$build/host.txt" | tr -d ' ')
if [ "$count" != 566 ]; then
    echo "FAIL: the host printed $count answers, expected 566 (560 conversions: 7 sizes x 5 regions x 8 points, two answers each; then the six barcode symbologies)"
    exit 1
fi
if diff "$build/host.txt" "$build/port.txt" > "$build/diff.txt"; then
    echo "port: all $count answers are the host's, to 17 digits"
else
    echo "FAIL: $(grep -c '^>' "$build/diff.txt") port answer(s) differ from the host's; first:"
    head -6 "$build/diff.txt" | sed 's/^/    /'
    exit 1
fi

# The plant: the y origin of the image-point conversion read from x, in a scratch copy of the folder. The comparison must see it.
plant="$build/plant"
rm -rf "$plant"
mkdir -p "$plant"
cp "$vision/"*.m "$vision/"*.c "$vision/"*.h "$plant/"
sed 's/(regionOfInterest.origin.y + normalizedPoint.y/(regionOfInterest.origin.x + normalizedPoint.y/' "$vision/Vision15_0.m" > "$plant/Vision15_0.m"
if cmp -s "$plant/Vision15_0.m" "$vision/Vision15_0.m"; then
    echo "FAIL: the plant did not change the file, so it proves nothing"
    exit 1
fi
xcrun clang -fobjc-arc -w $libs -I"$plant" "$here/probe.m" "$plant/"*.m "$plant/"*.c -o "$build/plant-bin"
"$build/plant-bin" > "$build/plant.txt"
if diff -q "$build/host.txt" "$build/plant.txt" > /dev/null; then
    echo "FAIL: the plant was not seen by the comparison"
    exit 1
fi
echo "plant: the changed answer is seen: $(diff "$build/host.txt" "$build/plant.txt" | grep -c '^>') line(s) differ"
