#!/bin/sh
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
SOURCES=${SOURCES:-$here/../../../../packages/a/apple-backports/Foundation}
BUILD=${BUILD:-$(runs_fresh revenant-suitedefaults)}
sdk=$(xcrun --show-sdk-path)
quiet="-Wno-deprecated-declarations -Wno-unguarded-availability-new -Wno-incomplete-implementation -Wno-objc-protocol-method-implementation -Wno-nullability-completeness"
target="-target arm64-apple-ios15.0-macabi -isysroot $sdk -iframework $sdk/System/iOSSupport/System/Library/Frameworks"
mkdir -p "$BUILD"
xcrun clang -fobjc-arc -fvisibility=hidden $target $quiet -c "$SOURCES/NSUserDefaults+SuiteName.m" -o "$BUILD/plain.o"
printf '#import <Foundation/Foundation.h>\n' > "$BUILD/declarations.h"
runs_xmake l "$here/../prefix_selectors.lua" "$SOURCES/NSUserDefaults+SuiteName.m" "$BUILD/NSUserDefaults+SuiteName.m" revenantHost_ --declarations="$BUILD/declarations.h" -fobjc-arc $target $quiet -- "$BUILD/plain.o"
xcrun clang -fobjc-arc -fvisibility=hidden $target $quiet -I"$SOURCES" -include "$BUILD/declarations.h" -c "$BUILD/NSUserDefaults+SuiteName.m" -o "$BUILD/suite.o"
perl -0777 -pi -e 's/__objc_catlist\0\0/__port_catlist\0\0/g' "$BUILD/suite.o"
xcrun clang -fobjc-arc $target $quiet "$here/differential.m" "$here/../foundation2/host-attach.c" "$BUILD/suite.o" \
    -framework Foundation -framework CoreGraphics -o "$BUILD/differential"
SUITE_EXPECTATIONS="${SUITE_EXPECTATIONS:-$here/../../device/suitedefaults-expectations.h}" "$BUILD/differential"
