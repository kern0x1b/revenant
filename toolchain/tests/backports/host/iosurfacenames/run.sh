#!/bin/sh
# run.sh - the port's IOSurface property keys (renamed revenantHost_*) against the host's own IOSurface,
# which exports every one of them. The values were read out of the arm64e shared cache of iOS 18.0;
# this is the second, independent source, and a key mistyped on the way out of the cache shows up here.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
port=${PORT:-$here/../../../../packages/a/apple-backports/.gen/IOSurface}
harness=${IOSURFACENAMES_HARNESS:-$here/../../device}
build=${IOSURFACENAMES_BUILD:-$(runs_fresh revenant-iosurfacenames)}
rm -rf "$build"
mkdir -p "$build"
renames=""
for name in $(sed -e '1,3d' "$here/names.txt"); do
    case "$name" in
        *) renames="$renames -D$name=revenantHost_$name" ;;
    esac
done
objects=""
for source in IOSurfacePropertyNames110 IOSurfacePropertyNames120 IOSurfacePropertyNames140 IOSurfacePropertyNames160 IOSurfacePropertyNames180; do
    # shellcheck disable=SC2086
    xcrun clang -fobjc-arc -fvisibility=hidden -w $renames -c "$port/$source.m" -o "$build/$source.o"
    objects="$objects $build/$source.o"
done
xcrun clang -fobjc-arc -Wall -Wno-deprecated-declarations -I"$harness" \
    "$here/differential.m" "$harness/check.m" $objects \
    -framework Foundation -framework IOSurface -o "$build/differential"
"$build/differential" "$here/names.txt"
