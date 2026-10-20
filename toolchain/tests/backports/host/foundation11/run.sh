#!/bin/sh
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
FOUNDATION=${FOUNDATION:-$here/../../../../packages/a/apple-backports/Foundation}
DEVICE=${DEVICE:-$here/../../device}
BUILD=${BUILD:-$(runs_fresh revenant-foundation11)}
EXPECTATIONS=${EXPECTATIONS:-$DEVICE/foundation11-expectations.h}
sources=${SOURCES:-$(cat "$here/sources.txt")}
quiet="-Wno-deprecated-declarations -Wno-unguarded-availability-new -Wno-incomplete-implementation -Wno-objc-protocol-method-implementation -Wno-nullability-completeness"
rm -rf "$BUILD/plain" "$BUILD/prefixed" "$BUILD/renamed"
mkdir -p "$BUILD/plain" "$BUILD/renamed"
for source in $sources; do
    xcrun clang -fobjc-arc -fvisibility=hidden $quiet -c "$FOUNDATION/$source" -o "$BUILD/plain/$source.o"
done
renames=""
for name in $(xcrun nm -gU "$BUILD"/plain/*.o | awk 'NF == 3 {print $3}' | grep -E '^_OBJC_CLASS_\$_|^_[A-Za-z][A-Za-z0-9]*$' | sed -e 's/^_OBJC_CLASS_\$_//' -e 's/^_//' | sort -u); do
    renames="$renames -D$name=RevenantHost$name"
done
mkdir -p "$BUILD/prefixed"
printf '#import <Foundation/Foundation.h>\n' > "$BUILD/prefixed/declarations.h"
for source in $sources; do
    runs_xmake l "$here/../prefix_selectors.lua" "$FOUNDATION/$source" "$BUILD/prefixed/$source" charonHost_ --declarations="$BUILD/prefixed/declarations.h" -fobjc-arc $quiet -- "$BUILD"/plain/*.o
done
for source in $sources; do
    xcrun clang -fobjc-arc -fvisibility=hidden $quiet $renames -I"$FOUNDATION" -include "$BUILD/prefixed/declarations.h" -c "$BUILD/prefixed/$source" -o "$BUILD/renamed/$source.o"
    perl -0777 -pi -e 's/__objc_catlist\0\0/__revenant_catlist/g' "$BUILD/renamed/$source.o"
done
xcrun clang -fobjc-arc $quiet -I"$DEVICE" "$here/differential.m" "$here/../foundation2/host-attach.c" \
    "$DEVICE/foundation11-cases.m" "$BUILD"/renamed/*.o -framework Foundation -o "$BUILD/differential"
"$BUILD/differential" "$BUILD/expectations.json"
xmake l "$here/../../common/embed.lua" "$BUILD/expectations.json" "$EXPECTATIONS" foundation2_expectations
sed -i '' 's/foundation2_expectations/foundation11_expectations/' "$EXPECTATIONS"
