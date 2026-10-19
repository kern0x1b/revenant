#!/bin/sh
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
FOUNDATION=${FOUNDATION:-$here/../../../../packages/a/apple-backports/Foundation}
BUILD=${BUILD:-$(runs_fresh revenant-rangewithname)}
source=NSTextCheckingResult+RangeWithName.m
quiet="-Wno-unguarded-availability-new -Wno-objc-protocol-method-implementation -Wno-nullability-completeness"
rm -rf "$BUILD/plain" "$BUILD/prefixed" "$BUILD/renamed"
mkdir -p "$BUILD/plain" "$BUILD/prefixed" "$BUILD/renamed"
xcrun clang -fobjc-arc -fvisibility=hidden $quiet -c "$FOUNDATION/$source" -o "$BUILD/plain/$source.o"
printf '#import <Foundation/Foundation.h>\n' > "$BUILD/prefixed/declarations.h"
python3 "$here/../prefix_selectors.py" "$FOUNDATION/$source" "$BUILD/prefixed/$source" charonHost_ --declarations="$BUILD/prefixed/declarations.h" -fobjc-arc $quiet -- "$BUILD"/plain/*.o
xcrun clang -fobjc-arc -fvisibility=hidden $quiet -I"$FOUNDATION" -include "$BUILD/prefixed/declarations.h" -c "$BUILD/prefixed/$source" -o "$BUILD/renamed/$source.o"
perl -0777 -pi -e 's/__objc_catlist\0\0/__revenant_catlist/g' "$BUILD/renamed/$source.o"
xcrun clang -fobjc-arc $quiet "$here/differential.m" "$here/../foundation2/host-attach.c" "$BUILD"/renamed/*.o -framework Foundation -o "$BUILD/differential"
"$BUILD/differential"
