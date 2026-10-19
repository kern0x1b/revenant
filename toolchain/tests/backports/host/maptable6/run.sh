#!/bin/sh
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
FOUNDATION=${FOUNDATION:-$here/../../../../packages/a/apple-backports/Foundation}
harness=${MAPTABLE6_HARNESS:-$here/../../device}
build=${MAPTABLE6_BUILD:-$(runs_folder charon-maptable6-host)}
rm -rf "$build"
mkdir -p "$build"
xcrun clang -fobjc-arc -fvisibility=hidden -w -DweakToStrongObjectsMapTable=charonHost_weakToStrongObjectsMapTable \
    -DstrongToWeakObjectsMapTable=charonHost_strongToWeakObjectsMapTable -DweakToWeakObjectsMapTable=charonHost_weakToWeakObjectsMapTable \
    -DstrongToStrongObjectsMapTable=charonHost_strongToStrongObjectsMapTable -c "$FOUNDATION/NSMapTable+Objects6.m" -o "$build/port.o"
xcrun clang -fobjc-arc -Wall -Wno-deprecated-declarations -I"$harness" \
    "$here/differential.m" "$harness/check.m" "$build/port.o" \
    -framework Foundation -o "$build/differential"
"$build/differential" > "$build/log" 2>&1 && result=0 || result=$?
grep -v '^ok ' "$build/log" || true
echo "log=$build/log"
exit $result
