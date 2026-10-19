#!/bin/sh
# run.sh - the two CNN descriptors (iOS 11.0) and the TensorFlow average-pooling factories of MPSNNDefaultPadding
# (11.0 and 11.3), against Apple's own objects on the same inputs, in one process.
#
# The port's sources are built for Catalyst beside Apple's MetalPerformanceShaders, and every class they define is
# renamed RevenantHost<Name>, so Apple's classes and the port's coexist in the process. The two descriptors subclass
# the base descriptor (MPSCNNConvolutionDescriptor10.m) and the padding policies subclass MPSNNDefaultPadding
# (MPSNNGraph11.m), so those files are built too. Nothing is stubbed: a symbol the port needs and does not have
# would stop the link here.
#
# A MUTANT runs last: the sub-pixel factor's default is 2 in a copy of the port file, and the default comparison
# must turn red.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
PORT=${PORT:-$here/../../../../packages/a/apple-backports/MetalPerformanceShaders}
BUILD=${BUILD:-$(runs_folder mps-cnn/descriptors)}
# Built for macOS, not Catalyst: the 16.4 header marks setNeuronType:parameterA:parameterB:, neuronType,
# neuronParameterA and neuronParameterB MPS_UNAVAILABLE(macCatalyst) (MPSCNNConvolution.h:266-284), so a Catalyst
# build cannot compile the neuron members at all. The mpscnn host test builds for macOS for the same reason.
sdk=$(xcrun --show-sdk-path)
target="-target arm64-apple-macos13.0 -isysroot $sdk"
quiet="-Wno-deprecated-declarations -Wno-unguarded-availability-new -Wno-objc-designated-initializers -Wno-incomplete-implementation -Wno-objc-protocol-method-implementation"
sources="MPSCNNConvolutionDescriptor10.m MPSCNNDepthWiseConvolutionDescriptor11.m MPSCNNSubPixelConvolutionDescriptor11.m MPSImageWalk13.m MPSNNGraph11.m MPSNNDefaultPadding11.m MPSNNDefaultPadding113.m MPSNNNeuronDescriptor11.m"

rm -rf "$BUILD/plain" "$BUILD/renamed" "$BUILD/mutant-src"
mkdir -p "$BUILD/plain" "$BUILD/renamed" "$BUILD/mutant-src"

# Every class the port defines, read from its own objects, so that no port class keeps a name Apple's framework has.
: > "$BUILD/classes.txt"
for source in $sources; do
    xcrun clang $target -fobjc-arc -fvisibility=hidden $quiet -I"$PORT" -c "$PORT/$source" -o "$BUILD/plain/$source.o"
    xcrun nm -gU "$BUILD/plain/$source.o" | awk 'NF == 3 {print $3}' | grep -E '^_OBJC_CLASS_\$_' | sed -e 's/^_OBJC_CLASS_\$_//' >> "$BUILD/classes.txt"
done
renames=""
for name in $(sort -u "$BUILD/classes.txt"); do
    renames="$renames -D$name=RevenantHost$name"
done
echo "renamed:$renames"

objects=""
for source in $sources; do
    xcrun clang $target -fobjc-arc -fvisibility=hidden $quiet $renames -I"$PORT" -c "$PORT/$source" -o "$BUILD/renamed/$source.o"
    objects="$objects $BUILD/renamed/$source.o"
done

xcrun clang $target -fobjc-arc $quiet -I"$here" "$here/cases.m" $objects \
    -framework Foundation -framework Metal -framework MetalPerformanceShaders -o "$BUILD/cases"
"$BUILD/cases"

echo "the mutant: the sub-pixel factor's default is 2, not Apple's 1"
sed 's/^        _subPixelScaleFactor = 1;$/        _subPixelScaleFactor = 2;/' "$PORT/MPSCNNSubPixelConvolutionDescriptor11.m" \
    > "$BUILD/mutant-src/MPSCNNSubPixelConvolutionDescriptor11.m"
if cmp -s "$PORT/MPSCNNSubPixelConvolutionDescriptor11.m" "$BUILD/mutant-src/MPSCNNSubPixelConvolutionDescriptor11.m"; then
    echo "RUN FAILED: the mutation did not change the source" >&2
    exit 1
fi
xcrun clang $target -fobjc-arc -fvisibility=hidden $quiet $renames -I"$PORT" \
    -c "$BUILD/mutant-src/MPSCNNSubPixelConvolutionDescriptor11.m" -o "$BUILD/mutant-subpixel.o"
mutant_objects=""
for source in $sources; do
    case "$source" in
    MPSCNNSubPixelConvolutionDescriptor11.m) mutant_objects="$mutant_objects $BUILD/mutant-subpixel.o" ;;
    *) mutant_objects="$mutant_objects $BUILD/renamed/$source.o" ;;
    esac
done
xcrun clang $target -fobjc-arc $quiet -I"$here" "$here/cases.m" $mutant_objects \
    -framework Foundation -framework Metal -framework MetalPerformanceShaders -o "$BUILD/mutant"
set +e
"$BUILD/mutant" > "$BUILD/mutant.out" 2>&1
set -e
if grep -q "subPixelScaleFactor: apple 1, port 2" "$BUILD/mutant.out" && grep -q "FAIL" "$BUILD/mutant.out"; then
    echo "ok   the mutant turns the sub-pixel default red"
else
    echo "FAIL: the mutant did not turn the sub-pixel default red" >&2
    cat "$BUILD/mutant.out" >&2
    exit 1
fi
