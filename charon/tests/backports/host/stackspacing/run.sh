#!/bin/sh
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
sources=${STACKSPACING_SOURCES:-$here/../../../../packages/a/apple-backports/UIKit}
harness=${STACKSPACING_HARNESS:-$here/../../device}
build=${STACKSPACING_BUILD:-$(runs_folder charon-stackspacing-host)}
sdk=$(xcrun --show-sdk-path)
target="-target arm64-apple-ios15.0-macabi -isysroot $sdk -iframework $sdk/System/iOSSupport/System/Library/Frameworks"
files="NSLayoutAnchor.m UIView+Anchors.m UILayoutGuide.m UIView+LayoutGuides.m NSLayoutAnchor+SystemSpacing.m UIStackView.m"
frameworks="-framework UIKit -framework QuartzCore -framework CoreGraphics -framework Foundation"
rm -rf "$build"
mkdir -p "$build/plain"
for file in $files; do
    xcrun clang $target -fobjc-arc -fvisibility=hidden -w -c "$sources/$file" -o "$build/plain/$file.o"
done
plain=""
for file in $files; do plain="$plain $build/plain/$file.o"; done
rename() {
    awk '{
        t = $0
        if (t ~ /^set[A-Z]/) { rest = substr(t, 4); print "-D" t "=setCharonHost" rest; print "-D" tolower(substr(rest, 1, 1)) substr(rest, 2) "=charonHost" rest }
        else if (t ~ /^is[A-Z]/) { rest = substr(t, 3); print "-D" t "=isCharonHost" rest; print "-D" tolower(substr(rest, 1, 1)) substr(rest, 2) "=charonHost" rest }
        else print "-D" t "=charonHost" toupper(substr(t, 1, 1)) substr(t, 2)
    }' | sort -u
}
classes=$(nm -g $plain | sed -n 's/.* S _OBJC_CLASS_\$_\(.*\)/-D\1=CharonHost\1/p' | sort -u)
selectors=$(nm $plain | sed -n 's/.*[-+]\[[A-Za-z_]*([A-Za-z]*) \([A-Za-z_]*\).*\]$/\1/p' | grep -v '^charon_' | rename)
printf '%s\n' $classes $selectors > "$build/flags"
mkdir -p "$build/ours"
objects=""
for file in $files; do
    xcrun clang $target -fobjc-arc -fvisibility=hidden -w $(cat "$build/flags") -c "$sources/$file" -o "$build/ours/$file.o"
    objects="$objects $build/ours/$file.o"
done
xcrun clang $target -fobjc-arc -Wall -Wno-deprecated-declarations -Wno-unguarded-availability-new -I"$harness" \
    "$here/differential.m" "$harness/check.m" $objects $frameworks -o "$build/differential"
"$build/differential" > "$build/log" 2>&1 && result=0 || result=$?
grep -v '^ok \|^  system \|^  ours ' "$build/log" || true
tail -1 "$build/log"
echo "log=$build/log"
exit $result
