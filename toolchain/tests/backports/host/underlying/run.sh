#!/bin/sh
# run.sh — runs the scheduler of the operation queue of the port beside the system's queue over the same cases, and writes what the
# system answered where the device test reads it.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
FOUNDATION=${FOUNDATION:-$here/../../../../packages/frameworks/apple-backports/Foundation}
DEVICE=${DEVICE:-$here/../../device}
BUILD=${BUILD:-$(runs_fresh revenant-underlying)}
xcrun clang -fobjc-arc -fvisibility=hidden -w -DRevenantOperationScheduler=RevenantHostRevenantOperationScheduler -c "$FOUNDATION/RevenantOperationScheduler.m" -o "$BUILD/scheduler.o"
xcrun clang -fobjc-arc -w -I"$DEVICE" -I"$FOUNDATION" "$here/differential.m" "$DEVICE/underlying-cases.m" "$DEVICE/check.m" "$BUILD/scheduler.o" -framework Foundation -o "$BUILD/differential"
"$BUILD/differential" "$BUILD/underlying.json"
xmake l "$here/../../common/embed.lua" "$BUILD/underlying.json" "$DEVICE/underlying-expectations.h" foundation2_expectations
sed -i.bak 's/foundation2_expectations/underlying_expectations/' "$DEVICE/underlying-expectations.h" && rm -f "$DEVICE/underlying-expectations.h.bak"
