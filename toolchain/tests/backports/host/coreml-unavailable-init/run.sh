#!/bin/sh
# run.sh - the Core ML classes whose headers declare -init and +new NS_UNAVAILABLE (MLKey, MLMetricKey, MLParameterKey,
# MLModelAsset, MLImageConstraint), against the host's own Core ML, question by question, in two processes.
#
#   1. probe.m is COMPILED against the host's CoreML framework and run
#   2. the same probe is COMPILED against the port's CoreML objects, with no framework linked, and run
#   3. the two outputs must be equal line for line; the two controls are part of the output
#   4. a plant: the port's copy of one class gets its own -init, which must turn the answer red
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
appledir=${APPLEDIR:-$here/../../../../packages/a/apple-backports}
build=${BUILD:-$(runs_folder coreml-unavailable-init)}
mkdir -p "$build"
coreml="$appledir/CoreML"
libs="-framework Foundation -framework CoreGraphics -framework CoreVideo -framework Accelerate"

xcrun clang -fobjc-arc -w -framework Foundation -framework CoreML "$here/probe.m" -o "$build/host"
xcrun clang -fobjc-arc -w $libs -I"$coreml" "$here/probe.m" "$coreml/"*.m "$coreml/"*.c -o "$build/port"
"$build/host" > "$build/host.txt"
"$build/port" > "$build/port.txt"
if [ "$(wc -l < "$build/host.txt" | tr -d ' ')" != 12 ]; then
    echo "FAIL: the host printed $(wc -l < "$build/host.txt" | tr -d ' ') answers, expected 12"; exit 1
fi
if diff "$build/host.txt" "$build/port.txt" > "$build/diff.txt"; then
    echo "port: the 12 answers are the host's, line for line"
else
    echo "FAIL: the port's answers differ from the host's:"; sed 's/^/    /' "$build/diff.txt"; exit 1
fi
# The control that must be red: the host's overrider reads 0, and the port's must read 0 too; a plant that gives a class its own
# -init must change the port's answer for that class, and the comparison has to see it.
plant="$build/plant"
rm -rf "$plant"; mkdir -p "$plant"
cp "$coreml/"*.m "$coreml/"*.c "$coreml/"*.h "$coreml/"*.inc "$plant/"
cat >> "$plant/MLParameter.m" <<'PLANT'

@interface MLKey (RevenantPlant)
- (instancetype)init;
@end
@implementation MLKey (RevenantPlant)
- (instancetype)init { return [super init]; }
@end
PLANT
xcrun clang -fobjc-arc -w $libs -I"$plant" "$here/probe.m" "$plant/"*.m "$plant/"*.c -o "$build/plant-bin"
"$build/plant-bin" > "$build/plant.txt"
if diff -q "$build/host.txt" "$build/plant.txt" > /dev/null; then
    echo "FAIL: the plant was not seen by the comparison"; exit 1
fi
echo "plant: the changed answer is seen: $(diff "$build/host.txt" "$build/plant.txt" | grep -c '^>') line(s) differ"
