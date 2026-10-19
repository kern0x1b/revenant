#!/bin/sh
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
AV=${AV:-$here/../../../../packages/a/apple-backports/AVFoundation}
GRAPHICS=${GRAPHICS:-$here/../../../../packages/a/apple-backports/Graphics}
BUILD=${BUILD:-$(runs_fresh revenant-coremedia)}
sdk=$(xcrun --show-sdk-path)
quiet="-Wno-deprecated-declarations -Wno-unguarded-availability-new -Wno-availability"
renames="-DCMVideoFormatDescriptionGetH264ParameterSetAtIndex=RevenantHostCMVideoFormatDescriptionGetH264ParameterSetAtIndex"
renames="$renames -DCMVideoFormatDescriptionCreateFromH264ParameterSets=RevenantHostCMVideoFormatDescriptionCreateFromH264ParameterSets"
for name in CVColorPrimariesGetStringForIntegerCodePoint CVColorPrimariesGetIntegerCodePointForString \
            CVTransferFunctionGetStringForIntegerCodePoint CVTransferFunctionGetIntegerCodePointForString \
            CVYCbCrMatrixGetStringForIntegerCodePoint CVYCbCrMatrixGetIntegerCodePointForString; do
    renames="$renames -D$name=revenant_host_$name"
done
xcrun clang -fobjc-arc $quiet $renames -c "$AV/CMVideoFormatDescription7.m" -o "$BUILD/port.o"
xcrun clang -fobjc-arc -fvisibility=hidden -w $renames -c "$GRAPHICS/CVCodePoints.m" -o "$BUILD/codepoints.o"
for test in differential create; do
    xcrun clang -fobjc-arc $quiet "$here/$test.m" "$BUILD/port.o" "$BUILD/codepoints.o" -framework CoreMedia -framework CoreVideo -framework VideoToolbox -framework Foundation -framework AudioToolbox -o "$BUILD/$test"
done
"$BUILD/differential"
"$BUILD/create"
