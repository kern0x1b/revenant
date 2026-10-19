#!/bin/sh
# run.sh - the PDF names and colour conversion keys (the Graphics objects CGPDFNames11, 12 and 16, CGColorConversionNames1001 and 11,
# CGBitmapContextNames11) and
# CGPDFTagTypeGetName, held to the host's CoreGraphics. The port's objects are built with their symbols renamed to
# charon_host_*, so both answers are in one binary and differential.m compares them.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
GRAPHICS=${GRAPHICS:-$here/../../../../packages/a/apple-backports/Graphics}
harness=${CGPDFNAMES_HARNESS:-$here/../../device}
build=${CGPDFNAMES_BUILD:-$(runs_fresh charon-cgpdf-names)}
renames=""
for name in kCGPDFOutlineChildren kCGPDFOutlineDestination kCGPDFOutlineDestinationRect kCGPDFOutlineTitle \
            kCGPDFContextAccessPermissions kCGPDFTagPropertyActualText kCGPDFTagPropertyAlternativeText \
            kCGPDFTagPropertyLanguageText kCGPDFTagPropertyTitleText kCGPDFContextCreateLinearizedPDF \
            kCGPDFContextCreatePDFA kCGColorConversionBlackPointCompensation kCGColorConversionTRCSize \
            kCGAdaptiveMaximumBitDepth CGPDFTagTypeGetName; do
    renames="$renames -D$name=charon_host_$name"
done
objects=""
for source in CGPDFNames11.m CGPDFNames12.m CGPDFNames16.m CGColorConversionNames1001.m CGColorConversionNames11.m CGBitmapContextNames11.m; do
    xcrun clang -fobjc-arc -fvisibility=hidden -w $renames -c "$GRAPHICS/$source" -o "$build/$source.o"
    objects="$objects $build/$source.o"
done
xcrun clang -fobjc-arc -Wall -Wno-deprecated-declarations -I"$harness" \
    "$here/differential.m" "$harness/check.m" $objects \
    -framework Foundation -framework CoreGraphics -o "$build/differential"
"$build/differential" > "$build/log" 2>&1 && result=0 || result=$?
grep -v '^ok ' "$build/log" || true
echo "log=$build/log"
exit $result
