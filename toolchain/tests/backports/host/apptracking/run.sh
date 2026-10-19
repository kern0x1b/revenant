#!/bin/sh
# run.sh - the port's ATTrackingManager (renamed RevenantHostATTrackingManager) against the host's own
# AppTrackingTransparency, asked the same questions at the same time. macOS is a platform that does
# not run the tracking authorization system either, so the host answers what a release without it
# answers, and the port must answer the same.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
port=${PORT:-$here/../../../../packages/a/apple-backports/AppTrackingTransparency}
harness=${APTTRACKING_HARNESS:-$here/../../device}
build=${APTTRACKING_BUILD:-$(runs_fresh revenant-apptracking)}
rm -rf "$build"
mkdir -p "$build"
xcrun clang -fobjc-arc -fvisibility=hidden -w -DATTrackingManager=RevenantHostATTrackingManager \
    -c "$port/ATTrackingManager.m" -o "$build/port.o"
xcrun clang -fobjc-arc -Wall -Wno-deprecated-declarations -I"$harness" \
    "$here/differential.m" "$harness/check.m" "$build/port.o" \
    -framework Foundation -framework AppTrackingTransparency -o "$build/differential"
"$build/differential"
