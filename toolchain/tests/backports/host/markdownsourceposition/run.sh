#!/bin/sh
# run.sh — NSAttributedStringMarkdownSourcePosition against the system's own, in one process.
#
# The port's source is compiled with its class and its C symbol renamed (the same mechanism
# uikit2, dynamics and presentationintent use, from uikit2/renames.sh), so the backport's class and
# the system's are two classes that never meet, and every case can hold their answers side by side.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
sources=${SOURCES:-$here/../../../../packages/frameworks/apple-backports/Foundation}
harness=${HARNESS:-$here/../../device}
build=${BUILD:-$(runs_fresh revenant-markdownsourceposition)}
sdk=$(xcrun --show-sdk-path)
target="-target arm64-apple-ios15.0-macabi -isysroot $sdk -iframework $sdk/System/iOSSupport/System/Library/Frameworks"
flags="-fobjc-arc -fvisibility=hidden -Wall -Wno-deprecated-declarations -Wno-unguarded-availability-new -Wno-incomplete-implementation -Wno-objc-property-implementation -Wno-nullability-completeness"
mkdir -p "$build/plain" "$build/ported"

. "$here/../uikit2/renames.sh"

for file in NSAttributedStringMarkdownSourcePosition.m; do
    xcrun clang $target $flags -w -c "$sources/$file" -o "$build/plain/$file.o"
done
renames "$build/plain/NSAttributedStringMarkdownSourcePosition.m.o" > "$build/flags"
# shellcheck disable=SC2046
xcrun clang $target $flags $(cat "$build/flags") -c "$sources/NSAttributedStringMarkdownSourcePosition.m" \
    -o "$build/ported/NSAttributedStringMarkdownSourcePosition.o"
xcrun clang $target -fobjc-arc -Wall -I"$harness" "$here/test.m" "$harness/check.m" \
    "$build/ported/NSAttributedStringMarkdownSourcePosition.o" -framework Foundation -o "$build/test"
if "$build/test" > "$build/test.log" 2>&1; then result=0; else result=$?; fi
grep -v '^ok ' "$build/test.log" || true
echo "markdownsourceposition: exit=$result log=$build/test.log"
exit "$result"
