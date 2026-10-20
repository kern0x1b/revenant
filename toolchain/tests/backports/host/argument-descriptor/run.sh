#!/bin/sh
# run.sh - MTLArgumentDescriptor (iOS 11.0) against Apple's own object, member by member.
#
# The port's class is built for Catalyst beside Apple's Metal in one process, with every class its one source file
# defines renamed RevenantHost<Name>. The class has no other port source to build with it.
#
# A MUTANT runs last: the fresh texture type is 1D, not Apple's 2D (measured), so the fresh comparison must turn red.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
METAL=${METAL:-$here/../../../../packages/frameworks/apple-backports/Metal}
BUILD=${BUILD:-$(runs_fresh revenant-argument-descriptor)}
sdk=$(xcrun --show-sdk-path)
target="-target arm64-apple-ios16.0-macabi -isysroot $sdk -iframework $sdk/System/iOSSupport/System/Library/Frameworks"
quiet="-Wno-deprecated-declarations -Wno-unguarded-availability-new -Wno-objc-designated-initializers -Wno-incomplete-implementation -Wno-objc-protocol-method-implementation"
gl="-I$here/../metalblit/gl-stub"
source=MTLArgumentDescriptor11.m

rm -rf "$BUILD/plain" "$BUILD/renamed" "$BUILD/mutant-src"
mkdir -p "$BUILD/plain" "$BUILD/renamed" "$BUILD/mutant-src"
xcrun clang $target -fobjc-arc -fvisibility=hidden $quiet $gl -I"$METAL" -c "$METAL/$source" -o "$BUILD/plain/$source.o"
renames=""
for name in $(xcrun nm -gU "$BUILD/plain/$source.o" | awk 'NF == 3 {print $3}' | grep -E '^_OBJC_CLASS_\$_' | sed -e 's/^_OBJC_CLASS_\$_//' | sort -u); do
    renames="$renames -D$name=RevenantHost$name"
done
echo "renamed:$renames"
xcrun clang $target -fobjc-arc -fvisibility=hidden $quiet $gl $renames -I"$METAL" -c "$METAL/$source" -o "$BUILD/renamed/$source.o"

xcrun clang $target -fobjc-arc $quiet -I"$here" "$here/descriptor.m" "$BUILD/renamed/$source.o" \
    -framework Metal -framework Foundation -o "$BUILD/descriptor"
"$BUILD/descriptor"

echo "the mutant: a fresh descriptor's texture type is 1D, not Apple's 2D"
sed 's/^        _textureType = MTLTextureType2D;$/        _textureType = MTLTextureType1D;/' "$METAL/$source" > "$BUILD/mutant-src/$source"
if cmp -s "$METAL/$source" "$BUILD/mutant-src/$source"; then
    echo "RUN FAILED: the mutation did not change the source" >&2
    exit 1
fi
xcrun clang $target -fobjc-arc -fvisibility=hidden $quiet $gl $renames -I"$METAL" -c "$BUILD/mutant-src/$source" -o "$BUILD/mutant-descriptor.o"
xcrun clang $target -fobjc-arc $quiet -I"$here" "$here/descriptor.m" "$BUILD/mutant-descriptor.o" \
    -framework Metal -framework Foundation -o "$BUILD/mutant"
set +e
"$BUILD/mutant" > "$BUILD/mutant.out" 2>&1
set -e
if grep -q "FAIL fresh: the port" "$BUILD/mutant.out"; then
    echo "ok   the mutant turns the fresh comparison red"
else
    echo "FAIL: the mutant did not turn the fresh comparison red" >&2
    cat "$BUILD/mutant.out" >&2
    exit 1
fi
