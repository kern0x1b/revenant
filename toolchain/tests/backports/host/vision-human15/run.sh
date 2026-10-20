#!/bin/sh
# run.sh - VNHumanObservation (15.0), the class the human rectangles request's results are typed as, against the host's own
# Vision, in three parts, each run in two processes (the host's framework, and the port's sources with no framework linked):
#
#   1. the declared surface: surface.tsv, read by the reflection probe of tests/backports/host/vision-results14, line by line
#   2. a fresh object: fresh.m makes one with -init and prints its upper-body flag, bounding box, confidence and selectors
#   3. the plant: a category on the port whose upperBodyOnly answers YES must turn part 2 red
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
appledir=${APPLEDIR:-$here/../../../../packages/frameworks/apple-backports}
build=${BUILD:-$(runs_folder vision-human15)}
mkdir -p "$build"
vision="$appledir/Vision"
[ -f "$vision/VNHumanObservation.m" ] || { echo "no $vision/VNHumanObservation.m"; exit 1; }
libs="-framework Foundation -framework CoreGraphics -framework CoreVideo -framework CoreImage -framework CoreML -framework Accelerate"
reflect="$here/../vision-results14/probe.m"

# part 1: the declared surface
xcrun clang -fobjc-arc -w -framework Foundation -framework Vision "$reflect" -o "$build/surface-host"
xcrun clang -fobjc-arc -w $libs -I"$vision" "$reflect" "$vision/"*.m "$vision/"*.c -o "$build/surface-port"
"$build/surface-host" < "$here/surface.tsv" > "$build/surface-host.txt"
"$build/surface-port" < "$here/surface.tsv" > "$build/surface-port.txt"
if grep -q MISSING "$build/surface-host.txt"; then
    echo "FAIL: the host does not answer a member the headers declare:"; grep MISSING "$build/surface-host.txt" | sed 's/^/    /'; exit 1
fi
if diff "$build/surface-host.txt" "$build/surface-port.txt" > "$build/surface-diff.txt"; then
    echo "port: the $(wc -l < "$here/surface.tsv" | tr -d ' ') declared members of VNHumanObservation are the host's, with their encodings"
else
    echo "FAIL: the surface differs:"; sed 's/^/    /' "$build/surface-diff.txt" | head -20; exit 1
fi

# part 2: a fresh object
xcrun clang -fobjc-arc -w -framework Foundation -framework Vision "$here/fresh.m" -o "$build/fresh-host"
xcrun clang -fobjc-arc -w $libs -I"$vision" "$here/fresh.m" "$vision/"*.m "$vision/"*.c -o "$build/fresh-port"
"$build/fresh-host" > "$build/fresh-host.txt"
"$build/fresh-port" > "$build/fresh-port.txt"
if diff "$build/fresh-host.txt" "$build/fresh-port.txt" > "$build/fresh-diff.txt"; then
    echo "port: a fresh VNHumanObservation answers as the host's: $(tr '\n' ';' < "$build/fresh-host.txt")"
else
    echo "FAIL: a fresh object differs:"; sed 's/^/    /' "$build/fresh-diff.txt"; exit 1
fi

# part 3: the plant
plant="$build/plant-src"
rm -rf "$plant"
mkdir -p "$plant"
cp "$vision/"*.m "$vision/"*.c "$vision/"*.h "$plant/"
cat >> "$plant/VNHumanObservation.m" <<'PLANT'
@implementation VNHumanObservation (RevenantPlant)
- (BOOL)upperBodyOnly { return YES; }
@end
PLANT
xcrun clang -fobjc-arc -w $libs -I"$plant" "$here/fresh.m" "$plant/"*.m "$plant/"*.c -o "$build/plant"
"$build/plant" > "$build/plant.txt"
if diff -q "$build/fresh-host.txt" "$build/plant.txt" > /dev/null; then
    echo "FAIL: the plant was not seen by the comparison"; exit 1
fi
echo "plant: the changed answer is seen: $(diff "$build/fresh-host.txt" "$build/plant.txt" | grep -c '^>') line(s) differ"
