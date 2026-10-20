#!/bin/sh
# run.sh - the contour classes of Vision iOS 14 added (VNContour, VNContoursObservation) and their request (VNDetectContoursRequest),
# against the host's own Vision, in two parts, each run in two processes (the host's framework, and the port's sources with no
# framework linked):
#
#   1. the declared surface: surface.tsv, read by the reflection probe of tests/backports/host/vision-results14, line by line
#   2. the detection: probe.m draws seven pictures of white and black and asks VNDetectContoursRequest for their contours, both
#      polarities; every contour's point count, nesting, aspect ratio and every normalised point are compared, numbers to 1e-5
#      (the contours are compared in the canonical sibling order probe.m prints; the release's own sibling order is not reproduced)
#
# Each part has a plant on a scratch copy of the port, which the comparison must see: the aspect ratio's return type (part 1),
# and the direction the contour walk prefers at a diagonal (part 2).
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
appledir=${APPLEDIR:-$here/../../../../packages/frameworks/apple-backports}
build=${BUILD:-$(runs_folder vision-contours14)}
mkdir -p "$build"
vision="$appledir/Vision"
[ -f "$vision/Vision14_0.m" ] || { echo "no $vision/Vision14_0.m"; exit 1; }
libs="-framework Foundation -framework CoreGraphics -framework CoreVideo -framework CoreImage -framework CoreML -framework Accelerate"
reflect="$here/../vision-results14/probe.m"

# numbers.sh-style comparison, in awk: the same field count and each field equal, or both numbers and within 1e-5
same() {
    awk 'FNR==NR { host[FNR] = $0; n = FNR; next }
         { port[FNR] = $0; m = FNR }
         END {
             bad = 0
             if (n != m) { print "line counts differ: host " n ", port " m; exit 1 }
             for (i = 1; i <= n; i++) {
                 a = split(host[i], x, " "); b = split(port[i], y, " ")
                 ok = (a == b)
                 for (k = 1; ok && k <= a; k++) {
                     if (x[k] == y[k]) continue
                     if (x[k] ~ /^-?[0-9.e+-]+$/ && y[k] ~ /^-?[0-9.e+-]+$/ && (x[k] - y[k] < 1e-5) && (y[k] - x[k] < 1e-5)) continue
                     ok = 0
                 }
                 if (!ok) { bad++; if (bad <= 6) print "    line " i ": host [" host[i] "] port [" port[i] "]" }
             }
             print bad
             exit (bad > 0)
         }' "$1" "$2"
}

# part 1: the declared surface
xcrun clang -fobjc-arc -w -framework Foundation -framework Vision "$reflect" -o "$build/surface-host"
xcrun clang -fobjc-arc -w $libs -I"$vision" "$reflect" "$vision/"*.m "$vision/"*.c -o "$build/surface-port"
"$build/surface-host" < "$here/surface.tsv" > "$build/surface-host.txt"
"$build/surface-port" < "$here/surface.tsv" > "$build/surface-port.txt"
if grep -q MISSING "$build/surface-host.txt"; then
    echo "FAIL: the host does not answer a member the headers declare:"; grep MISSING "$build/surface-host.txt" | sed 's/^/    /'; exit 1
fi
if diff "$build/surface-host.txt" "$build/surface-port.txt" > "$build/surface-diff.txt"; then
    echo "port: the $(wc -l < "$here/surface.tsv" | tr -d ' ') declared members of the contour classes are the host's, with their encodings"
else
    echo "FAIL: the surface differs:"; sed 's/^/    /' "$build/surface-diff.txt" | head -20; exit 1
fi

# part 2: the detection
xcrun clang -fobjc-arc -w -framework Foundation -framework CoreGraphics -framework Vision "$here/probe.m" -o "$build/host"
xcrun clang -fobjc-arc -w $libs -I"$vision" "$here/probe.m" "$vision/"*.m "$vision/"*.c -o "$build/port"
"$build/host" > "$build/host.txt"
"$build/port" > "$build/port.txt"
if [ "$(grep -c 'performed=1' "$build/host.txt")" != 14 ]; then
    echo "FAIL: the host did not perform 14 requests"; exit 1
fi
if same "$build/host.txt" "$build/port.txt" > "$build/detect-diff.txt"; then
    echo "port: the contours of the $(grep -c "performed=1" "$build/host.txt") pictures are the host's: $(wc -l < "$build/host.txt" | tr -d ' ') lines, numbers to 1e-5"
else
    echo "FAIL: the contours differ:"; sed "s/^/    /" "$build/detect-diff.txt"; exit 1
fi

# the plants: each is a scratch copy of the port with one change, and the comparison of that copy must be red
plant="$build/plant"
rm -rf "$plant"
mkdir -p "$plant"
cp "$vision/"*.m "$vision/"*.c "$vision/"*.h "$plant/"
sed 's/^- (float)aspectRatio$/- (double)aspectRatio/' "$vision/Vision14_0.m" > "$plant/Vision14_0.m"
if cmp -s "$plant/Vision14_0.m" "$vision/Vision14_0.m"; then
    echo "FAIL: the surface plant did not change the file"; exit 1
fi
xcrun clang -fobjc-arc -w $libs -I"$plant" "$reflect" "$plant/"*.m "$plant/"*.c -o "$build/plant-surface"
"$build/plant-surface" < "$here/surface.tsv" > "$build/plant-surface.txt"
if diff -q "$build/surface-host.txt" "$build/plant-surface.txt" > /dev/null; then
    echo "FAIL: the surface plant was not seen"; exit 1
fi
echo "plant (surface): the changed member is seen: $(diff "$build/surface-host.txt" "$build/plant-surface.txt" | grep -c '^>') line(s) differ"

cp "$vision/RevenantVisionContours.h" "$plant/RevenantVisionContours.h"
sed 's/int candidates\[3\] = {(d + 1) % 4, d, (d + 3) % 4};/int candidates[3] = {(d + 3) % 4, d, (d + 1) % 4};/' "$vision/RevenantVisionContours.h" > "$plant/RevenantVisionContours.h"
if cmp -s "$plant/RevenantVisionContours.h" "$vision/RevenantVisionContours.h"; then
    echo "FAIL: the detection plant did not change the file"; exit 1
fi
xcrun clang -fobjc-arc -w $libs -I"$plant" "$here/probe.m" "$plant/"*.m "$plant/"*.c -o "$build/plant-detect"
"$build/plant-detect" > "$build/plant-detect.txt"
if same "$build/host.txt" "$build/plant-detect.txt" > /dev/null; then
    echo "FAIL: the detection plant was not seen"; exit 1
fi
echo "plant (detection): the changed contours are seen: the comparison is red on the plant"
