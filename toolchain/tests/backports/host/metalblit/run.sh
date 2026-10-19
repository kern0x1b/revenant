#!/bin/sh
# run.sh — differential host test for Metal's blits and mip chain.
#
# What runs here, and what does not, is deliberate and is written down rather than discovered:
#
#   * The port's **buffer** blits run. CharonMetalBuffer.m and the copy and fill methods of
#     CharonMetalBlitEncoder hold no OpenGL ES 2.0, so they compile for Mac Catalyst with the port's
#     classes renamed and run in one process beside macOS Metal's own blit encoder, on the same
#     inputs, and the bytes that come out are compared.
#   * The port's **texture** blits do not run here. CharonMetalTexture is an ES 2.0 texture, and
#     Catalyst has no EAGL context to make one in. What this test does for those is record macOS
#     Metal's own answers into metalblit-expectations.h, which tests/backports/device/metalblit.m
#     holds the port to on the device; the recording is the oracle, and the device test is where the
#     port's answer meets it.
#   * The **mip geometry** is the same: macOS Metal's level extents and bytes-per-row are recorded,
#     and the port's own level arithmetic is checked against the recorded ones here, since
#     levelExtent() is pure.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
METAL=${METAL:-$here/../../../../packages/a/apple-backports/Metal}
BUILD=${BUILD:-$(runs_fresh charon-metalblit)}
sources=${SOURCES:-$(cat "$here/sources.txt")}
sdk=$(xcrun --show-sdk-path)
target="-target arm64-apple-ios15.0-macabi -isysroot $sdk -iframework $sdk/System/iOSSupport/System/Library/Frameworks"
quiet="-Wno-deprecated-declarations -Wno-unguarded-availability-new -Wno-incomplete-implementation -Wno-objc-property-implementation -Wno-nullability-completeness -Wno-objc-designated-initializers -Wno-objc-protocol-method-implementation -Wno-incompatible-property-type -Wmismatched-return-types"

# The oracle first: what macOS Metal itself does, recorded.
DEVICE=${DEVICE:-$here/../../device}
EXPECTATIONS=${EXPECTATIONS:-$DEVICE/metalblit-expectations.h}
if [ "${ORACLE:-1}" = 1 ]; then
    xcrun clang -O -fobjc-arc "$here/oracle.m" -framework Metal -framework Foundation -o "$BUILD/oracle"
    "$BUILD/oracle" "$EXPECTATIONS"
fi

# Then the port's own buffer code beside the system's, with its classes renamed so both live here.
rm -rf "$BUILD/plain" "$BUILD/renamed"
mkdir -p "$BUILD/plain" "$BUILD/renamed"
for source in $sources; do
    xcrun clang $target -fobjc-arc -fvisibility=hidden $quiet -I"$here/gl-stub" -I"$METAL" -c "$METAL/$source" -o "$BUILD/plain/$source.o"
done
renames=""
for name in $(xcrun nm -gU "$BUILD"/plain/*.o | awk 'NF == 3 {print $3}' | grep -E '^_OBJC_CLASS_\$_' | sed -e 's/^_OBJC_CLASS_\$_//' | sort -u); do
    renames="$renames -D$name=CharonHost$name"
done
echo "renamed:$renames"
for source in $sources; do
    xcrun clang $target -fobjc-arc -fvisibility=hidden $quiet $renames -I"$here/gl-stub" -I"$METAL" -c "$METAL/$source" -o "$BUILD/renamed/$source.o"
done
# The port's buffer files name two classes this test cannot have: CharonMetalDevice, which makes an
# EAGL context, and CharonMetalTexture, which is an ES 2.0 texture. host-fixtures.m supplies the two
# names, and every entry point of them raises, so a path under test that ever reached one would abort
# this test rather than be compared against a stand-in that agrees with it.
xcrun clang $target -fobjc-arc $quiet $renames -I"$here" -c "$here/host-fixtures.m" -o "$BUILD/host-fixtures.o"
xcrun clang $target -fobjc-arc $quiet -I"$here" "$here/differential.m" "$BUILD"/renamed/*.o "$BUILD/host-fixtures.o" \
    -framework Metal -framework Foundation -o "$BUILD/differential"
"$BUILD/differential"
