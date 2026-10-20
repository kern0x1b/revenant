#!/bin/sh
# NSProgress of packages/frameworks/apple-backports/Foundation/NSProgress.m, compiled for the host with its class renamed, against the
# host's own NSProgress: counts, fractionCompleted, the current-progress stack (becomeCurrentWithPendingUnitCount:/
# resignCurrent/initWithParent:), cancelling and pausing with their handlers, userInfo and kind. Four named divergences from
# the host are tolerated - this class follows iOS 6's own measured answers there, not the host's (facts/Foundation/NSProgress.md)
# - each asserted on this class's own side unconditionally; tolerated() only annotates the host's side when it disagrees.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
FOUNDATION=${FOUNDATION:-$here/../../../../packages/frameworks/apple-backports/Foundation}
BUILD=${BUILD:-$(runs_fresh revenant-progress2)}
quiet="-Wno-deprecated-declarations -Wno-unguarded-availability-new -Wno-incomplete-implementation -Wno-objc-protocol-method-implementation -Wno-nullability-completeness -Wno-objc-designated-initializers"
rm -rf "$BUILD/port"
mkdir -p "$BUILD/port"
xcrun clang -fobjc-arc -fvisibility=hidden $quiet -DNSProgress=RevenantHostNSProgress -c "$FOUNDATION/NSProgress.m" -o "$BUILD/port/NSProgress.o"
xcrun clang -fobjc-arc $quiet "$here/differential.m" "$BUILD/port/NSProgress.o" -framework Foundation -o "$BUILD/differential"
"$BUILD/differential"
