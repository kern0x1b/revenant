#!/bin/sh
# run.sh - differential host test for the five MetalKit classes whose -init the headers mark NS_UNAVAILABLE.
#
# The port's MetalKit objects are built here for Catalyst beside Apple's own MetalKit in one process, the
# way metalblit does it: every class the port defines is renamed CharonHost<Name>, so the two live side by
# side, and init.m asks each side the same question. The answer is NSObject's own -init on both, which is
# what the five rows say once they are implemented: the port carries no -init of its own, and a caller
# reaching -init gets the object NSObject makes, as it does from Apple's class.
#
# A mutation runs last: the case's control class no longer overrides -init, so the measurement has to turn
# red. A harness whose controls cannot fail proves nothing.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
METALKIT=${METALKIT:-$here/../../../../packages/a/apple-backports/MetalKit}
METAL=${METAL:-$here/../../../../packages/a/apple-backports/Metal}
BUILD=${BUILD:-$(runs_fresh charon-metalkit-init)}
sdk=$(xcrun --show-sdk-path)
target="-target arm64-apple-ios15.0-macabi -isysroot $sdk -iframework $sdk/System/iOSSupport/System/Library/Frameworks"
quiet="-Wno-deprecated-declarations -Wno-unguarded-availability-new -Wno-incomplete-implementation -Wno-objc-property-implementation -Wno-nullability-completeness -Wno-objc-designated-initializers -Wno-objc-protocol-method-implementation -Wno-incompatible-property-type -Wmismatched-return-types"
sources="MTKMesh9.m MTKMeshBuffer9.m MTKTextureLoader9.m MDLMeshBufferMap9.m MDLVertexDescriptor9.m"

rm -rf "$BUILD/plain" "$BUILD/renamed"
mkdir -p "$BUILD/plain" "$BUILD/renamed"
for source in $sources; do
    xcrun clang $target -fobjc-arc -fvisibility=hidden $quiet -I"$METALKIT" -I"$METAL" -c "$METALKIT/$source" -o "$BUILD/plain/$source.o"
done
# Every class the port defines gets the CharonHost prefix, in the headers it includes as well as its own code.
renames=""
for name in $(xcrun nm -gU "$BUILD"/plain/*.o | awk 'NF == 3 {print $3}' | grep -E '^_OBJC_CLASS_\$_' | sed -e 's/^_OBJC_CLASS_\$_//' | sort -u); do
    renames="$renames -D$name=CharonHost$name"
done
echo "renamed:$renames"
for source in $sources; do
    xcrun clang $target -fobjc-arc -fvisibility=hidden $quiet $renames -I"$METALKIT" -I"$METAL" -c "$METALKIT/$source" -o "$BUILD/renamed/$source.o"
done

# The case, linked against the port's renamed objects and against Apple's frameworks it asks.
xcrun clang $target -fobjc-arc $quiet -I"$here" "$here/init.m" "$BUILD"/renamed/*.o \
    -framework MetalKit -framework Metal -framework ModelIO -framework Foundation -framework UIKit -framework CoreGraphics -o "$BUILD/init"
"$BUILD/init"

# THE MUTATION: a control that no longer overrides -init must make the case fail. Done in a copy of the
# case, so the case itself is never edited.
echo "the mutation: the control class no longer overrides -init"
sed '/^- (instancetype)init { return \[super init\]; }$/d' "$here/init.m" > "$BUILD/mutant.m"
xcrun clang $target -fobjc-arc $quiet -I"$here" "$BUILD/mutant.m" "$BUILD"/renamed/*.o \
    -framework MetalKit -framework Metal -framework ModelIO -framework Foundation -framework UIKit -framework CoreGraphics -o "$BUILD/mutant"
if "$BUILD/mutant" > "$BUILD/mutant.out" 2>&1; then
    echo "FAIL: the mutant passed, so the measurement cannot see an override" >&2
    exit 1
fi
grep -q "FAIL control: a class that overrides" "$BUILD/mutant.out" || {
    echo "FAIL: the mutant failed, but not on the control that should turn red" >&2
    exit 1
}
echo "ok   the mutant turns the control red"
