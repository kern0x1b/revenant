#!/bin/sh
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
SOURCES=${SOURCES:-$here/../../../../packages/a/apple-backports/Foundation}
BUILD=${BUILD:-$(runs_fresh charon-appgroup)}
sdk=$(xcrun --show-sdk-path)
quiet="-Wno-deprecated-declarations -Wno-unguarded-availability-new -Wno-incomplete-implementation -Wno-objc-protocol-method-implementation -Wno-nullability-completeness"
target="-target arm64-apple-ios15.0-macabi -isysroot $sdk -iframework $sdk/System/iOSSupport/System/Library/Frameworks"
mkdir -p "$BUILD"
xcrun clang -fobjc-arc -fvisibility=hidden $target $quiet -c "$SOURCES/NSFileManager+AppGroup.m" -o "$BUILD/plain.o"
printf '#import <Foundation/Foundation.h>\n' > "$BUILD/declarations.h"
python3 "$here/../prefix_selectors.py" "$SOURCES/NSFileManager+AppGroup.m" "$BUILD/NSFileManager+AppGroup.m" charonHost_ --declarations="$BUILD/declarations.h" -fobjc-arc $target $quiet -- "$BUILD/plain.o"
xcrun clang -fobjc-arc -fvisibility=hidden $target $quiet -I"$SOURCES" -include "$BUILD/declarations.h" -c "$BUILD/NSFileManager+AppGroup.m" -o "$BUILD/group.o"
perl -0777 -pi -e 's/__objc_catlist\0\0/__charon_catlist/g' "$BUILD/group.o"
xcrun clang -fobjc-arc $target $quiet "$here/differential.m" "$here/../foundation2/host-attach.c" "$BUILD/group.o" \
    -framework Foundation -framework CoreGraphics -o "$BUILD/differential"
APPGROUP_EXPECTATIONS="${APPGROUP_EXPECTATIONS:-$here/../../device/appgroup-expectations.h}" "$BUILD/differential"
