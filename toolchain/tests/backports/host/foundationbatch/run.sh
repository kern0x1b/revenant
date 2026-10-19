#!/bin/sh
# run.sh — the second N-Z Foundation batch against the system's own, in one process.
#
# Each source is compiled once plain, prefix_selectors.py renames the selectors it defines by their
# place in the AST, and the renamed objects are attached beside the system's Foundation through
# foundation2/host-attach.c. A category needs that mechanism rather than a -D rename, which would
# rename the same selector in an SDK header where it carries an attribute.
#
# Only the categories are in this build. NSProgress.m, the port's own NSProgress *class*, is not: the
# rewriter leaves a class implementation's methods unrenamed, so a host differential cannot hold that
# one beside the system's. tests/backports/device/foundation15batch.m holds its members.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
sources=${SOURCES:-$here/../../../../packages/a/apple-backports/Foundation}
harness=${HARNESS:-$here/../../device}
build=${BUILD:-$(runs_fresh revenant-foundationbatch)}
sdk=$(xcrun --show-sdk-path)
target="-target arm64-apple-ios15.0-macabi -isysroot $sdk -iframework $sdk/System/iOSSupport/System/Library/Frameworks"
quiet="-Wno-deprecated-declarations -Wno-unguarded-availability-new -Wno-incomplete-implementation -Wno-objc-protocol-method-implementation -Wno-nullability-completeness"
files="NSProgress+State7.m NSNumberFormatter+Context8.m NSURL+Encoding17.m NSURL+Promised8.m"
mkdir -p "$build/plain" "$build/prefixed" "$build/renamed"
printf '#import <Foundation/Foundation.h>\n' > "$build/prefixed/declarations.h"
renamed=""
for file in $files; do
    xcrun clang -fobjc-arc -fvisibility=hidden $target $quiet -c "$sources/$file" -o "$build/plain/$file.o"
    python3 "$here/../prefix_selectors.py" "$sources/$file" "$build/prefixed/$file" charonHost_ \
        --declarations="$build/prefixed/declarations.h" -fobjc-arc $target $quiet -- "$build/plain/$file.o"
    xcrun clang -fobjc-arc -fvisibility=hidden $target $quiet -I"$sources" \
        -include "$build/prefixed/declarations.h" -c "$build/prefixed/$file" -o "$build/renamed/$file.o"
    perl -0777 -pi -e 's/__objc_catlist\0\0/__revenant_catlist/g' "$build/renamed/$file.o"
    renamed="$renamed $build/renamed/$file.o"
done
xcrun clang -fobjc-arc $target $quiet -I"$harness" "$here/test.m" "$here/../foundation2/host-attach.c" \
    "$harness/check.m" $renamed -framework Foundation -o "$build/test"
if "$build/test" > "$build/test.log" 2>&1; then result=0; else result=$?; fi
grep -v '^ok ' "$build/test.log" || true
echo "foundationbatch: exit=$result log=$build/test.log"
exit "$result"
