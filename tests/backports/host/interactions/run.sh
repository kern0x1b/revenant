#!/bin/sh
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
. "$here/../../common/generated.sh"
ensure_generated "$here" UIKit
sources=${INTERACTIONS_SOURCES:-$here/../../../../packages/a/apple-backports/UIKit}
# a source of the folder, or one the generated layer writes beside it in .gen/UIKit (UIKitConstants110.m is one of those)
generated=$here/../../../../packages/a/apple-backports/.gen/UIKit
source_of() {
    if [ -f "$sources/$1" ]; then printf "%s\n" "$sources/$1"; else printf "%s\n" "$generated/$1"; fi
}
harness=${INTERACTIONS_HARNESS:-$here/../../device}
build=${INTERACTIONS_BUILD:-$(runs_folder charon-interactions-host)}
sdk=$(xcrun --show-sdk-path)
target="-target arm64-apple-ios15.0-macabi -isysroot $sdk -iframework $sdk/System/iOSSupport/System/Library/Frameworks"
# UIKitConstants110.m, and the name it is called here was stale: the constants were split by the release the
# ladder places them at, and the 11.0 file is UIKitConstants110.m - UIActivityTypeMarkupAsPDF and
# UIImagePickerControllerImageURL are in it (measured with grep over the port). The harness named
# UIKitConstants11.m, which no longer exists, and clang said "no such file or directory" and then
# "no input files", so the test guarded nothing.
files="UIView+Interactions.m NSObject+AccessibilityAttributedStrings.m UIKitConstants110.m"
constants="UIAccessibilitySpeechAttributeQueueAnnouncement UIAccessibilitySpeechAttributeIPANotation UIAccessibilityTextAttributeHeadingLevel UIAccessibilityTextAttributeCustom UIImagePickerControllerImageURL UIActivityTypeMarkupAsPDF UIAccessibilityVoiceOverStatusDidChangeNotification"
frameworks="-framework UIKit -framework Foundation -framework CoreGraphics"
rm -rf "$build"
mkdir -p "$build/plain" "$build/ours"
for file in $files; do
    xcrun clang $target -fobjc-arc -fvisibility=hidden -w -c "$(source_of "$file")" -o "$build/plain/$file.o"
done
plain=""
for file in $files; do plain="$plain $build/plain/$file.o"; done
rename() {
    awk '{
        t = $0
        if (t ~ /^set[A-Z]/) { rest = substr(t, 4); print "-D" t "=setCharonHost" rest; print "-D" tolower(substr(rest, 1, 1)) substr(rest, 2) "=charonHost" rest }
        else print "-D" t "=charonHost" toupper(substr(t, 1, 1)) substr(t, 2)
    }' | sort -u
}
selectors=$(nm $plain | sed -n 's/.*[-+]\[[A-Za-z_]*([A-Za-z]*) \([A-Za-z_]*\).*\]$/\1/p' | grep -v '^charon_' | rename)
for constant in $constants; do selectors="$selectors -D$constant=CharonHost$constant"; done
printf '%s\n' $selectors > "$build/flags"
objects=""
for file in $files; do
    xcrun clang $target -fobjc-arc -fvisibility=default -w $(cat "$build/flags") -c "$(source_of "$file")" -o "$build/ours/$file.o"
    objects="$objects $build/ours/$file.o"
done
xcrun clang $target -fobjc-arc -Wall -Wno-deprecated-declarations -Wno-unguarded-availability-new -I"$harness" \
    "$here/differential.m" "$harness/check.m" $objects $frameworks -o "$build/differential"
"$build/differential" > "$build/log" 2>&1 && result=0 || result=$?
grep -v '^ok ' "$build/log" || true
echo "log=$build/log"
exit $result
