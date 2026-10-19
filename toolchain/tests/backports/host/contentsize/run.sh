#!/bin/sh
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
UIKIT=${UIKIT:-$here/../../../../packages/a/apple-backports/UIKit}
BUILD=${BUILD:-$(runs_fresh revenant-contentsize)}
sdk=$(xcrun --show-sdk-path)
quiet="-Wno-deprecated-declarations -Wno-unguarded-availability-new -Wno-nullability-completeness"
mkdir -p "$BUILD"
for source in UIContentSizeCategory+Comparison.m UIFont+LargeTitle.m; do
    xcrun clang -fobjc-arc -fvisibility=hidden -target arm64-apple-ios15.0-macabi -isysroot "$sdk" \
        -iframework "$sdk/System/iOSSupport/System/Library/Frameworks" $quiet \
        -DUIContentSizeCategoryIsAccessibilityCategory=RevenantHostUIContentSizeCategoryIsAccessibilityCategory \
        -DUIContentSizeCategoryCompareToCategory=RevenantHostUIContentSizeCategoryCompareToCategory \
        -DUIFontTextStyleLargeTitle=RevenantHostUIFontTextStyleLargeTitle \
        -c "$UIKIT/$source" -o "$BUILD/$source.o"
done
xcrun clang -fobjc-arc -target arm64-apple-ios15.0-macabi -isysroot "$sdk" \
    -iframework "$sdk/System/iOSSupport/System/Library/Frameworks" $quiet \
    "$here/differential.m" "$BUILD"/*.o -framework UIKit -framework Foundation -o "$BUILD/differential"
"$BUILD/differential"
