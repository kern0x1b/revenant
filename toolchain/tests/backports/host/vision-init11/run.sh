#!/bin/sh
# run.sh - the initialisers of the iOS 11 Vision classes the headers mark NS_UNAVAILABLE (-init and +new of nine classes, and
# -initWithCompletionHandler: of five), against the host's own Vision and the port's sources, in two processes:
#
#   1. probe.m is COMPILED against the host's Vision framework (a bare macOS tool) and run
#   2. the same probe is COMPILED against the port's Vision sources, with no framework linked, and run
#   3. the outputs are compared line by line; a plant on a scratch copy of the port (a category that answers nil to -init on one
#      class) must turn the comparison red
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
appledir=${APPLEDIR:-$here/../../../../packages/frameworks/apple-backports}
build=${BUILD:-$(runs_folder vision-init11)}
mkdir -p "$build"
vision="$appledir/Vision"
[ -f "$vision/VNHandlers.m" ] || { echo "no $vision/VNHandlers.m"; exit 1; }
libs="-framework Foundation -framework CoreGraphics -framework CoreVideo -framework CoreImage -framework CoreML -framework Accelerate"

xcrun clang -fobjc-arc -w -framework Foundation -framework Vision "$here/probe.m" -o "$build/host"
xcrun clang -fobjc-arc -w $libs -I"$vision" "$here/probe.m" "$vision/"*.m "$vision/"*.c -o "$build/port"
"$build/host" > "$build/host.txt"
"$build/port" > "$build/port.txt"
if [ "$(grep -c absent "$build/host.txt")" != 0 ]; then
    echo "FAIL: the host does not carry a class the rows name:"; grep absent "$build/host.txt" | sed 's/^/    /'; exit 1
fi
if diff "$build/host.txt" "$build/port.txt" > "$build/diff.txt"; then
    echo "port: the $(wc -l < "$build/host.txt" | tr -d ' ') initialiser answers are the host's, line for line (nil answers: $(grep -c ' nil' "$build/host.txt" || true))"
else
    echo "FAIL: the port answers differ from the host:"; sed 's/^/    /' "$build/diff.txt"; exit 1
fi

# The plant: a scratch copy of the port with a category that answers nil to -init of one class. The comparison must see it.
plant="$build/plant-src"
rm -rf "$plant"
mkdir -p "$plant"
cp "$vision/"*.m "$vision/"*.c "$vision/"*.h "$plant/"
cat >> "$plant/VNHandlers.m" <<'PLANT'
@interface VNCoreMLModel (RevenantPlant)
@end
@implementation VNCoreMLModel (RevenantPlant)
- (instancetype)init { return nil; }
@end
PLANT
xcrun clang -fobjc-arc -w $libs -I"$plant" "$here/probe.m" "$plant/"*.m "$plant/"*.c -o "$build/plant"
"$build/plant" > "$build/plant.txt"
if diff -q "$build/host.txt" "$build/plant.txt" > /dev/null; then
    echo "FAIL: the plant was not seen by the comparison"; exit 1
fi
echo "plant: the changed answer is seen: $(diff "$build/host.txt" "$build/plant.txt" | grep -c '^>') line(s) differ"
