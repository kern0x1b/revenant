#!/bin/sh
# The port's LinearAlgebra8.m and AppleBLAS8.m held against the host's own Accelerate, case by case:
# the same inputs through each, comparing the status, the shape and every element.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
ACCELERATE=${ACCELERATE:-$here/../../../../packages/a/apple-backports/Accelerate}
build=${LINEARALGEBRA_BUILD:-$(runs_folder revenant-linearalgebra-host)}
rm -rf "$build"
mkdir -p "$build"

# Every API name the two sources define is renamed in the port's own translation unit, so this one can
# hold the port's objects and the host's side by side. The names come from the port's registry, not from
# a list kept here, so a name added to the library is renamed too.
renames=""
for name in $(runs_xmake l "$here/../registry-functions.lua" "$here/../../../../packages/a/apple-backports/registry/Accelerate" ios8blas.json --except=la_retain --except=la_release); do
    renames="$renames -D$name=revenant_host_$name"
done

objects=""
for source in LinearAlgebra8.m AppleBLAS8.m; do
    xcrun clang -fobjc-arc -w $renames -I"$ACCELERATE" -c "$ACCELERATE/$source" -o "$build/$source.o"
    objects="$objects $build/$source.o"
done

xcrun clang -fobjc-arc -Wall -Wno-deprecated-declarations -Wno-nonnull \
    "$here/differential.m" $objects \
    -framework Foundation -framework Accelerate -o "$build/differential"
"$build/differential" > "$build/log" 2>&1 && result=0 || result=$?
grep -v '^ok ' "$build/log" || true
echo "log=$build/log"
exit $result
