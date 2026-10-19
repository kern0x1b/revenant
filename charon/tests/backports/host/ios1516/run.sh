#!/bin/sh
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
FOUNDATION=${FOUNDATION:-$here/../../../../packages/a/apple-backports/Foundation}
BUILD=${BUILD:-$(runs_fresh charon-ios1516)}
sed 's/^- (NSComparisonResult)compare:/- (NSComparisonResult)charonHostCompare:/' "$FOUNDATION/NSUUID+Compare.m" > "$BUILD/NSUUID+Compare.m"
xcrun clang -fobjc-arc -mmacosx-version-min=10.11 -w "$here/differential.m" "$BUILD/NSUUID+Compare.m" -framework Foundation -o "$BUILD/differential"
"$BUILD/differential" "$BUILD/expectations.h"
# The routine check above already failed (via `set -eu`) if the port disagreed with the system
# on any pair, fixed or random. Refreshing the device-side fixture that ships in the tree is a
# separate, deliberate act - it draws fresh random UUIDs every time, so doing it on every check
# run left the tracked file, and the flakes it could mask, rewritten by whoever ran the tests.
if [ -n "${IOS1516_RECORD:-}" ]; then
    cp "$BUILD/expectations.h" "$here/../../device/ios1516-expectations.h"
fi
