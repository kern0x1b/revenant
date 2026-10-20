#!/bin/sh
# run.sh - is this port's convolutional MPS the same arithmetic as the system's own?
#
# cases.m is compiled twice and run twice: once against the system's MPS, once against this port's
# classes with the MPS names mapped to Revenant names and their selectors prefixed, so the port's
# implementations are reached under names of their own and cannot replace the system's. Every case
# prints the result the kernel wrote, as text, and the two runs are compared against a written-down
# float tolerance rather than bit for bit, because a normalisation accumulates in a different order on
# a GPU than on a CPU. See TOLERANCE below.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
mps=${MPS:-$here/../../../../packages/frameworks/apple-backports/MetalPerformanceShaders}
build=${BUILD:-$(runs_folder host/mpscnn10)}
rm -rf "$build"
mkdir -p "$build"
sdk=$(xcrun --show-sdk-path)
target="-target arm64-apple-macos13.0 -isysroot $sdk"
quiet="-Wno-deprecated-declarations -Wno-unguarded-availability-new -Wno-unguarded-availability -Wno-incomplete-implementation -Wno-nullability-completeness -Wno-objc-protocol-method-implementation"
xcrun clang -fobjc-arc $target $quiet "$here/cases.m" \
    -framework Foundation -framework Metal -framework MetalPerformanceShaders -o "$build/system"
"$build/system" > "$build/system.txt" 2> "$build/system.err" || true
echo "system: $(wc -l < "$build/system.txt") lines"

# The names this library carries, each under a name of its own. The list is every class the port
# *defines*, read out of its compiled objects and not the subset a case happens to reach: the host's
# MPS framework defines nearly all of them, so a class left unrenamed is two classes of one name in
# the port's process, and which one a superclass pointer or a message reaches is then decided by load
# order rather than by anything here. The same shape of defect ba5df243 found in NetworkExtension.
rm -rf "$build/plain"
mkdir -p "$build/plain"
for source in "$mps"/*.m; do
    xcrun clang -fobjc-arc -w $target -c "$source" -o "$build/plain/$(basename "$source" .m).o" 2>/dev/null
done
for object in "$build/plain"/*.o; do xcrun nm -g --defined-only "$object"; done \
    | grep -oE '_OBJC_CLASS_\$_[A-Za-z0-9_]+' | sed 's/_OBJC_CLASS_\$_//' | sort -u > "$build/port-defines.txt"
runs_xmake l "$runs_checkout/tests/backports/common/classes.lua" rename "$build/port-defines.txt" "$build/rename.h"
echo "renamed: $(grep -c define "$build/rename.h") classes"

# The eleven classes this band carries, named here so the run FAILS if one is missing from the
# objects. Without this the harness would compile, run and compare, and the comparison would be of
# two transcripts in which every case said NOT COMPARED - which the reader below treats as red, but
# which a reader who only looked at the case count would read as a pass.
runs_xmake l "$runs_checkout/tests/backports/common/classes.lua" require "$build/port-defines.txt" \
    MPSCNNNeuron MPSCNNNeuronLinear MPSCNNNeuronReLU MPSCNNNeuronSigmoid \
    MPSCNNNeuronTanH MPSCNNNeuronAbsolute MPSCNNSoftMax MPSCNNLogSoftMax \
    MPSCNNSpatialNormalization MPSCNNLocalContrastNormalization \
    MPSCNNCrossChannelNormalization

printf '#import <MetalPerformanceShaders/MetalPerformanceShaders.h>\n#import "RevenantMPSCnn.h"\n#import <objc/runtime.h>\n#include <stdio.h>\n' > "$build/declarations.h"
objects=""
for source in "$mps"/*.m; do
    name=$(basename "$source" .m)
    xcrun clang -fobjc-arc -fvisibility=hidden $target $quiet -c "$source" -o "$build/$name.plain.o"
    runs_xmake l "$here/../prefix_selectors.lua" "$source" "$build/$name.m" revenantHost_ \
        --declarations="$build/declarations.h" -fobjc-arc $target $quiet -I"$mps" -include "$build/rename.h" -- "$build/$name.plain.o"
    xcrun clang -fobjc-arc -fvisibility=hidden $target $quiet -I"$mps" -include "$build/rename.h" \
        -include "$build/declarations.h" -c "$build/$name.m" -o "$build/$name.o"
    objects="$objects $build/$name.o"
done
echo "compiled: $(echo "$objects" | wc -w) objects"

# -DREVENANT_PORT_BUILD: this is the port's own build, and the guard below is a statement about it. The
# system build has no rename header and no port classes, and there is nothing for the guard to ask of
# it.
xcrun clang -fobjc-arc $target $quiet -DREVENANT_PORT_BUILD=1 -include "$build/rename.h" "$here/cases.m" $objects \
    -framework Foundation -framework Metal -framework MetalPerformanceShaders -o "$build/port"
"$build/port" > "$build/port.txt" 2> "$build/port.err" || true

# TOLERANCE, written down before the numbers were compared: a normalisation and an exponential
# accumulate in a different order on the GPU than on the CPU, so the two are not expected to agree to
# the bit. A case passes when every element differs by no more than TOLERANCE, absolute or relative,
# whichever is larger, with TOLERANCE = 1e-4 for a single precision result.
TOLERANCE=1e-4
status=0
runs_xmake l "$here/compare.lua" "$build/system.txt" "$build/port.txt" "$TOLERANCE" || status=$?
if [ "$status" -ne 0 ]; then
    echo "the port's convolutional MPS differs from the system's own"
    exit 1
fi
echo "port: within the tolerance, case for case"
