#!/bin/sh
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
FOUNDATION=${FOUNDATION:-$here/../../../../packages/a/apple-backports/Foundation}
BUILD=${BUILD:-$(runs_fresh charon-oslog)}
xcrun clang -fobjc-arc -mmacosx-version-min=10.11 -w -I"$FOUNDATION" -I"$here" "$here/differential.m" "$FOUNDATION/CharonOSLogFormat.m" \
    -framework Foundation -o "$BUILD/differential"
TZ=UTC OS_ACTIVITY_DT_MODE=YES "$BUILD/differential" "$BUILD/ours.bin" 2> "$BUILD/system.txt" > "$BUILD/stdout.txt" || { cat "$BUILD/stdout.txt"; exit 1; }
cat "$BUILD/stdout.txt"
EXPECTATIONS=${EXPECTATIONS:-$here/../../device/oslog-expectations.h}
xmake l "$here/compare.lua" "$BUILD/system.txt" "$BUILD/ours.bin" "$EXPECTATIONS" "$(awk '/OSLOG_BATTERY_HOST/ {exit} /^    CASE\(/ {n++} END {print n}' "$here/battery.h")"
