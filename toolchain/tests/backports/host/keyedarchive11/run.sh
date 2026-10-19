#!/bin/sh
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
FOUNDATION=${FOUNDATION:-$here/../../../../packages/a/apple-backports/Foundation}
DEVICE=${DEVICE:-$here/../../device}
BUILD=${BUILD:-$(runs_fresh charon-keyedarchive11)}
EXPECTATIONS=${EXPECTATIONS:-$DEVICE/keyedarchive11-expectations.h}
sources=${SOURCES:-$(cat "$here/sources.txt")}
quiet="-Wno-deprecated-declarations -Wno-unguarded-availability-new -Wno-incomplete-implementation -Wno-objc-protocol-method-implementation -Wno-nullability-completeness"
rm -rf "$BUILD/plain" "$BUILD/prefixed" "$BUILD/renamed"
mkdir -p "$BUILD/plain" "$BUILD/prefixed" "$BUILD/renamed"
for source in $sources; do
    xcrun clang -fobjc-arc -fvisibility=hidden $quiet -c "$FOUNDATION/$source" -o "$BUILD/plain/$source.o"
done
printf '#import <Foundation/Foundation.h>\n' > "$BUILD/prefixed/declarations.h"
for source in $sources; do
    python3 "$here/../prefix_selectors.py" "$FOUNDATION/$source" "$BUILD/prefixed/$source" charonHost_ --declarations="$BUILD/prefixed/declarations.h" -fobjc-arc $quiet -- "$BUILD"/plain/*.o
done
for source in $sources; do
    xcrun clang -fobjc-arc -fvisibility=hidden $quiet -I"$FOUNDATION" -include "$BUILD/prefixed/declarations.h" -c "$BUILD/prefixed/$source" -o "$BUILD/renamed/$source.o"
    perl -0777 -pi -e 's/__objc_catlist\0\0/__charon_catlist/g' "$BUILD/renamed/$source.o"
done
xcrun clang -fobjc-arc $quiet -I"$DEVICE" "$here/differential.m" "$here/../foundation2/host-attach.c" \
    "$DEVICE/keyedarchive11-cases.m" "$BUILD"/renamed/*.o -framework Foundation -o "$BUILD/differential"
"$BUILD/differential" "$BUILD/expectations.json"
xmake l "$here/../../common/embed.lua" "$BUILD/expectations.json" "$EXPECTATIONS" foundation2_expectations
sed -i '' 's/foundation2_expectations/keyedarchive11_expectations/' "$EXPECTATIONS"
