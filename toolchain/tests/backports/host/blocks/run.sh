#!/bin/sh
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
FOUNDATION=${FOUNDATION:-$here/../../../../packages/a/apple-backports/Foundation}
BUILD=${BUILD:-$(runs_fresh revenant-blocks)}
sources="NSTimer+Block.m NSThread+Block.m NSRunLoop+Block.m NSFileManager+TemporaryDirectory.m"
quiet="-Wno-deprecated-declarations -Wno-unguarded-availability-new -Wno-incomplete-implementation -Wno-objc-protocol-method-implementation -Wno-nullability-completeness"
rm -rf "$BUILD/plain" "$BUILD/prefixed" "$BUILD/renamed"
mkdir -p "$BUILD/plain" "$BUILD/prefixed" "$BUILD/renamed"
for source in $sources; do
    xcrun clang -fobjc-arc -fvisibility=hidden $quiet -I"$FOUNDATION" -c "$FOUNDATION/$source" -o "$BUILD/plain/$source.o"
done
printf '#import <Foundation/Foundation.h>\n' > "$BUILD/prefixed/declarations.h"
for source in $sources; do
    runs_xmake l "$here/../prefix_selectors.lua" "$FOUNDATION/$source" "$BUILD/prefixed/$source" charonHost_ --declarations="$BUILD/prefixed/declarations.h" -fobjc-arc $quiet -I"$FOUNDATION" -- "$BUILD"/plain/*.o
done
for source in $sources; do
    xcrun clang -fobjc-arc -fvisibility=hidden $quiet -I"$FOUNDATION" -include "$BUILD/prefixed/declarations.h" -c "$BUILD/prefixed/$source" -o "$BUILD/renamed/$source.o"
    perl -0777 -pi -e 's/__objc_catlist\0\0/__revenant_catlist/g' "$BUILD/renamed/$source.o"
done
xcrun clang -fobjc-arc $quiet "$here/differential.m" "$here/../foundation2/host-attach.c" "$BUILD"/renamed/*.o -framework Foundation -o "$BUILD/differential"
"$BUILD/differential"
