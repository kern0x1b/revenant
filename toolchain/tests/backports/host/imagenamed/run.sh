#!/bin/sh
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
UIKIT=${UIKIT:-$here/../../../../packages/a/apple-backports/UIKit}
BUILD=${BUILD:-$(runs_fresh revenant-imagenamed)}
sdk=$(xcrun --show-sdk-path)
quiet="-Wno-deprecated-declarations -Wno-unguarded-availability-new -Wno-incomplete-implementation -Wno-objc-protocol-method-implementation -Wno-nullability-completeness"
target="-target arm64-apple-ios15.0-macabi -isysroot $sdk -iframework $sdk/System/iOSSupport/System/Library/Frameworks"
mkdir -p "$BUILD"
xcrun clang -fobjc-arc -fvisibility=hidden $target $quiet -c "$UIKIT/UIImage+NamedInBundle.m" -o "$BUILD/plain.o"
printf '#import <UIKit/UIKit.h>\n' > "$BUILD/declarations.h"
runs_xmake l "$here/../prefix_selectors.lua" "$UIKIT/UIImage+NamedInBundle.m" "$BUILD/UIImage+NamedInBundle.m" revenantHost_ --declarations="$BUILD/declarations.h" -fobjc-arc $target $quiet -- "$BUILD/plain.o"
xcrun clang -fobjc-arc -fvisibility=hidden $target $quiet -I"$UIKIT" -include "$BUILD/declarations.h" -c "$BUILD/UIImage+NamedInBundle.m" -o "$BUILD/named.o"
perl -0777 -pi -e 's/__objc_catlist\0\0/__port_catlist\0\0/g' "$BUILD/named.o"
xcrun clang -fobjc-arc $target $quiet "$here/differential.m" "$here/../foundation2/host-attach.c" "$BUILD/named.o" \
    -framework UIKit -framework Foundation -framework CoreGraphics -o "$BUILD/differential"
IMAGENAMED_EXPECTATIONS="${IMAGENAMED_EXPECTATIONS:-$here/../../device/imagenamed-expectations.h}" "$BUILD/differential"
