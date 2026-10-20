#!/bin/sh
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
sources=${TRAITSTYLE_SOURCES:-$here/../../../../packages/frameworks/apple-backports/UIKit}
harness=${TRAITSTYLE_HARNESS:-$here/../../device}
build=${TRAITSTYLE_BUILD:-$(runs_folder revenant-traitstyle-host)}
sdk=$(xcrun --show-sdk-path)
target="-target arm64-apple-ios15.0-macabi -isysroot $sdk -iframework $sdk/System/iOSSupport/System/Library/Frameworks"
frameworks="-framework UIKit -framework QuartzCore -framework CoreGraphics -framework Foundation"
flags="-fobjc-arc -fvisibility=hidden -w"
files="UITraitCollection.m RevenantTraitObservers.m UITraitCollection+Appearance13.m UITraitCollection+ForceTouch.m"
[ -f "$sources/UITraitCollection+UserInterfaceStyle.m" ] && files="$files UITraitCollection+UserInterfaceStyle.m"
rm -rf "$build"
mkdir -p "$build/plain" "$build/ours"
objects=""
for file in $files; do
    xcrun clang $target $flags -c "$sources/$file" -o "$build/plain/$file.o"
    objects="$objects $build/plain/$file.o"
done
renames=$(nm -m $objects | grep -v '(undefined)' | sed -n 's/.* external _OBJC_CLASS_\$_\(.*\)/-D\1=RevenantHost\1/p' | sort -u)
printf '%s\n' $renames > "$build/flags"
built=""
for file in $files; do
    xcrun clang $target $flags $(cat "$build/flags") -c "$sources/$file" -o "$build/ours/$file.o"
    built="$built $build/ours/$file.o"
done
xcrun clang $target -fobjc-arc -Wall -Wno-deprecated-declarations -Wno-unguarded-availability-new -I"$harness" \
    "$here/traitstyle_test.m" "$harness/check.m" $built $frameworks -o "$build/traitstyle_test"
"$build/traitstyle_test" > "$build/log" 2>&1 && result=0 || result=$?
grep -v '^ok ' "$build/log" || true
tail -1 "$build/log"
echo "log=$build/log"
exit $result
