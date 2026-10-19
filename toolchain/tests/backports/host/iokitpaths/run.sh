#!/bin/sh
# run.sh - the port's IORegistryEntryCopyFromPath, IORegistryEntryCopyPath, IOMainPort and
# kIOMainPortDefault (renamed revenantHost_*) against the host's own IOKit, asked the same questions.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
port=${PORT:-$here/../../../../packages/a/apple-backports/IOKit}
harness=${IOKITPATHS_HARNESS:-$here/../../device}
build=${IOKITPATHS_BUILD:-$(runs_fresh revenant-iokitpaths)}
rm -rf "$build"
mkdir -p "$build"
renames="-DIORegistryEntryCopyFromPath=revenantHost_IORegistryEntryCopyFromPath
-DIORegistryEntryCopyPath=revenantHost_IORegistryEntryCopyPath
-DIOMainPort=revenantHost_IOMainPort
-DkIOMainPortDefault=revenantHost_kIOMainPortDefault"
# shellcheck disable=SC2086
xcrun clang -fvisibility=hidden -w $renames -c "$port/IORegistryPaths9.c" -o "$build/port9.o"
# shellcheck disable=SC2086
xcrun clang -fvisibility=hidden -w $renames -c "$port/IOMainPort15.c" -o "$build/port15.o"
xcrun clang -fobjc-arc -Wall -I"$harness" \
    "$here/differential.m" "$harness/check.m" "$build/port9.o" "$build/port15.o" \
    -framework Foundation -framework IOKit -o "$build/differential"
"$build/differential"
