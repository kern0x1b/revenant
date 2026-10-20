#!/bin/sh
# vImage's quarter turns held against the host's own, sample for sample, over twelve shapes and both
# destination shapes for each. The port's sources are compiled with every API name they define renamed, so
# this translation unit can hold the port's answers and the host's side by side; the names come from the
# port's registry, so a name added to either file is renamed too.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
ACCELERATE=${ACCELERATE:-$here/../../../../packages/a/apple-backports/Accelerate}
BUILD=${BUILD:-$(runs_fresh revenant-rotate90)}
sdk=$(xcrun --show-sdk-path)
quiet="-Wno-deprecated-declarations -Wno-unguarded-availability-new -Wno-nullability-completeness"

renames=""
for name in $(runs_xmake l "$here/../registry-functions.lua" "$here/../../../../packages/a/apple-backports/registry/Accelerate" --prefix=vImageRotate90); do
    renames="$renames -D$name=revenantHost_$name"
done

rm -rf "$BUILD"
mkdir -p "$BUILD"
objects=""
for source in vImageGeometry7.m vImageGeometry15.m; do
    xcrun clang -fobjc-arc -isysroot "$sdk" $quiet $renames -c "$ACCELERATE/$source" -o "$BUILD/$source.o"
    objects="$objects $BUILD/$source.o"
done
xcrun clang -fobjc-arc -isysroot "$sdk" $quiet "$here/differential.m" $objects \
    -framework Accelerate -framework Foundation -o "$BUILD/differential"
"$BUILD/differential" > "$BUILD/log" 2>&1 && result=0 || result=$?
grep -v '^ok ' "$BUILD/log" || true
echo "log=$BUILD/log"
exit $result
