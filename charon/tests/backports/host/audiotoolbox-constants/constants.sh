#!/bin/sh
# AudioToolbox's constants this round carries: constants.m checks the port's notification names against the host and the
# enumerators' values against the iOS 26.2 declarations.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
build=${AUDIOTOOLBOX_CONSTANTS_BUILD:-$(runs_folder charon-audiotoolbox-constants)}
rm -rf "$build"
mkdir -p "$build"

xcrun clang -fobjc-arc -Wall -Wno-deprecated-declarations "$here/constants.m" \
    -framework Foundation -framework AudioToolbox -framework AudioUnit \
    -o "$build/constants" 2> "$build/build.err" || { echo "FAIL building constants"; head -10 "$build/build.err"; exit 1; }
"$build/constants" > "$build/log" 2>&1 && result=0 || result=$?
cat "$build/log"
echo "log=$build/log"
exit "$result"
