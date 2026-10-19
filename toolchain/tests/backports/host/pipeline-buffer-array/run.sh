#!/bin/sh
# run.sh - the 11.0 pipeline buffer descriptor and its array, against Apple's own objects, and a mutant.
#
# MTLReflection11.m is built for Catalyst beside Apple's Metal in one process: its two classes are renamed
# RevenantHost<Name> while it is compiled, the way metalkit-init and metal-census/descriptors do it, and
# array.m asks Apple's class and the port's the same questions. The array has 31 slots on Apple's side and
# index 31 stops Apple's process, so that boundary is asked in a child process, whose death is the answer.
#
# A MUTANT runs last: the copy a set keeps is replaced by the caller's own object, which must turn the
# copy check red. A harness whose checks cannot fail proves nothing.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
METAL=${METAL:-$here/../../../../packages/a/apple-backports/Metal}
BUILD=${BUILD:-$(runs_fresh revenant-pipeline-buffer-array)}
sdk=$(xcrun --show-sdk-path)
target="-target arm64-apple-ios16.0-macabi -isysroot $sdk -iframework $sdk/System/iOSSupport/System/Library/Frameworks"
quiet="-Wno-deprecated-declarations -Wno-unguarded-availability-new -Wno-objc-designated-initializers"
renames="-DMTLPipelineBufferDescriptorArray=RevenantHostMTLPipelineBufferDescriptorArray -DMTLPipelineBufferDescriptor=RevenantHostMTLPipelineBufferDescriptor"

xcrun clang $target -fobjc-arc -fvisibility=hidden $quiet $renames -I"$here/../metalblit/gl-stub" -I"$METAL" -c "$METAL/MTLReflection11.m" -o "$BUILD/port.o"
xcrun clang $target -fobjc-arc $quiet -I"$here" "$here/array.m" "$BUILD/port.o" \
    -framework Metal -framework Foundation -o "$BUILD/array"
"$BUILD/array"

echo "the overflow: Apple's array at index 31 must stop its process"
set +e
"$BUILD/array" overflow > "$BUILD/overflow.out" 2>&1
status=$?
set -e
if [ "$status" -eq 0 ]; then
    echo "FAIL: Apple's array answered index 31; the boundary the port copies is not there" >&2
    exit 1
fi
echo "ok   Apple's array stops at index 31 (status $status)"

echo "the mutant: a set keeps the caller's own object, not a copy"
mkdir -p "$BUILD/mutant-src"
sed 's/_descriptors\[@(bufferIndex)\] = buffer ? \[buffer copy\] :/_descriptors[@(bufferIndex)] = buffer ? buffer :/' "$METAL/MTLReflection11.m" > "$BUILD/mutant-src/MTLReflection11.m"
if cmp -s "$METAL/MTLReflection11.m" "$BUILD/mutant-src/MTLReflection11.m"; then
    echo "RUN FAILED: the mutation did not change the source" >&2
    exit 1
fi
xcrun clang $target -fobjc-arc -fvisibility=hidden $quiet $renames -I"$here/../metalblit/gl-stub" -I"$METAL" -c "$BUILD/mutant-src/MTLReflection11.m" -o "$BUILD/mutant.o"
xcrun clang $target -fobjc-arc $quiet -I"$here" "$here/array.m" "$BUILD/mutant.o" \
    -framework Metal -framework Foundation -o "$BUILD/mutant"
set +e
"$BUILD/mutant" > "$BUILD/mutant.out" 2>&1
set -e
if grep -q "FAIL  *port: a set stores a copy" "$BUILD/mutant.out"; then
    echo "ok   the mutant turns the copy check red"
else
    echo "FAIL: the mutant did not turn the copy check red" >&2
    cat "$BUILD/mutant.out" >&2
    exit 1
fi
