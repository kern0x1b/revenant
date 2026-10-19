#!/bin/sh
# run.sh — NSPresentationIntent against the system's own, in one process.
#
# The port's sources are compiled with their class and their selectors renamed (the same mechanism
# uikit2 and dynamics use, from uikit2/renames.sh), so the backport's NSPresentationIntent and the
# system's are two classes that never meet, and every case can hold their answers side by side.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
sources=${SOURCES:-$here/../../../../packages/a/apple-backports/Foundation}
harness=${HARNESS:-$here/../../device}
build=${BUILD:-$(runs_fresh charon-presentationintent)}
sdk=$(xcrun --show-sdk-path)
target="-target arm64-apple-ios15.0-macabi -isysroot $sdk -iframework $sdk/System/iOSSupport/System/Library/Frameworks"
flags="-fobjc-arc -fvisibility=hidden -Wall -Wno-deprecated-declarations -Wno-unguarded-availability-new -Wno-incomplete-implementation -Wno-objc-property-implementation -Wno-nullability-completeness"
mkdir -p "$build/plain" "$build/ported"

. "$here/../uikit2/renames.sh"

for file in NSPresentationIntent15.m; do
    xcrun clang $target $flags -w -c "$sources/$file" -o "$build/plain/$file.o"
done
renames "$build/plain/NSPresentationIntent15.m.o" "*" > "$build/flags"
# shellcheck disable=SC2046
xcrun clang $target $flags $(cat "$build/flags") -c "$sources/NSPresentationIntent15.m" -o "$build/ported/NSPresentationIntent15.o"
xcrun clang $target -fobjc-arc -Wall -I"$harness" "$here/test.m" "$harness/check.m" "$build/ported/NSPresentationIntent15.o" \
    -framework Foundation -o "$build/test"
if "$build/test" > "$build/test.log" 2>&1; then result=0; else result=$?; fi
grep -v '^ok ' "$build/test.log" || true
echo "presentationintent: exit=$result log=$build/test.log"
exit "$result"
