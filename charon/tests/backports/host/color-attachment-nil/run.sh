#!/bin/sh
# run.sh - the colour attachment array of MTLRenderPipelineDescriptor (MTLRenderPipelineDescriptor8.m) against Apple's
# object in one process: a nil store resets the slot in place, a stored attachment is a copy, and an index of 8 or
# more asserts on the store and on the read (cases.m).
#
# The port's file is built for macOS beside Apple's Metal, with every class it defines renamed CharonHost<Name>, so
# Apple's classes and the port's coexist.
#
# A MUTANT runs last: a nil store allocates a new attachment instead of resetting the slot, in a copy of the port
# file, and the test must turn red.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
PORT=${PORT:-$here/../../../../packages/a/apple-backports/Metal}
BUILD=${BUILD:-$(runs_folder metal/color-attachment-nil)}
sdk=$(xcrun --show-sdk-path)
target="-target arm64-apple-macos13.0 -isysroot $sdk"
quiet="-Wno-deprecated-declarations -Wno-unguarded-availability-new -Wno-objc-designated-initializers -Wno-incomplete-implementation -Wno-objc-protocol-method-implementation"
gl="-I$here/../metalblit/gl-stub"
source="MTLRenderPipelineDescriptor8.m"

rm -rf "$BUILD/plain" "$BUILD/renamed" "$BUILD/mutant-src"
mkdir -p "$BUILD/plain" "$BUILD/renamed" "$BUILD/mutant-src"

: > "$BUILD/classes.txt"
xcrun clang $target -fobjc-arc -fvisibility=hidden $quiet $gl -I"$PORT" -c "$PORT/$source" -o "$BUILD/plain/$source.o"
xcrun nm -gU "$BUILD/plain/$source.o" | awk 'NF == 3 {print $3}' | grep -E '^_OBJC_CLASS_\$_' | sed -e 's/^_OBJC_CLASS_\$_//' >> "$BUILD/classes.txt"
renames=""
for name in $(sort -u "$BUILD/classes.txt"); do
    renames="$renames -D$name=CharonHost$name"
done

xcrun clang $target -fobjc-arc -fvisibility=hidden $quiet $gl $renames -I"$PORT" -c "$PORT/$source" -o "$BUILD/renamed/$source.o"

xcrun clang $target -fobjc-arc $quiet -I"$here" "$here/cases.m" "$BUILD/renamed/$source.o" \
    -framework Foundation -framework Metal -o "$BUILD/cases"
"$BUILD/cases"

echo "the mutant: a nil store allocates a new attachment instead of resetting the slot"
sed 's/CharonResetColorAttachment(_items\[attachmentIndex\]);/_items[attachmentIndex] = [[MTLRenderPipelineColorAttachmentDescriptor alloc] init];/' \
    "$PORT/$source" > "$BUILD/mutant-src/$source"
if cmp -s "$PORT/$source" "$BUILD/mutant-src/$source"; then
    echo "RUN FAILED: the mutation did not change the source" >&2
    exit 1
fi
xcrun clang $target -fobjc-arc -fvisibility=hidden $quiet $gl $renames -I"$PORT" \
    -c "$BUILD/mutant-src/$source" -o "$BUILD/mutant.o"
xcrun clang $target -fobjc-arc $quiet -I"$here" "$here/cases.m" "$BUILD/mutant.o" \
    -framework Foundation -framework Metal -o "$BUILD/cases-mutant"
if "$BUILD/cases-mutant" > "$BUILD/mutant.out"; then
    echo "RUN FAILED: the mutant passed" >&2
    cat "$BUILD/mutant.out" >&2
    exit 1
fi
echo "mutant red: $(tail -n 1 "$BUILD/mutant.out")"
