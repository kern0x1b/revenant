#!/bin/sh
# run.sh - MTLComputePipelineDescriptor (iOS 9.0) against Apple's own object, property by property.
#
# The port's compute descriptor is built for Catalyst beside Apple's Metal in one process, with every class
# the three source files define renamed CharonHost<Name>, the way metalkit-init and metal-census/descriptors
# do it. The sources are: the descriptor itself, its stage input descriptor (10.0) and the pipeline buffer
# descriptor array (11.0), which the descriptor's defaults are made of.
#
# MTLLinkedFunctions (14.0) stays Apple's class in this case. Its port file, MTLDescriptors14.m, does not
# compile against the SDK of macOS 26 that the host builds with: CharonMetalProtocols.h forward-declares the
# MTL4*Sparse* classes, which that SDK declares as typedefs. So the case measures the descriptor's own
# members, and the linked functions it holds are the host's object on both sides.
#
# A MUTANT runs last: -reset also clears requiredThreadsPerThreadgroup. Apple's keeps it (measured), so the
# reset comparison must turn red. A harness whose comparison cannot fail proves nothing.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
METAL=${METAL:-$here/../../../../packages/a/apple-backports/Metal}
BUILD=${BUILD:-$(runs_fresh charon-compute-pipeline-descriptor)}
sdk=$(xcrun --show-sdk-path)
target="-target arm64-apple-ios16.0-macabi -isysroot $sdk -iframework $sdk/System/iOSSupport/System/Library/Frameworks"
quiet="-Wno-deprecated-declarations -Wno-unguarded-availability-new -Wno-objc-designated-initializers -Wno-incomplete-implementation -Wno-objc-protocol-method-implementation"
gl="-I$here/../metalblit/gl-stub"
sources="MTLComputePipelineDescriptor9.m MTLStageInputOutputDescriptor10.m MTLReflection11.m"

rm -rf "$BUILD/plain" "$BUILD/renamed"
mkdir -p "$BUILD/plain" "$BUILD/renamed"
for source in $sources; do
    xcrun clang $target -fobjc-arc -fvisibility=hidden $quiet $gl -I"$METAL" -c "$METAL/$source" -o "$BUILD/plain/$source.o"
done
renames=""
for name in $(xcrun nm -gU "$BUILD"/plain/*.o | awk 'NF == 3 {print $3}' | grep -E '^_OBJC_CLASS_\$_' | sed -e 's/^_OBJC_CLASS_\$_//' | sort -u); do
    renames="$renames -D$name=CharonHost$name"
done
for source in $sources; do
    xcrun clang $target -fobjc-arc -fvisibility=hidden $quiet $gl $renames -I"$METAL" -c "$METAL/$source" -o "$BUILD/renamed/$source.o"
done

xcrun clang $target -fobjc-arc $quiet -I"$here" "$here/descriptor.m" "$BUILD"/renamed/*.o \
    -framework Metal -framework Foundation -o "$BUILD/descriptor"
"$BUILD/descriptor"

echo "the mutant: -reset also clears requiredThreadsPerThreadgroup"
mkdir -p "$BUILD/mutant-src"
sed '/^- (void)reset$/,/^}$/ s/^    _shaderValidation = MTLShaderValidationDefault;$/    _shaderValidation = MTLShaderValidationDefault;\
    _requiredThreadsPerThreadgroup = MTLSizeMake(0, 0, 0);/' "$METAL/MTLComputePipelineDescriptor9.m" > "$BUILD/mutant-src/MTLComputePipelineDescriptor9.m"
if cmp -s "$METAL/MTLComputePipelineDescriptor9.m" "$BUILD/mutant-src/MTLComputePipelineDescriptor9.m"; then
    echo "RUN FAILED: the mutation did not change the source" >&2
    exit 1
fi
xcrun clang $target -fobjc-arc -fvisibility=hidden $quiet $gl $renames -I"$METAL" -c "$BUILD/mutant-src/MTLComputePipelineDescriptor9.m" -o "$BUILD/mutant-descriptor.o"
ls "$BUILD"/renamed/*.o | grep -v "MTLComputePipelineDescriptor9" > "$BUILD/rest.txt"
xcrun clang $target -fobjc-arc $quiet -I"$here" "$here/descriptor.m" "$BUILD/mutant-descriptor.o" $(cat "$BUILD/rest.txt") \
    -framework Metal -framework Foundation -o "$BUILD/mutant"
set +e
"$BUILD/mutant" > "$BUILD/mutant.out" 2>&1
set -e
if grep -q "FAIL  *port: \|FAIL  *the port" "$BUILD/mutant.out" || grep -q "FAIL  *reset" "$BUILD/mutant.out"; then
    echo "ok   the mutant turns the reset comparison red"
else
    echo "FAIL: the mutant did not turn the reset comparison red" >&2
    cat "$BUILD/mutant.out" >&2
    exit 1
fi
