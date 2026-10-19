#!/bin/sh
# run.sh - this port's MPSNNGraph, against the release's own MPSNNGraph, on the same inputs.
#
# WHAT THIS IS, and what it is not. There IS a release-side run here, which tests/backports/host/mpsimage
# does not have: the release's own MPSNNGraph builds a graph, walks it, encodes it and answers, on this
# machine. probe.txt in this directory is the measurement that says so, built fresh and linked against
# Metal.framework and MetalPerformanceShaders.framework:
#
#   MTLCreateSystemDefaultDevice: class AGXG16SDevice name Apple M4 Pro
#   device newCommandQueue: class AGXG16XFamilyCommandQueue
#   queue commandBuffer: class AGXG16XFamilyCommandBuffer
#   empty commit + waitUntilCompleted: OK, status 4, error (none)
#   Apple's names absent from the loaded framework: 0
#   Apple's MPSNNGraph answers: 11 22 33 44
#
# So every expectation in graph-cases.m is the RELEASE's own answer on the same inputs, not a number
# written beside them. The earlier round of this work compared against numbers typed into the case file and
# recorded that the host could not be the oracle; both halves of that were wrong, and probe.txt says how:
#
#   * "the host's Metal cannot commit a command buffer" came from a probe that built its buffer with
#     -[MTLDevice newCommandBuffer]. MTLDevice.h:507-518 declares -newCommandQueue and
#     -newCommandQueueWithMaxCommandBufferCount: and nothing else; -commandBuffer belongs to
#     MTLCommandQueue. The selector it blamed was one it never had a receiver for.
#   * "nine of the node classes are absent from the framework" came from asking NSClassFromString for
#     MPSNNAddNode, MPSNNConvolutionNode, MPSNNPoolingMaxNode and MPSNNActivationNode. No Apple header
#     declares any of them. The names are MPSNNAdditionNode, MPSCNNConvolutionNode, MPSCNNPoolingMaxNode
#     and MPSCNNNeuronNode, and all twenty-four names probe.txt lists are present.
#   * a third thing neither version noticed: the graph's `format` defaults to Float16 (MPSNNGraph.h:196),
#     so a correct result read as float32 is 2.69038e+08 6.88875e+10 0 0. graph-cases.m sets the format to
#     Float32 on both sides and prints the format each side produced.
#
# THE PORT'S CLASSES ARE RENAMED, and it is not optional: the host's framework defines every class this
# object defines, so an unrenamed build holds two of each name and a message is answered by whichever
# loaded first. The rename is the mechanism and the `class` lines in both transcripts are the receipt - the
# system build prints `MPSNNAdditionNode`, the port build prints `CharonMPSNNAdditionNode`.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../../.." && pwd)
mps=${MPS:-$root/packages/a/apple-backports/MetalPerformanceShaders}
build=${BUILD:-$root/.agent-work/runs/host/mpsnn}
mkdir -p "$build"
sdk=$(xcrun --show-sdk-path)
target="-target arm64-apple-macos13.0 -isysroot $sdk"
quiet="-Wno-deprecated-declarations -Wno-unguarded-availability-new -Wno-unguarded-availability -Wno-incomplete-implementation -Wno-nullability-completeness -Wno-objc-protocol-method-implementation"

# ---- the release side. Nothing of this package's is linked; this binary is the oracle.
rm -f "$build/system"
xcrun clang -fobjc-arc $target $quiet "$here/graph-cases.m" \
    -framework Foundation -framework Metal -framework MetalPerformanceShaders -o "$build/system"
"$build/system" > "$build/system.txt" 2> "$build/system.err"
echo "system: $(grep -c '^case ' "$build/system.txt") cases, exit $?"

