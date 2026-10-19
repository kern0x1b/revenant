#!/bin/sh
# run.sh - MTLTileRenderPipelineDescriptor (iOS 11.0) against Apple's own object, property by property.
#
# The port's tile descriptor is built for Catalyst beside Apple's Metal in one process, with every class the three
# source files define renamed CharonHost<Name>: the descriptor, the colour attachment array (11.0) and the pipeline
# buffer descriptor array (11.0), which its members are made of. MTLLinkedFunctions (14.0) stays Apple's class, for
# the reason compute-pipeline-descriptor/run.sh gives.
#
# A MUTANT runs last: -reset no longer clears maxTotalThreadsPerThreadgroup. Apple's reset restores it (measured),
# so the reset comparison must turn red.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
METAL=${METAL:-$here/../../../../packages/a/apple-backports/Metal}
BUILD=${BUILD:-$(runs_fresh charon-tile-render-pipeline-descriptor)}
sdk=$(xcrun --show-sdk-path)
target="-target arm64-apple-ios16.0-macabi -isysroot $sdk -iframework $sdk/System/iOSSupport/System/Library/Frameworks"
quiet="-Wno-deprecated-declarations -Wno-unguarded-availability-new -Wno-objc-designated-initializers -Wno-incomplete-implementation -Wno-objc-protocol-method-implementation"
gl="-I$here/../metalblit/gl-stub"
sources="MTLTileRenderPipelineDescriptor11.m MTLTileRenderPipelineAttachments11.m MTLReflection11.m"

rm -rf "$BUILD/plain" "$BUILD/renamed"
mkdir -p "$BUILD/plain" "$BUILD/renamed"
for source in $sources; do
    xcrun clang $target -fobjc-arc -fvisibility=hidden $quiet $gl -I"$METAL" -c "$METAL/$source" -o "$BUILD/plain/$source.o"
done
renames=""
for name in $(xcrun nm -gU "$BUILD"/plain/*.o | awk 'NF == 3 {print $3}' | grep -E '^_OBJC_CLASS_\$_' | sed -e 's/^_OBJC_CLASS_\$_//' | sort -u); do
    renames="$renames -D$name=CharonHost$name"
done
echo "renamed:$renames"
for source in $sources; do
    xcrun clang $target -fobjc-arc -fvisibility=hidden $quiet $gl $renames -I"$METAL" -c "$METAL/$source" -o "$BUILD/renamed/$source.o"
done

xcrun clang $target -fobjc-arc $quiet -I"$here" "$here/descriptor.m" "$BUILD"/renamed/*.o \
    -framework Metal -framework Foundation -o "$BUILD/descriptor"
"$BUILD/descriptor"

echo "the child: Apple's tile buffers touched, then -reset, which must stop Apple's process"
set +e
"$BUILD/descriptor" apple-tile-reset > "$BUILD/child.out" 2>&1
status=$?
set -e
if [ "$status" -eq 0 ]; then
    echo "FAIL: Apple's -reset returned after its tile buffers were touched; the defect is not there" >&2
    exit 1
fi
echo "ok   Apple's -reset stops its process once the tile buffers were touched (status $status)"

echo "the mutant: -reset no longer clears maxTotalThreadsPerThreadgroup"
mkdir -p "$BUILD/mutant-src"
sed 's/^    _maxTotalThreadsPerThreadgroup = 0;$/    \/\/ the threadgroup limit is not reset (mutant)/' "$METAL/MTLTileRenderPipelineDescriptor11.m" > "$BUILD/mutant-src/MTLTileRenderPipelineDescriptor11.m"
if cmp -s "$METAL/MTLTileRenderPipelineDescriptor11.m" "$BUILD/mutant-src/MTLTileRenderPipelineDescriptor11.m"; then
    echo "RUN FAILED: the mutation did not change the source" >&2
    exit 1
fi
xcrun clang $target -fobjc-arc -fvisibility=hidden $quiet $gl $renames -I"$METAL" -c "$BUILD/mutant-src/MTLTileRenderPipelineDescriptor11.m" -o "$BUILD/mutant-descriptor.o"
ls "$BUILD"/renamed/*.o | grep -v "MTLTileRenderPipelineDescriptor11" > "$BUILD/rest.txt"
xcrun clang $target -fobjc-arc $quiet -I"$here" "$here/descriptor.m" "$BUILD/mutant-descriptor.o" $(cat "$BUILD/rest.txt") \
    -framework Metal -framework Foundation -o "$BUILD/mutant"
set +e
"$BUILD/mutant" > "$BUILD/mutant.out" 2>&1
set -e
if grep -q "FAIL reset: the port" "$BUILD/mutant.out"; then
    echo "ok   the mutant turns the reset comparison red"
else
    echo "FAIL: the mutant did not turn the reset comparison red" >&2
    cat "$BUILD/mutant.out" >&2
    exit 1
fi
