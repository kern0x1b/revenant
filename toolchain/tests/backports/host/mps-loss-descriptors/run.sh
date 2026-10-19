#!/bin/sh
# run.sh - MPSCNNLossDataDescriptor (11.3), MPSCNNLossDescriptor (11.3), MPSCNNYOLOLossDescriptor (12.0) and
# MPSNNNeuronDescriptor (11.3) against Apple's own objects, member by member.
#
# The port's four classes are built for Catalyst beside Apple's MetalPerformanceShaders in one process, with every class
# their sources define renamed RevenantHost<Name>, so the port is reached under names of its own and cannot replace Apple's.
# The build and the scratch output are under .agent-work/runs/mps-loss/.
#
# A MUTANT runs last: the factory's default weight is 2.0, not Apple's 1.0 (measured), so the defaults comparison must turn
# red on that member, and the mutant's source is a scratch copy, not the port.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
METAL=${METAL:-$here/../../../../packages/a/apple-backports/MetalPerformanceShaders}
BUILD=${BUILD:-$(runs_folder mps-loss)}
sdk=$(xcrun --show-sdk-path)
target="-target arm64-apple-ios16.0-macabi -isysroot $sdk -iframework $sdk/System/iOSSupport/System/Library/Frameworks"
quiet="-Wno-deprecated-declarations -Wno-unguarded-availability-new -Wno-objc-designated-initializers -Wno-incomplete-implementation -Wno-objc-protocol-method-implementation -Wno-objc-method-access"
sources="MPSCNNLossDataDescriptor11.m MPSCNNLossDescriptor11.m MPSCNNYOLOLossDescriptor12.m MPSNNNeuronDescriptor11.m"

rm -rf "$BUILD/plain" "$BUILD/renamed" "$BUILD/mutant-src" "$BUILD/descriptor" "$BUILD/mutant"
mkdir -p "$BUILD/plain" "$BUILD/renamed" "$BUILD/mutant-src"

# The classes the port defines, read from its own objects: every one is renamed, in every port object, so a class the
# port carries under the release's name cannot be the one the test reaches.
for source in $sources; do
    xcrun clang $target -fobjc-arc -fvisibility=hidden $quiet -I"$METAL" -c "$METAL/$source" -o "$BUILD/plain/$source.o"
done
names=""
for source in $sources; do
    names="$names $(xcrun nm -gU "$BUILD/plain/$source.o" | awk 'NF == 3 {print $3}' | grep -E '^_OBJC_CLASS_\$_' | sed -e 's/^_OBJC_CLASS_\$_//')"
done
renames=""
for name in $(printf '%s\n' $names | sort -u); do
    renames="$renames -D$name=RevenantHost$name"
done
echo "renamed:$renames"

for source in $sources; do
    xcrun clang $target -fobjc-arc -fvisibility=hidden $quiet $renames -I"$METAL" -c "$METAL/$source" -o "$BUILD/renamed/$source.o"
done

objects=""
for source in $sources; do
    objects="$objects $BUILD/renamed/$source.o"
done
xcrun clang $target -fobjc-arc $quiet -I"$here" "$here/descriptor.m" $objects \
    -framework Metal -framework Foundation -framework MetalPerformanceShaders -o "$BUILD/descriptor"
"$BUILD/descriptor"

echo "the mutant: the factory's default weight is 2.0, not Apple's 1.0"
mutated=MPSCNNLossDescriptor11.m
sed 's/^    descriptor->_weight = 1.0f;$/    descriptor->_weight = 2.0f;/' "$METAL/$mutated" > "$BUILD/mutant-src/$mutated"
if cmp -s "$METAL/$mutated" "$BUILD/mutant-src/$mutated"; then
    echo "RUN FAILED: the mutation did not change the source" >&2
    exit 1
fi
xcrun clang $target -fobjc-arc -fvisibility=hidden $quiet $renames -I"$METAL" -c "$BUILD/mutant-src/$mutated" -o "$BUILD/mutant-src/$mutated.o"
mutant_objects=""
for source in $sources; do
    if [ "$source" = "$mutated" ]; then
        mutant_objects="$mutant_objects $BUILD/mutant-src/$mutated.o"
    else
        mutant_objects="$mutant_objects $BUILD/renamed/$source.o"
    fi
done
xcrun clang $target -fobjc-arc $quiet -I"$here" "$here/descriptor.m" $mutant_objects \
    -framework Metal -framework Foundation -framework MetalPerformanceShaders -o "$BUILD/mutant"
set +e
"$BUILD/mutant" > "$BUILD/mutant.out" 2>&1
set -e
if grep -q "FAIL.*factory: loss types 0 to 9" "$BUILD/mutant.out" && grep -q "weight: apple 1, port 2" "$BUILD/mutant.out"; then
    echo "ok   the mutant turns the loss defaults comparison red, on the weight"
else
    echo "FAIL: the mutant did not turn the loss defaults comparison red" >&2
    cat "$BUILD/mutant.out" >&2
    exit 1
fi
