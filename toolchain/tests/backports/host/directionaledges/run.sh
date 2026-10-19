#!/bin/sh
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
UIKIT=${UIKIT:-$here/../../../../packages/a/apple-backports/UIKit}
DEVICE=${DEVICE:-$here/../../device}
BUILD=${BUILD:-$(runs_fresh revenant-directionaledges)}
EXPECTATIONS=${EXPECTATIONS:-$DEVICE/directionaledges-expectations.h}
sdk=$(xcrun --show-sdk-path)
quiet="-Wno-deprecated-declarations -Wno-unguarded-availability-new -Wno-incomplete-implementation -Wno-objc-protocol-method-implementation -Wno-nullability-completeness"
renames="-DNSDirectionalEdgeInsetsZero=RevenantHostNSDirectionalEdgeInsetsZero -DNSStringFromDirectionalEdgeInsets=RevenantHostNSStringFromDirectionalEdgeInsets -DNSDirectionalEdgeInsetsFromString=RevenantHostNSDirectionalEdgeInsetsFromString"
mkdir -p "$BUILD"
xcrun clang -fobjc-arc -fvisibility=hidden -target arm64-apple-ios15.0-macabi -isysroot "$sdk" \
    -iframework "$sdk/System/iOSSupport/System/Library/Frameworks" $quiet $renames \
    -c "$UIKIT/NSDirectionalEdgeInsets.m" -o "$BUILD/NSDirectionalEdgeInsets.o"
perl -0777 -pi -e 's/__objc_catlist\0\0/__revenant_catlist/g' "$BUILD/NSDirectionalEdgeInsets.o"
xcrun clang -fobjc-arc -target arm64-apple-ios15.0-macabi -isysroot "$sdk" \
    -iframework "$sdk/System/iOSSupport/System/Library/Frameworks" $quiet -I"$DEVICE" \
    "$here/differential.m" "$here/../foundation2/host-attach.c" "$DEVICE/directionaledges-cases.m" \
    "$BUILD/NSDirectionalEdgeInsets.o" -framework UIKit -framework Foundation -o "$BUILD/differential"
"$BUILD/differential" "$BUILD/expectations.json"
xmake l "$here/../../common/embed.lua" "$BUILD/expectations.json" "$EXPECTATIONS" foundation2_expectations
sed -i '' 's/foundation2_expectations/directionaledges_expectations/' "$EXPECTATIONS"
