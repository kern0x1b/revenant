#!/bin/sh
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
UIKIT=${UIKIT:-$here/../../../../packages/frameworks/apple-backports/UIKit}
BUILD=${BUILD:-$(runs_fresh revenant-imageflip)}
sdk=$(xcrun --show-sdk-path)
quiet="-Wno-deprecated-declarations -Wno-unguarded-availability-new -Wno-incomplete-implementation -Wno-objc-protocol-method-implementation -Wno-nullability-completeness"
target="-target arm64-apple-ios15.0-macabi -isysroot $sdk -iframework $sdk/System/iOSSupport/System/Library/Frameworks"
mkdir -p "$BUILD"
xcrun clang -fobjc-arc -fvisibility=hidden $target $quiet -c "$UIKIT/UIImage+HorizontalFlip.m" -o "$BUILD/plain.o"
printf '#import <UIKit/UIKit.h>\n' > "$BUILD/declarations.h"
runs_xmake l "$here/../prefix_selectors.lua" "$UIKIT/UIImage+HorizontalFlip.m" "$BUILD/UIImage+HorizontalFlip.m" revenantHost_ --declarations="$BUILD/declarations.h" -fobjc-arc $target $quiet -- "$BUILD/plain.o"
xcrun clang -fobjc-arc -fvisibility=hidden $target $quiet -I"$UIKIT" -include "$BUILD/declarations.h" -c "$BUILD/UIImage+HorizontalFlip.m" -o "$BUILD/flip.o"
perl -0777 -pi -e 's/__objc_catlist\0\0/__port_catlist\0\0/g' "$BUILD/flip.o"
xcrun clang -fobjc-arc $target $quiet "$here/differential.m" "$here/../foundation2/host-attach.c" "$BUILD/flip.o" \
    -framework UIKit -framework Foundation -framework CoreGraphics -framework CoreImage -o "$BUILD/differential"
"$BUILD/differential"
