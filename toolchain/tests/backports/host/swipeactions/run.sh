#!/bin/sh
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
UIKIT=${UIKIT:-$here/../../../../packages/frameworks/apple-backports/UIKit}
harness=${SWIPEACTIONS_HARNESS:-$here/../../device}
build=${SWIPEACTIONS_BUILD:-$(runs_folder revenant-swipeactions-host)}
sources="UIContextualAction.m UISwipeActionsConfiguration.m"
sdk=$(xcrun --show-sdk-path)
target="-target arm64-apple-ios15.0-macabi -isysroot $sdk -iframework $sdk/System/iOSSupport/System/Library/Frameworks"
renames="-DUIContextualAction=RevenantHostUIContextualAction -DUISwipeActionsConfiguration=RevenantHostUISwipeActionsConfiguration"
rm -rf "$build"
mkdir -p "$build"
objects=""
for source in $sources; do
    xcrun clang $target -fobjc-arc -fvisibility=hidden -w $renames -I"$UIKIT" -c "$UIKIT/$source" -o "$build/$source.o"
    objects="$objects $build/$source.o"
done
xcrun clang $target -fobjc-arc -Wall -Wno-deprecated-declarations -Wno-unguarded-availability-new -I"$harness" \
    "$here/differential.m" "$harness/check.m" $objects \
    -framework UIKit -framework Foundation -o "$build/differential"
"$build/differential" > "$build/log" 2>&1 && result=0 || result=$?
grep -v '^ok ' "$build/log" || true
echo "log=$build/log"
exit $result
