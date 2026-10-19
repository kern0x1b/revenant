#!/bin/sh
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
sources=${ALERT_SOURCES:-$here/../../../../packages/a/apple-backports/UIKit}
harness=${ALERT_HARNESS:-$here/../../device}
build=${ALERT_BUILD:-$(runs_folder charon-alert-host)}
frameworks="$(xcrun --show-sdk-path)/System/iOSSupport/System/Library/Frameworks"
flags="-target arm64-apple-ios15.0-macabi -iframework $frameworks -fobjc-arc -fvisibility=hidden -Wall -Wno-deprecated-declarations"
files="UIAlertAction.m UIAlertController.m UIAlertController+PreferredAction.m"
mkdir -p "$build"
defines=""
for file in $files; do
    xcrun clang $flags -c "$sources/$file" -o "$build/plain.o"
    for class in $(nm "$build/plain.o" | sed -n 's/.* [SsDd] _OBJC_CLASS_\$_\(.*\)$/\1/p'); do
        defines="$defines -D$class=CharonHost$class"
    done
done
objects=""
for file in $files; do
    object="$build/$(basename "$file" .m).o"
    xcrun clang $flags $defines -c "$sources/$file" -o "$object"
    objects="$objects $object"
done
xcrun clang $flags -I"$harness" "$here/test.m" "$harness/check.m" $objects -framework UIKit -framework CoreGraphics -framework Foundation -o "$build/alert-host"
"$build/alert-host"
