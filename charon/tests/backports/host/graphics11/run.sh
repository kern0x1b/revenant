#!/bin/sh
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
GRAPHICS=${GRAPHICS:-$here/../../../../packages/a/apple-backports/Graphics}
harness=${GRAPHICS11_HARNESS:-$here/../../device}
build=${GRAPHICS11_BUILD:-$(runs_folder charon-graphics11-host)}
sources="CVCodePoints.m CVConstants.m CVConstants11.m CVConstants12.m CGColorSpaceGetName.m CGImageInfo.m CGPathApplyWithBlock.m CGPDFApplyBlocks.m"
renames=""
for name in CGColorSpaceGetName CGPathApplyWithBlock CGImageGetByteOrderInfo CGImageGetPixelFormatInfo CGPDFArrayApplyBlock CGPDFDictionaryApplyBlock \
            CVColorPrimariesGetStringForIntegerCodePoint CVColorPrimariesGetIntegerCodePointForString \
            CVTransferFunctionGetStringForIntegerCodePoint CVTransferFunctionGetIntegerCodePointForString \
            CVYCbCrMatrixGetStringForIntegerCodePoint CVYCbCrMatrixGetIntegerCodePointForString \
            kCVImageBufferTransferFunction_sRGB kCVImageBufferTransferFunction_ITU_R_2100_HLG kCVImageBufferTransferFunction_SMPTE_ST_2084_PQ \
            kCVImageBufferTransferFunction_Linear kCVImageBufferContentLightLevelInfoKey kCVImageBufferMasteringDisplayColorVolumeKey \
            kCVPixelFormatContainsGrayscale kCGColorSpaceGenericLab; do
    renames="$renames -D$name=charon_host_$name"
done
rm -rf "$build"
mkdir -p "$build"
objects=""
for source in $sources; do
    xcrun clang -fobjc-arc -fvisibility=hidden -w $renames -c "$GRAPHICS/$source" -o "$build/$source.o"
    objects="$objects $build/$source.o"
done
xcrun clang -fobjc-arc -Wall -Wno-deprecated-declarations -I"$harness" \
    "$here/differential.m" "$harness/check.m" $objects \
    -framework Foundation -framework CoreGraphics -framework CoreVideo -o "$build/differential"
"$build/differential" > "$build/log" 2>&1 && result=0 || result=$?
grep -v '^ok ' "$build/log" || true
echo "log=$build/log"
exit $result
