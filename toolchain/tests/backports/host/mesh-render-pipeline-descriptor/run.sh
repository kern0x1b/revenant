#!/bin/sh
# run.sh - MTLMeshRenderPipelineDescriptor (iOS 16.0) against Apple's own object, member by member.
#
# The port's class is built for Catalyst beside Apple's Metal in one process, with every class its three source files
# define renamed RevenantHost<Name>. Those are the class, the colour attachment array and descriptor (8.0), which the
# class's colour array is made of, and the pipeline buffer array (11.0), which its three buffer arrays are made of.
#
# A MUTANT runs last: a fresh descriptor's rasterization is off, not Apple's on (measured), so the fresh comparison
# must turn red.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
METAL=${METAL:-$here/../../../../packages/a/apple-backports/Metal}
BUILD=${BUILD:-$(runs_fresh revenant-mesh-render-pipeline-descriptor)}
sdk=$(xcrun --show-sdk-path)
target="-target arm64-apple-ios16.0-macabi -isysroot $sdk -iframework $sdk/System/iOSSupport/System/Library/Frameworks"
quiet="-Wno-deprecated-declarations -Wno-unguarded-availability-new -Wno-objc-designated-initializers -Wno-incomplete-implementation -Wno-objc-protocol-method-implementation"
gl="-I$here/../metalblit/gl-stub"
sources="MTLMeshRenderPipelineDescriptor16.m MTLRenderPipelineDescriptor8.m MTLReflection11.m"
main=MTLMeshRenderPipelineDescriptor16.m

rm -rf "$BUILD/plain" "$BUILD/renamed" "$BUILD/mutant-src"
mkdir -p "$BUILD/plain" "$BUILD/renamed" "$BUILD/mutant-src"
for source in $sources; do
    xcrun clang $target -fobjc-arc -fvisibility=hidden $quiet $gl -I"$METAL" -c "$METAL/$source" -o "$BUILD/plain/$source.o"
done
renames=""
for name in $(xcrun nm -gU "$BUILD"/plain/*.o | awk 'NF == 3 {print $3}' | grep -E '^_OBJC_CLASS_\$_' | sed -e 's/^_OBJC_CLASS_\$_//' | sort -u); do
    renames="$renames -D$name=RevenantHost$name"
done
echo "renamed:$renames"
for source in $sources; do
    xcrun clang $target -fobjc-arc -fvisibility=hidden $quiet $gl $renames -I"$METAL" -c "$METAL/$source" -o "$BUILD/renamed/$source.o"
done

xcrun clang $target -fobjc-arc $quiet -I"$here" "$here/descriptor.m" "$BUILD"/renamed/*.o \
    -framework Metal -framework Foundation -o "$BUILD/descriptor"
"$BUILD/descriptor"

echo "the mutant: a fresh descriptor has rasterization off, not Apple's on"
sed 's/^    _rasterizationEnabled = YES;$/    _rasterizationEnabled = NO;/' "$METAL/$main" > "$BUILD/mutant-src/$main"
if cmp -s "$METAL/$main" "$BUILD/mutant-src/$main"; then
    echo "RUN FAILED: the mutation did not change the source" >&2
    exit 1
fi
xcrun clang $target -fobjc-arc -fvisibility=hidden $quiet $gl $renames -I"$METAL" -c "$BUILD/mutant-src/$main" -o "$BUILD/mutant-descriptor.o"
ls "$BUILD"/renamed/*.o | grep -v "MTLMeshRenderPipelineDescriptor16" > "$BUILD/rest.txt"
xcrun clang $target -fobjc-arc $quiet -I"$here" "$here/descriptor.m" "$BUILD/mutant-descriptor.o" $(cat "$BUILD/rest.txt") \
    -framework Metal -framework Foundation -o "$BUILD/mutant"
set +e
"$BUILD/mutant" > "$BUILD/mutant.out" 2>&1
set -e
if grep -q "FAIL fresh: the port" "$BUILD/mutant.out"; then
    echo "ok   the mutant turns the fresh comparison red"
else
    echo "FAIL: the mutant did not turn the fresh comparison red" >&2
    cat "$BUILD/mutant.out" >&2
    exit 1
fi
