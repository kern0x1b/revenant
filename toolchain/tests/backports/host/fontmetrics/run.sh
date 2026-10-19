#!/bin/sh
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
UIKIT=${UIKIT:-$here/../../../../packages/a/apple-backports/UIKit}
BUILD=${BUILD:-$(runs_fresh charon-fontmetrics)}
sdk=$(xcrun --show-sdk-path)
quiet="-Wno-deprecated-declarations -Wno-unguarded-availability-new -Wno-objc-designated-initializers -Wno-nullability-completeness"
target="-target arm64-apple-ios15.0-macabi -isysroot $sdk -iframework $sdk/System/iOSSupport/System/Library/Frameworks"
mkdir -p "$BUILD"
xcrun clang -fobjc-arc -fvisibility=hidden $target $quiet -DUIFontMetrics=CharonHostUIFontMetrics \
    -c "$UIKIT/UIFontMetrics.m" -o "$BUILD/metrics.o"
xcrun clang -fobjc-arc $target $quiet "$here/differential.m" "$BUILD/metrics.o" \
    -framework UIKit -framework Foundation -o "$BUILD/differential"
"$BUILD/differential"
