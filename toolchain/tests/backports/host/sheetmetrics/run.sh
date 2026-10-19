#!/bin/sh
# run.sh - holds the constants the port's sheet takes from UIKitCore 16.0 (packages/a/apple-backports/UIKit/
# UISheetPresentationController.m, read from that file here, not copied) against what the host's own sheet metrics
# answer under Mac Catalyst. The host is a later UIKit: where it agrees, the value has an oracle besides the read of the
# 16.0 cache; where it differs for a known reason the difference is named and checked, so the test fails if it ever
# stops differing. The layout the port composes from these (frames, the presenter's scale, the stack) has no host
# oracle: the host shows a sheet in a window of its own and has no _UISheetLayoutInfo class to drive.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
source=${SOURCE:-$here/../../../../packages/a/apple-backports/UIKit/UISheetPresentationController.m}
build=${BUILD:-$(runs_fresh charon-sheetmetrics)}
sdk=$(xcrun --show-sdk-path)
xcrun clang -target arm64-apple-ios16.0-macabi -isysroot "$sdk" -iframework "$sdk/System/iOSSupport/System/Library/Frameworks" -fobjc-arc -w \
    "$here/metrics.m" -framework UIKit -framework Foundation -o "$build/metrics"
"$build/metrics" > "$build/metrics.txt"
port() {
    value=$(sed -n "s/^static const [A-Za-z]* charon_sheet_$1 = \([0-9.]*\);.*/\1/p" "$source")
    [ -n "$value" ] || { echo "FAIL the port declares no charon_sheet_$1 in $source"; exit 1; }
    echo "$value"
}
host() {
    value=$(sed -n "s/^$1 //p" "$build/metrics.txt")
    [ -n "$value" ] || { echo "FAIL the host printed no $1"; exit 1; }
    echo "$value"
}
failures=0
same() {
    p=$(port "$1"); h=$(host "$2")
    if python3 -c "import sys; sys.exit(0 if abs(float('$p') - float('$h')) < 1e-9 else 1)"; then
        echo "ok $1 = $p, the host's $2"
    else
        echo "FAIL $1: port $p, host $2 $h"; failures=$((failures + 1))
    fi
}
differs() {
    p=$(port "$1"); h=$(host "$2")
    if [ "$h" = "$3" ] && [ "$p" != "$h" ]; then
        echo "ok $1 = $p, the host's $2 is $h: $4"
    else
        echo "FAIL $1: port $p, host $2 $h, expected the host at $3 ($4)"; failures=$((failures + 1))
    fi
}
same top_offset topOffset
same top_offset_compact_height topOffsetInCompactHeight
same maximum_depth maximumSheetDepthLevel
same transition_duration transitionDuration
same spring_response spring.response
same spring_damping spring.damping
same spring_damping_fast springFast.damping
differs corner_radius cornerRadius 8 "the host's UIKit is of the design after iOS 26, whose sheet has smaller metrics corners; 16.0 answers 10 (0x189b99fd4)"
echo "checks=8 failures=$failures"
[ "$failures" -eq 0 ]
