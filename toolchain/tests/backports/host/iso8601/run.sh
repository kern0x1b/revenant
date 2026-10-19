#!/bin/sh
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
FOUNDATION=${FOUNDATION:-$here/../../../../packages/a/apple-backports/Foundation}
BUILD=${BUILD:-$(runs_fresh revenant-iso8601)}
sources=${SOURCES:-$(cat "$here/sources.txt")}
quiet="-Wno-deprecated-declarations -Wno-unguarded-availability-new -Wno-incomplete-implementation -Wno-objc-protocol-method-implementation -Wno-nullability-completeness -Wno-objc-designated-initializers"
rm -rf "$BUILD/plain" "$BUILD/renamed"
mkdir -p "$BUILD/plain" "$BUILD/renamed"
for source in $sources; do
    xcrun clang -fobjc-arc -fvisibility=hidden $quiet -I"$FOUNDATION" -c "$FOUNDATION/$source" -o "$BUILD/plain/$source.o"
done
renames=""
for name in $(xcrun nm -gU "$BUILD"/plain/*.o | awk 'NF == 3 {print $3}' | grep -E '^_OBJC_CLASS_\$_' | sed -e 's/^_OBJC_CLASS_\$_//' | sort -u); do
    renames="$renames -D$name=RevenantHost$name"
done
echo "renamed:$renames"
for source in $sources; do
    xcrun clang -fobjc-arc -fvisibility=hidden $quiet $renames -I"$FOUNDATION" -c "$FOUNDATION/$source" -o "$BUILD/renamed/$source.o"
done
xcrun clang -fobjc-arc $quiet "$here/differential.m" "$BUILD"/renamed/*.o -framework Foundation -o "$BUILD/differential"
"$BUILD/differential"
