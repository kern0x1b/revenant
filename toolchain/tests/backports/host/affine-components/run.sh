#!/bin/sh
# run.sh - the port's CGAffineTransformDecompose and CGAffineTransformMakeWithComponents, held to the host's own
# CoreGraphics (differential.m). The port's source is compiled for this host with both functions renamed, so the
# host's and the port's stand side by side in one binary. The port is linked twice: through the system's sine-cosine
# pair, and through apple-compat's __sincos_stret (packages/runtimes/apple-compat/src), as a build for an older release links it.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
GRAPHICS=${GRAPHICS:-$here/../../../../packages/frameworks/apple-backports/Graphics}
COMPAT=${COMPAT:-$here/../../../../packages/runtimes/apple-compat/src}
BUILD=${BUILD:-$(runs_fresh revenant-affine-components)}
mkdir -p "$BUILD"
renames="-DCGAffineTransformDecompose=RevenantHostDecompose -DCGAffineTransformMakeWithComponents=RevenantHostMakeWithComponents"
xcrun clang -fobjc-arc -mmacosx-version-min=10.12 -w $renames -I"$GRAPHICS" -c "$GRAPHICS/CGAffineTransform16.m" \
    -o "$BUILD/port.o"
# The shim as apple-compat builds it: -Os, -fno-builtin, hidden. It must call the library's sin and cos, not __sincos_stret.
xcrun clang -mmacosx-version-min=10.12 -Os -fno-builtin -fvisibility=hidden -c "$COMPAT/__sincos_stret.c" -o "$BUILD/shim.o"
if nm -u "$BUILD/shim.o" | grep -q sincos; then
    echo "shim.o calls a sincos symbol of its own: the shim would call itself" >&2
    exit 1
fi
xcrun clang -fobjc-arc -mmacosx-version-min=10.12 -w "$here/differential.m" "$BUILD/port.o" \
    -framework CoreGraphics -framework Foundation -o "$BUILD/differential"
xcrun clang -fobjc-arc -mmacosx-version-min=10.12 -w "$here/differential.m" "$BUILD/port.o" "$BUILD/shim.o" \
    -framework CoreGraphics -framework Foundation -o "$BUILD/differential-shim"
echo "system pair:"
"$BUILD/differential"
echo "shim:"
"$BUILD/differential-shim"
