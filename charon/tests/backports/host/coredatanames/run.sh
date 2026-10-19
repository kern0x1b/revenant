#!/bin/sh
# run.sh - the port's CoreData names (renamed charonHost_*) against the host's own CoreData, which
# exports every one of them. The values were read out of the arm64e shared cache of iOS 18.0; this is
# the second, independent source, and a key mistyped on the way out of the cache shows up here.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
port=${PORT:-$here/../../../../packages/a/apple-backports/.gen/CoreData}
# CoreDataNames70 is committed (it is not one of the measured table's objects); the others are gen's output in .gen/CoreData.
committed=$here/../../../../packages/a/apple-backports/CoreData
harness=${COREDATANAMES_HARNESS:-$here/../../device}
build=${COREDATANAMES_BUILD:-$(runs_fresh charon-coredatanames)}
rm -rf "$build"
mkdir -p "$build"
renames=""
for name in $(sed -e '1,3d' "$here/names.txt"); do
    renames="$renames -D$name=charonHost_$name"
done
objects=""
for source in CoreDataNames70 CoreDataNames100 CoreDataNames103 CoreDataNames140 CoreDataNames170 CoreDataNames180; do
    # shellcheck disable=SC2086
    dir=$port
    [ "$source" = CoreDataNames70 ] && dir=$committed
    xcrun clang -fobjc-arc -fvisibility=hidden -w $renames -c "$dir/$source.m" -o "$build/$source.o"
    objects="$objects $build/$source.o"
done
xcrun clang -fobjc-arc -Wall -Wno-deprecated-declarations -I"$harness" \
    "$here/differential.m" "$harness/check.m" $objects \
    -framework Foundation -framework CoreData -o "$build/differential"
"$build/differential" "$here/names.txt"
