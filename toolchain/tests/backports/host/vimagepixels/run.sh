#!/bin/sh
# The port's vImage pixel conversions held against the host's own vImage, case by case: the same pixels
# through each, every byte of the answer compared.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
ACCELERATE=${ACCELERATE:-$here/../../../../packages/frameworks/apple-backports/Accelerate}
build=${VIMAGEPIXELS_BUILD:-$(runs_folder revenant-vimagepixels-host)}
rm -rf "$build"
mkdir -p "$build"

# Every API name the object files define is renamed in the port's own translation units, so this one can
# hold the port's answers and the host's side by side. The names come from the port's registry, not from a
# list kept here, so a name added to either file is renamed too.
renames=""
for name in $(runs_xmake l "$here/../registry-functions.lua" "$here/../../../../packages/frameworks/apple-backports/registry/Accelerate" ios7pixels.json ios8pixels.json); do
    renames="$renames -D$name=revenant_host_$name"
done

objects=""
for source in vImagePixels7.m vImagePixels8.m; do
    xcrun clang -fobjc-arc -w $renames -I"$ACCELERATE" -c "$ACCELERATE/$source" -o "$build/$(basename "$source").o"
    objects="$objects $build/$(basename "$source").o"
done

xcrun clang -fobjc-arc -Wall -Wno-deprecated-declarations \
    "$here/differential.m" $objects \
    -framework Foundation -framework Accelerate -o "$build/differential"
"$build/differential" > "$build/log" 2>&1 && result=0 || result=$?
grep -v '^ok ' "$build/log" || true
echo "log=$build/log"
exit $result
