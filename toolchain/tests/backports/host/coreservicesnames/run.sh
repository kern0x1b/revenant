#!/bin/sh
# run.sh - the port's kUTType names (renamed revenantHost_*) against the host's own CoreServices, which
# exports every one of them. The values were read out of the arm64e shared cache of iOS 18.0; this is
# the second, independent source, and a value mistyped on the way out of the cache shows up here.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
port=${PORT:-$here/../../../../packages/a/apple-backports/.gen/CoreServices}
harness=${CORESERVICESNAMES_HARNESS:-$here/../../device}
build=${CORESERVICESNAMES_BUILD:-$(runs_fresh revenant-coreservicesnames)}
rm -rf "$build"
mkdir -p "$build"
renames=""
for name in $(sed -e '1,3d' "$here/names.txt"); do
    renames="$renames -D$name=revenantHost_$name"
done
objects=""
for source in CoreServicesNames80 CoreServicesNames90 CoreServicesNames91; do
    # shellcheck disable=SC2086
    xcrun clang -fobjc-arc -fvisibility=hidden -w $renames -c "$port/$source.m" -o "$build/$source.o"
    objects="$objects $build/$source.o"
done
xcrun clang -fobjc-arc -Wall -Wno-deprecated-declarations -I"$harness" \
    "$here/differential.m" "$harness/check.m" $objects \
    -framework Foundation -framework CoreServices -o "$build/differential"
"$build/differential" "$here/names.txt"
