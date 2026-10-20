#!/bin/sh
# The port's interleaved and planar moves held against the host's own vImage, case by case.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
ACCELERATE=$here/../../../../packages/a/apple-backports/Accelerate
REGISTRY=$here/../../../../packages/a/apple-backports/registry/Accelerate
build=${VIMAGEPLANAR_BUILD:-$(runs_folder revenant-vimageplanar-host)}
rm -rf "$build"
mkdir -p "$build"

# Every API name the object defines is renamed in the port's own translation unit, so this one can hold the
# port's answers and the host's side by side. The names come from the port's registry, not from a list kept
# here, so a name added to the library is renamed too.
names=$(runs_xmake l "$here/../registry-functions.lua" "$REGISTRY" ios7planar.json)

renames=""
for name in $names; do
    renames="$renames -D$name=revenant_host_$name"
done

xcrun clang -fobjc-arc -w $renames -I"$ACCELERATE" -c "$ACCELERATE/vImagePlanar7.m" -o "$build/vImagePlanar7.o"
xcrun clang -fobjc-arc -Wall -Wno-deprecated-declarations \
    "$here/differential.m" "$build/vImagePlanar7.o" \
    -framework Foundation -framework Accelerate -o "$build/differential"
"$build/differential" > "$build/log" 2>&1 && result=0 || result=$?
grep -v '^ok ' "$build/log" || true
echo "log=$build/log"
exit $result
