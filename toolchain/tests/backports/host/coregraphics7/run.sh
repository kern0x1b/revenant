#!/bin/sh
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
GRAPHICS=${GRAPHICS:-$here/../../../../packages/frameworks/apple-backports/Graphics}
harness=${COREGRAPHICS7_HARNESS:-$here/../../device}
build=${COREGRAPHICS7_BUILD:-$(runs_folder revenant-coregraphics7-host)}
sources="CGColorSpaceICCData10.m CGColorSpaceHDR13.m CGColorSpaceHDR14.m CGColorSpaceHDR15.m CGColorSpaceExtendedRange93.m"
renames=""
for name in CGColorSpaceCopyICCData CGColorSpaceUsesExtendedRange CGColorSpaceIsHDR CGColorSpaceUsesITUR_2100TF CGColorSpaceIsHLGBased CGColorSpaceIsPQBased; do
    renames="$renames -D$name=revenant_host_$name"
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
    -framework Foundation -framework CoreGraphics -o "$build/differential"
"$build/differential" > "$build/log" 2>&1 && result=0 || result=$?
grep -v '^ok ' "$build/log" || true
echo "log=$build/log"
exit $result
