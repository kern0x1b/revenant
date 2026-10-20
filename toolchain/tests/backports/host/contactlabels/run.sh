#!/bin/sh
# run.sh - the port's 207 CNLabel names (renamed revenantHost_*) against the host's own Contacts, which
# exports every one of them. The values were read out of the arm64e shared cache of iOS 18.0; this is
# the second, independent source, and a value mistyped on the way out of the cache shows up here.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
port=${PORT:-$here/../../../../packages/frameworks/apple-backports/.gen/Contacts}
harness=${CONTACTLABELS_HARNESS:-$here/../../device}
build=${CONTACTLABELS_BUILD:-$(runs_fresh revenant-contactlabels)}
rm -rf "$build"
mkdir -p "$build"
renames=""
for name in $(sed -e '1,3d' "$here/names.txt"); do
    renames="$renames -D$name=revenantHost_$name"
done
# shellcheck disable=SC2086
objects=""
for source in ContactsRelationLabels110 ContactsRelationLabels130 ContactsRelationLabels140 ContactsRelationLabels143; do
    # shellcheck disable=SC2086
    xcrun clang -fobjc-arc -fvisibility=hidden -w $renames -c "$port/$source.m" -o "$build/$source.o"
    objects="$objects $build/$source.o"
done
xcrun clang -fobjc-arc -Wall -Wno-deprecated-declarations -I"$harness" \
    "$here/differential.m" "$harness/check.m" $objects \
    -framework Foundation -framework Contacts -o "$build/differential"
"$build/differential" "$here/names.txt"
