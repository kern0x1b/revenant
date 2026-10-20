#!/bin/sh
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
UIKIT=${UIKIT:-$here/../../../../packages/a/apple-backports/UIKit}
DEVICE=${DEVICE:-$here/../../device}
BUILD=${BUILD:-$(runs_fresh revenant-spring)}
EXPECTATIONS=${EXPECTATIONS:-$DEVICE/spring-expectations.h}
sdk=$(xcrun --show-sdk-path)
quiet="-Wno-deprecated-declarations -Wno-unguarded-availability-new -Wno-incomplete-implementation -Wno-objc-protocol-method-implementation -Wno-nullability-completeness"
target="-target arm64-apple-ios15.0-macabi -isysroot $sdk -iframework $sdk/System/iOSSupport/System/Library/Frameworks"
mkdir -p "$BUILD"
xcrun clang -fobjc-arc -fvisibility=hidden $target $quiet -c "$UIKIT/CASpringAnimation+InitialVelocity.m" -o "$BUILD/plain.o"
printf '#import <QuartzCore/QuartzCore.h>\n' > "$BUILD/declarations.h"
runs_xmake l "$here/../prefix_selectors.lua" "$UIKIT/CASpringAnimation+InitialVelocity.m" "$BUILD/CASpringAnimation+InitialVelocity.m" revenantHost_ \
    --declarations="$BUILD/declarations.h" -fobjc-arc $target $quiet -- "$BUILD/plain.o"
xcrun clang -fobjc-arc -fvisibility=hidden $target $quiet -I"$UIKIT" -include "$BUILD/declarations.h" \
    -c "$BUILD/CASpringAnimation+InitialVelocity.m" -o "$BUILD/spring.o"
perl -0777 -pi -e 's/__objc_catlist\0\0/__port_catlist\0\0/g' "$BUILD/spring.o"
xcrun clang -fobjc-arc $target $quiet -I"$DEVICE" "$here/differential.m" "$here/../foundation2/host-attach.c" \
    "$BUILD/spring.o" -framework QuartzCore -framework Foundation -o "$BUILD/differential"
"$BUILD/differential" "$BUILD/expectations.json"
xmake l "$here/../../common/embed.lua" "$BUILD/expectations.json" "$EXPECTATIONS" foundation2_expectations
sed -i '' 's/foundation2_expectations/spring_expectations/' "$EXPECTATIONS"