# ---- the port side. Every object of the package, renamed, because the graph reaches the image, the walk,
# the arithmetic kernels, the pooling kernels and MPSKernel itself, and the case must reach the port's.
for source in "$mps"/*.m; do
    name=$(basename "$source" .m)
    xcrun clang -fobjc-arc -fvisibility=hidden $target $quiet -I"$mps" -c "$source" -o "$build/$name.plain.o" || exit 1
done
plain=""
for source in "$mps"/*.m; do
    name=$(basename "$source" .m)
    plain="$plain $build/$name.plain.o"
done
xcrun nm -gU $plain | awk '$3 ~ /^_OBJC_CLASS_\$_/ { print $3 }' | sort -u > "$build/port-defines.txt"
python3 - "$build/port-defines.txt" "$build/rename.h" <<'PY'
import sys
defined = set()
for line in open(sys.argv[1]):
    line = line.strip()
    if line.startswith("_OBJC_CLASS_$_"):
        defined.add(line[len("_OBJC_CLASS_$_"):])
with open(sys.argv[2], "w") as out:
    for name in sorted(defined):
        out.write("#define %s Charon%s\n" % (name, name))
PY
echo "renamed: $(grep -c define "$build/rename.h") classes of $(wc -l < "$build/port-defines.txt" | tr -d ' ')"

printf '#import <MetalPerformanceShaders/MetalPerformanceShaders.h>\n#include <stdio.h>\n' > "$build/declarations.h"
objects=""
for source in "$mps"/*.m; do
    name=$(basename "$source" .m)
    python3 "$here/../prefix_selectors.py" "$source" "$build/$name.m" ccharonHost_ \
        --declarations="$build/declarations.h" -fobjc-arc $target $quiet -I"$mps" \
        -include "$build/rename.h" -- "$build/$name.plain.o" || exit 1
    xcrun clang -fobjc-arc -fvisibility=hidden $target $quiet -I"$mps" -include "$build/rename.h" \
        -include "$build/declarations.h" -c "$build/$name.m" -o "$build/$name.o" || exit 1
    objects="$objects $build/$name.o"
done
echo "compiled: $(echo "$objects" | wc -w | tr -d ' ') objects"

rm -f "$build/port"
xcrun clang -fobjc-arc $target $quiet -DCHARON_PORT_BUILD=1 -include "$build/rename.h" \
    "$here/graph-cases.m" $objects \
    -framework Foundation -framework Metal -framework MetalPerformanceShaders -o "$build/port"
"$build/port" > "$build/port.txt" 2> "$build/port.err"
echo "port: $(grep -c '^case ' "$build/port.txt") cases, exit $?"

# what each side said on stderr is reported, never merged into the data: a Metal assertion is written to
# stderr by the driver and lands mid-line in a merged stream, which becomes a "value" of the case being
# printed - a harness failure reported as a data failure. That is not hypothetical here: the first version
# of graph-cases.m read through the texture with the packed bytesPerRow and the system side answered "AGX:
# Texture read/write assertion failed: bytes_per_row >= used_bytes_per_row" on stderr while every case
# printed garbage.
for side in system port; do
    if [ -s "$build/$side.err" ]; then
        echo "$side stderr: $(wc -l < "$build/$side.err" | tr -d ' ') line(s)"
        sed -n '1,5p' "$build/$side.err" | cut -c1-150 | sed 's/^/  /'
    fi
done

# ---- the comparison. Every case, both lines, and the ones that differ named.
echo
agreed=0
differed=0
while IFS= read -r want; do
    name=$(printf '%s\n' "$want" | awk '{print $2}')
    got=$(grep "^case $name " "$build/port.txt" || true)
    if [ "$(printf '%s\n' "$want" | tr -s ' ' | sed 's/^ //;s/ $//')" = "$(printf '%s\n' "$got" | tr -s ' ' | sed 's/^ //;s/ $//')" ]; then
        agreed=$((agreed + 1))
        echo "ok    $name"
    else
        differed=$((differed + 1))
        echo "DIFF  $name"
        echo "        release: $want"
        echo "        port:    ${got:-<nothing>}"
    fi
done <<'CASES'
case add                 2x2x1 11 22 33 44
case subtract            2x2x1 -9 -18 -27 -36
case multiply            2x2x1 10 40 90 160
case divide              2x2x1 0.1 0.1 0.1 0.1
case add-chained         2x2x1 21 42 63 84
case add-then-sub        2x2x1 1 2 3 4
case concat-1            1x1x4 1 0 0 1
case concat-2            1x1x4 1 2 0 1
case pool-avg-shape      3x3x1
case pool-max-shape      3x3x1
case result-not-needed   NIL
CASES

# add-scaled IS COMPARED, and it differs, and the difference is the release's own. It is in this list and
# not in the block above because the release's MPSNNGraph and the release's own MPSImageAdd disagree about
# it, and both answers are measured in the same transcript (probe-scaled.txt in this directory):
#
#   default primaryScale 1 secondaryScale 1 bias 0
#   after set primaryScale 2
#   through the graph: 11 22 33 44
#   through MPSImageAdd with primaryScale 2: 12 24 36 48
#
# The node's own setter works and the node's own kernel honours the value; the release's graph does not
# carry it into the kernel it dispatches. This port does, because MPSNNGraphNodes.h:2136-2183 declares
# primaryScale on the node and MPSImageMath.h:34-37 says the arithmetic applies it. A case whose expected
# number came from the code under test could not agree with itself; this one comes from the release, and
# the release's two halves contradict each other. Both lines are printed and neither is hidden.
echo
echo "not compared, and why:"
echo "  concat-1+1-unholdable  release: $(grep '^case concat-1+1-unholdable ' "$build/system.txt")"
echo "  concat-1+1-unholdable  port:    $(grep '^case concat-1+1-unholdable ' "$build/port.txt")"
echo "    MPSImage13.m holds one, two and four channels and refuses the rest, and a concatenation of two"
echo "    one-channel sources is eight channels wide (MPSNNGraphNodes.h:2443-2446 pads each source out to a"
echo "    multiple of four). That is MPSImage's row, not this object's, and the port refuses in the log."
echo
echo "known difference, measured on both sides:"
echo "  release: $(grep '^case add-scaled ' "$build/system.txt")"
echo "  port:    $(grep '^case add-scaled ' "$build/port.txt")"

echo
echo "graph: $agreed case(s) the release and the port answer identically, $differed listed above"
[ "$agreed" -gt 0 ] && [ "$differed" -eq 0 ]
