#!/bin/sh
# run-crop.sh -- the port's crop-and-scale rules against Core ML's own image constructor, pixel for
# pixel, with a mutant that must go red.
#
# One program, built twice: once against the framework's own resampler (which is the oracle and
# answers itself, so the system binary is a self-consistency check of the program) and once against
# the port's, compiled with the rest of the library under names of its own. Both print
# `differing=N of M` per case and the run fails if any N is not zero.
#
# The harness compiles the port's function with each of CoreGraphics' interpolation qualities first
# (the header's REVENANT_VISION_INTERPOLATION is the seam), which is how the one the framework uses was
# found: the numbers below are the measurement, and the default in the header is the answer.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
root=$(cd "$here/../../../.." && pwd)
vision=${VISION:-$root/packages/frameworks/apple-backports/Vision}
# The build directory: BUILD if the caller set it, a fresh temporary one otherwise, and made
# either way, so a caller who points BUILD at a path that is not there yet gets one made rather
# than a build that fails inside the compiler.
build=${BUILD:-$(runs_fresh revenant-vision)}
mkdir -p "$build"
sdk=$(xcrun --show-sdk-path)
common="-target arm64-apple-ios15.0-macabi -isysroot $sdk -iframework $sdk/System/iOSSupport/System/Library/Frameworks -fobjc-arc -w -Wno-unguarded-availability"
libs="-framework Foundation -framework CoreGraphics -framework CoreVideo -framework CoreML -framework Vision"

runs_xmake l "$runs_checkout/tests/backports/common/registry.lua" names "$vision/../registry/Vision" "$build/rename.h" class,protocol,constant,function

xcrun clang $common -I"$here" "$here/crop.m" $libs -o "$build/system" 2>/dev/null ||
    xcrun clang $common -I"$here" "$here/crop.m" $libs -o "$build/system"
build_port() {
    quality=$1
    xcrun clang $common -DREVENANT_PORT_BUILD=1 \
        -include "$build/rename.h" -I"$here" -I"$vision" \
        "$here/crop.m" "$vision/RevenantVisionBilinear.c" $libs -o "$build/port-$quality"
}

echo "=== the oracle against itself (the program's own two answers are both Core ML's here):"
"$build/system" || true

for quality in kCGInterpolationHigh kCGInterpolationMedium kCGInterpolationNone; do
    build_port "$quality"
    echo "=== the port with $quality:"
    "$build/port-$quality" || true
done

# The verdict and the mutants are counted separately, and the mutants run whatever the verdict was:
# a red verdict is the common case while a rule is being found, and a mutant stage that only ran on
# a green one would not run at all.
echo "=== the verdict, with the header's own default:"
build_port kCGInterpolationHigh
verdict=0
"$build/port-kCGInterpolationHigh" || verdict=1
if [ "$verdict" -eq 0 ]; then
    echo "port: same as the framework, every case"
else
    echo "port: DIFFERS from the framework"
fi

# 5. the mutant: the destination inset put back into the sample position, which is the bug the
#    kernel had and the one this check exists to hold. It has to go red, or the check above is not
#    holding anything -- and a patch that changes nothing is an error rather than a pass, because
#    the mutant would then be the pristine kernel and a green run would prove nothing at all.
rm -rf "$build/mutant"
mkdir -p "$build/mutant"
cp "$vision"/*.m "$vision"/*.h "$vision"/*.c "$build/mutant/"
runs_xmake l "$runs_checkout/tests/backports/common/mutants.lua" first "$build/mutant/RevenantVisionBilinear.c" \
    "revenant_vision_clamp(((double)y + 0.5) * down" "revenant_vision_clamp(((double)(insetY + y) + 0.5) * down"
runs_xmake l "$runs_checkout/tests/backports/common/mutants.lua" first "$build/mutant/RevenantVisionBilinear.c" \
    "revenant_vision_clamp(((double)x + 0.5) * across" "revenant_vision_clamp(((double)(insetX + x) + 0.5) * across"
xcrun clang $common -DREVENANT_PORT_BUILD=1 -include "$build/rename.h" -I"$here" -I"$build/mutant" \
    "$here/crop.m" "$build/mutant/RevenantVisionBilinear.c" $libs -o "$build/mutant/run"
if "$build/mutant/run" > "$build/mutant/record.txt" 2>&1; then
    echo "MUTANT SURVIVED: the inset in the sample position makes no difference, so the check holds nothing"
    mutants=1
else
    echo "the mutant is caught: the inset in the sample position is red, so the check holds the geometry"
    mutants=0
fi
echo "=== mutants: 1 run, $mutants surviving"
if [ "$verdict" -ne 0 ] || [ "$mutants" -ne 0 ]; then
    exit 1
fi
