#!/bin/sh
# run.sh - MPSRNNDescriptor, MPSRNNSingleGateDescriptor, MPSGRUDescriptor and MPSLSTMDescriptor (iOS 11.0) against
# Apple's own objects, member by member, from the header MPSRNNLayer.h of the iOS 16.4 SDK.
#
# The four port files are built for Catalyst beside Apple's MetalPerformanceShaders in one process. Every class any of the
# four files defines is renamed RevenantHost<Name> in all four, with one shared rename list: the subclasses name their
# superclass through the renamed base, so a per-file list would leave a subclass inheriting Apple's base by mistake.
#
# A MUTANT runs last: the GRU's gatePnormValue default is 2, not Apple's 1 (measured), and the defaults comparison must
# turn red with a FAIL line naming that class. The mutant is a copy in the build folder; the port's source is not touched.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
PORT=${PORT:-$here/../../../../packages/frameworks/apple-backports/MetalPerformanceShaders}
BUILD=${BUILD:-$(runs_folder mps-rnn)/build}
rm -rf "$BUILD"
mkdir -p "$BUILD/plain" "$BUILD/renamed" "$BUILD/mutant-src"
sdk=$(xcrun --show-sdk-path)
target="-target arm64-apple-ios16.0-macabi -isysroot $sdk -iframework $sdk/System/iOSSupport/System/Library/Frameworks"
quiet="-Wno-deprecated-declarations -Wno-unguarded-availability-new -Wno-objc-designated-initializers -Wno-incomplete-implementation -Wno-objc-protocol-method-implementation"
sources="MPSRNNDescriptor11.m MPSRNNSingleGateDescriptor11.m MPSGRUDescriptor11.m MPSLSTMDescriptor11.m"

for source in $sources; do
    xcrun clang $target -fobjc-arc -fvisibility=hidden $quiet -I"$PORT" -c "$PORT/$source" -o "$BUILD/plain/$source.o"
done
renames=""
for name in $(for object in "$BUILD"/plain/*.o; do xcrun nm -gU "$object"; done | awk 'NF == 3 {print $3}' | grep -E '^_OBJC_CLASS_\$_' | sed -e 's/^_OBJC_CLASS_\$_//' | sort -u); do
    renames="$renames -D$name=RevenantHost$name"
done
echo "renamed:$renames"
objects=""
for source in $sources; do
    xcrun clang $target -fobjc-arc -fvisibility=hidden $quiet $renames -I"$PORT" -c "$PORT/$source" -o "$BUILD/renamed/$source.o"
    objects="$objects $BUILD/renamed/$source.o"
done

xcrun clang $target -fobjc-arc $quiet -I"$here" "$here/descriptor.m" $objects \
    -framework Foundation -framework MetalPerformanceShaders -o "$BUILD/descriptor"
"$BUILD/descriptor"

echo "the mutant: the GRU's gatePnormValue default is 2, not Apple's 1"
gru=MPSGRUDescriptor11.m
sed 's/^        _gatePnormValue = 1.0f;$/        _gatePnormValue = 2.0f;/' "$PORT/$gru" > "$BUILD/mutant-src/$gru"
if cmp -s "$PORT/$gru" "$BUILD/mutant-src/$gru"; then
    echo "RUN FAILED: the mutation did not change the source" >&2
    exit 1
fi
xcrun clang $target -fobjc-arc -fvisibility=hidden $quiet $renames -I"$PORT" -c "$BUILD/mutant-src/$gru" -o "$BUILD/mutant-gru.o"
mutant_objects=""
for source in $sources; do
    if [ "$source" = "$gru" ]; then
        mutant_objects="$mutant_objects $BUILD/mutant-gru.o"
    else
        mutant_objects="$mutant_objects $BUILD/renamed/$source.o"
    fi
done
xcrun clang $target -fobjc-arc $quiet -I"$here" "$here/descriptor.m" $mutant_objects \
    -framework Foundation -framework MetalPerformanceShaders -o "$BUILD/mutant"
set +e
"$BUILD/mutant" > "$BUILD/mutant.out" 2>&1
set -e
if grep -q "FAIL MPSGRUDescriptor defaults" "$BUILD/mutant.out"; then
    echo "ok   the mutant turns the GRU defaults comparison red"
else
    echo "FAIL: the mutant did not turn the GRU defaults comparison red" >&2
    cat "$BUILD/mutant.out" >&2
    exit 1
fi
