#!/bin/sh
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
UIKIT=${UIKIT:-$here/../../../../packages/frameworks/apple-backports/UIKit}
harness=${ANIMATORSCRUB_HARNESS:-$here/../../device}
build=${ANIMATORSCRUB_BUILD:-$(runs_folder revenant-animatorscrub-host)}
sources=${SOURCES:-$(cat "$here/sources.txt")}
sdk=$(xcrun --show-sdk-path)
target="-target arm64-apple-ios15.0-macabi -isysroot $sdk -iframework $sdk/System/iOSSupport/System/Library/Frameworks"
quiet="-w"
rm -rf "$build"
mkdir -p "$build/plain" "$build/renamed"
for source in $sources; do
    xcrun clang $target -fobjc-arc -fvisibility=hidden $quiet -I"$UIKIT" -c "$UIKIT/$source" -o "$build/plain/$source.o"
done
renames=""
for name in $(xcrun nm -gU "$build"/plain/*.o | awk 'NF == 3 {print $3}' | grep -E '^_OBJC_CLASS_\$_' | sed -e 's/^_OBJC_CLASS_\$_//' | sort -u); do
    renames="$renames -D$name=RevenantHost$name"
done
for source in $sources; do
    xcrun clang $target -fobjc-arc -fvisibility=hidden $quiet $renames -I"$UIKIT" -c "$UIKIT/$source" -o "$build/renamed/$source.o"
done
xcrun clang $target -fobjc-arc -Wall -Wno-deprecated-declarations -Wno-unguarded-availability-new -I"$harness" -I"$UIKIT" \
    "$here/differential.m" "$harness/check.m" "$build"/renamed/*.o \
    -framework UIKit -framework QuartzCore -framework CoreGraphics -framework Foundation -o "$build/differential"
"$build/differential" > "$build/log" 2>&1 && result=0 || result=$?
grep -v '^ok ' "$build/log" || true
tail -1 "$build/log"
echo "log=$build/log"
exit $result
