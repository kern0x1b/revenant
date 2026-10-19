#!/bin/sh
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
ACCELERATE=${ACCELERATE:-$here/../../../../packages/a/apple-backports/Accelerate}
harness=${ACCELERATE7_HARNESS:-$here/../../device}
build=${ACCELERATE7_BUILD:-$(runs_folder charon-accelerate7-host)}
sources="vImageBuffer7.m vImageCGImage7.m"
renames=""
for name in vImageBuffer_Init vImageBuffer_InitWithCGImage vImageCreateCGImageFromBuffer; do
    renames="$renames -D$name=charon_host_$name"
done
rm -rf "$build"
mkdir -p "$build"
objects=""
for source in $sources; do
    xcrun clang -fobjc-arc -fvisibility=hidden -w $renames -c "$ACCELERATE/$source" -o "$build/$source.o"
    objects="$objects $build/$source.o"
done
xcrun clang -fobjc-arc -Wall -Wno-deprecated-declarations -I"$harness" \
    "$here/differential.m" "$harness/check.m" $objects \
    -framework Foundation -framework CoreGraphics -framework Accelerate -o "$build/differential"
"$build/differential" > "$build/log" 2>&1 && result=0 || result=$?
grep -v '^ok ' "$build/log" || true
echo "log=$build/log"
exit $result
