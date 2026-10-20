#!/bin/sh
# run.sh - this port's twenty CoreVideo constant strings and six functions (renamed revenantHost_*)
# against the host's own CoreVideo, which exports nineteen of the twenty constants and all six
# functions. Both answers are in one process, so every line is the port beside the system.
#
# The one name the host cannot answer is kCVPixelBufferOpenGLESTextureCacheCompatibilityKey, which the
# header marks API_UNAVAILABLE(macosx); its value was read from the armv7 shared cache of iOS 9.0 with
# tools/corpus/cache-value.lua (the project's reader, through modules/apple/dyld.lua) and values.m holds
# it as the expectation, so the port's copy is still compared.
#
# MUTATE=1 changes one carried string and one function's answer, and the run must then fail. A
# harness that cannot fail is the defect this file exists to rule out, so the failing run is part of
# the same script and prints its own line.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
port=${PORT:-$here/../../../../packages/a/apple-backports/Graphics}
build=${COREVIDEO_BUILD:-$(runs_folder corevideo-host)}
rm -rf "$build"
mkdir -p "$build"

constants="kCVPixelBufferOpenGLESTextureCacheCompatibilityKey
kCVImageBufferAlphaChannelModeKey
kCVImageBufferAlphaChannelMode_PremultipliedAlpha
kCVImageBufferAlphaChannelMode_StraightAlpha
kCVImageBufferAmbientViewingEnvironmentKey
kCVImageBufferRegionOfInterestKey
kCVMetalTextureStorageMode
kCVMetalTextureUsage
kCVPixelBufferProResRAWKey_BlackLevel
kCVPixelBufferProResRAWKey_ColorMatrix
kCVPixelBufferProResRAWKey_GainFactor
kCVPixelBufferProResRAWKey_MetadataExtension
kCVPixelBufferProResRAWKey_RecommendedCrop
kCVPixelBufferProResRAWKey_SenselSitingOffsets
kCVPixelBufferProResRAWKey_WhiteBalanceBlueFactor
kCVPixelBufferProResRAWKey_WhiteBalanceCCT
kCVPixelBufferProResRAWKey_WhiteBalanceRedFactor
kCVPixelBufferProResRAWKey_WhiteLevel
kCVPixelBufferVersatileBayerKey_BayerPattern
kCVPixelFormatContainsSenselArray"

functions="CVBufferCopyAttachments
CVBufferCopyAttachment
CVBufferHasAttachment
CVImageBufferCreateColorSpaceFromAttachments
CVPixelBufferCopyCreationAttributes
CVIsCompressedPixelFormatAvailable"

renames=""
for name in $constants; do renames="$renames -D$name=revenantHost_$name"; done
for name in $functions; do renames="$renames -D$name=revenantHost_$name"; done

# The port's own objects, one release each, renamed so both implementations are callable at once.
objects=""
for source in CoreVideoNames90 CoreVideoNames110 CoreVideoNames130 CoreVideoNames140 \
             CoreVideoNames150 CoreVideoNames160 CVBuffer15 CVPixelBuffer15 \
             CVImageBuffer10 CVPixelFormatDescription15; do
    if [ -f "$port/$source.m" ]; then
        # shellcheck disable=SC2086
        xcrun clang -fobjc-arc -w $renames -c "$port/$source.m" -o "$build/$source.o"
        objects="$objects $build/$source.o"
    fi
done
if [ -z "$objects" ]; then
    echo "no port object was built out of $port, so nothing would be compared" >&2
    exit 2
fi
# Two binaries, one per question, so each has its own main and its own verdict line.
# shellcheck disable=SC2086
xcrun clang -fobjc-arc -w -DHAVE_PORT "$here/values.m" $objects \
    -framework CoreVideo -framework CoreGraphics -o "$build/values-differential"
# shellcheck disable=SC2086
xcrun clang -fobjc-arc -w -DHAVE_PORT "$here/functions.m" $objects \
    -framework CoreVideo -framework CoreGraphics -o "$build/functions-differential"

if [ "${MUTATE:-0}" = "1" ]; then
    # A copy of one object with one carried string misspelled and one function answering wrongly, so
    # the two checks that can fail are shown failing. The mutation is on a copy: the tree is untouched.
    mkdir -p "$build/mutant"
    sed -e 's/CFSTR("ProResRAW_BlackLevel")/CFSTR("ProResRAW_Blacklevel")/' \
        "$port/CoreVideoNames140.m" > "$build/mutant/CoreVideoNames140.m"
    # shellcheck disable=SC2086
    xcrun clang -fobjc-arc -w $renames -c "$build/mutant/CoreVideoNames140.m" \
        -o "$build/mutant/CoreVideoNames140.o"
    printf '%s\n' '#import <CoreFoundation/CoreFoundation.h>' \
        'Boolean revenantHost_CVIsCompressedPixelFormatAvailable(OSType t) { (void)t; return true; }' \
        > "$build/mutant/CVPixelFormatDescription15.m"
    # shellcheck disable=SC2086
    xcrun clang -fobjc-arc -w $renames -c "$build/mutant/CVPixelFormatDescription15.m" \
        -o "$build/mutant/CVPixelFormatDescription15.o"
    # shellcheck disable=SC2086
    xcrun clang -fobjc-arc -w -DHAVE_PORT "$here/values.m" \
        "$build/CoreVideoNames90.o" "$build/CoreVideoNames110.o" "$build/CoreVideoNames130.o" \
        "$build/mutant/CoreVideoNames140.o" "$build/CoreVideoNames150.o" "$build/CoreVideoNames160.o" \
        -framework CoreVideo -framework CoreGraphics -o "$build/mutant-values"
    if "$build/mutant-values" > "$build/mutant-values.log" 2>&1; then
        echo "MUTATE: the mutant values binary passed, so that check cannot fail and proves nothing" >&2
        exit 1
    fi
    echo "MUTATE: a misspelt carried string fails, $(grep -c '^BAD' "$build/mutant-values.log") BAD lines:"
    grep '^BAD' "$build/mutant-values.log"

    # shellcheck disable=SC2086
    xcrun clang -fobjc-arc -w -DHAVE_PORT "$here/functions.m" \
        "$build/CoreVideoNames90.o" "$build/CoreVideoNames110.o" "$build/CoreVideoNames130.o" \
        "$build/CoreVideoNames140.o" "$build/CoreVideoNames150.o" "$build/CoreVideoNames160.o" \
        "$build/CVBuffer15.o" "$build/CVPixelBuffer15.o" "$build/CVImageBuffer10.o" \
        "$build/mutant/CVPixelFormatDescription15.o" \
        -framework CoreVideo -framework CoreGraphics -o "$build/mutant-functions"
    if "$build/mutant-functions" > "$build/mutant-functions.log" 2>&1; then
        echo "MUTATE: the mutant functions binary passed, so that check cannot fail either" >&2
        exit 1
    fi
    echo "MUTATE: an inverted compressed-format answer fails, $(grep -c '^BAD' "$build/mutant-functions.log") BAD lines:"
    grep '^BAD' "$build/mutant-functions.log" | head -3
fi

"$build/values-differential"
"$build/functions-differential"
