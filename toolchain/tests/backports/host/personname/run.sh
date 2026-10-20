#!/bin/sh
# run.sh — the person name components formatter against the system's own, in one process.
#
# The port's class is compiled under a name of its own (uikit2/renames.sh with "*", which renames the
# classes and leaves the selectors alone, so each side has a class of its own and the two never meet),
# which is the mechanism a class the port implements itself needs: a category's selectors would have
# to be renamed as well, and a -D rename would rename the same selector in an SDK header.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
sources=${SOURCES:-$here/../../../../packages/frameworks/apple-backports/Foundation}
harness=${HARNESS:-$here/../../device}
build=${BUILD:-$(runs_fresh revenant-personname)}
sdk=$(xcrun --show-sdk-path)
target="-target arm64-apple-ios15.0-macabi -isysroot $sdk -iframework $sdk/System/iOSSupport/System/Library/Frameworks"
flags="-fobjc-arc -fvisibility=hidden -Wall -Wno-deprecated-declarations -Wno-unguarded-availability-new -Wno-incomplete-implementation -Wno-objc-property-implementation -Wno-nullability-completeness"
file=NSPersonNameComponentsFormatter9.m
mkdir -p "$build/plain" "$build/ported"
xcrun clang $target $flags -w -c "$sources/$file" -o "$build/plain/$file.o"
. "$here/../uikit2/renames.sh"
renames "$build/plain/$file.o" "*" > "$build/flags"
# shellcheck disable=SC2046
xcrun clang $target $flags $(cat "$build/flags") -c "$sources/$file" -o "$build/ported/$file.o"
xcrun clang $target -fobjc-arc -Wall -I"$harness" "$here/test.m" "$harness/check.m" "$build/ported/$file.o" \
    -framework Foundation -framework CoreServices -o "$build/test"
if "$build/test" > "$build/test.log" 2>&1; then result=0; else result=$?; fi
grep -v '^ok ' "$build/test.log" || true
echo "personname: exit=$result log=$build/test.log"
exit "$result"
