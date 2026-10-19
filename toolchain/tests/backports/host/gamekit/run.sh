#!/bin/sh
# run.sh - the port's GKLeaderboardSet, GKBasePlayer and GKCloudPlayer against the host's own GameKit,
# which has all three. `--mutated` makes the port answer a set that was never loaded as if it had one,
# and every check that holds the shapes must fail.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
port=${PORT:-$here/../../../../packages/a/apple-backports/GameKit}
harness=${GAMEKIT_HARNESS:-$here/../../device}
build=${GAMEKIT_BUILD:-$(runs_fresh revenant-gamekit)}
rm -rf "$build"
mkdir -p "$build"
# The rename list is generated from what the port's objects actually carry, not from the names this
# test happens to declare: after the one-release-per-object split the three classes live in two
# objects, and a list written by hand covered one of them, so the renamed class did not exist and the
# probe trapped in objc_opt_respondsToSelector. Build the list from the built objects, so a class that is
# added, moved or dropped cannot be missed here.
# shellcheck disable=SC2086
# The objects are built first, without a rename, so the rename list can be read off them: the names a
# -D would change are the names the objects are compiled from in the first place.
for source in GKLeaderboardSet7 GKBasePlayer10; do
    xcrun clang -fobjc-arc -fvisibility=hidden -w -x objective-c -c "$port/$source.m" -o "$build/$source.o"
done

# `--mutated` builds the PORT with a compile-time switch, not the probe with a different argument: a
# probe that perturbs its own arguments cannot make any answer of this surface differ, because every one
# of them is that the release has no such call. So the switch is in the port, and this run is red because
# the port answers something else.
if [ "${1:-}" = "--mutated" ]; then
    mutate="-DREVENANT_MUTATE_SETLOAD"
    printf '%s\n' "the port is built with REVENANT_MUTATE_SETLOAD, and the checks below must fail"
else
    mutate=""
fi
renames=""
classes=$(for object in "$build"/*.o; do
    nm "$object" 2>/dev/null | awk '/_OBJC_CLASS_\$_GK/ {sub(/^_OBJC_CLASS_\$_/, "", $3); print $3}'
done | sort -u)
[ -n "$classes" ] || { echo "FAIL no GameKit object in $build, so the rename list would be empty"; exit 1; }
for name in $classes; do
    renames="$renames -D$name=RevenantHost$name"
done
printf 'the port objects carry: %s\n' "$(echo $classes | tr '\n' ' ')"

# the same objects, compiled again with the rename this time, so the differential's declared classes
# and the port's are the same classes under two names
objects=""
for source in GKLeaderboardSet7 GKBasePlayer10; do
    # shellcheck disable=SC2086
    xcrun clang -fobjc-arc -fvisibility=hidden -w -x objective-c $renames $mutate -c "$port/$source.m" -o "$build/renamed-$source.o"
    objects="$objects $build/renamed-$source.o"
done
xcrun clang -fobjc-arc -Wall -Wno-deprecated-declarations -I"$harness" \
    "$here/differential.m" "$harness/check.m" $objects \
    -framework Foundation -framework GameKit -o "$build/differential"
"$build/differential" "$@"
