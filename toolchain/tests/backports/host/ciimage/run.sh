#!/bin/sh
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
GRAPHICS=${GRAPHICS:-$here/../../../../packages/frameworks/apple-backports/Graphics}
BUILD=${BUILD:-$(runs_fresh revenant-ciimage)}
# CoreImage is on the host itself: the categories are built for macOS with their selectors
# prefixed, so the port and the system answer side by side in one process.
quiet="-Wno-nonnull -Wno-deprecated-declarations -Wno-unguarded-availability-new -Wno-objc-protocol-method-implementation -Wno-nullability-completeness -Wno-availability"
carried="CIImage+Compositing8.m CIImage+ImageBuffer9.m CIImage+SamplingLinear11.m"
rm -rf "$BUILD/plain" "$BUILD/prefixed" "$BUILD/renamed"
mkdir -p "$BUILD/plain" "$BUILD/prefixed" "$BUILD/renamed"
printf '#import <CoreImage/CoreImage.h>\n#import <CoreVideo/CoreVideo.h>\n' > "$BUILD/prefixed/declarations.h"
for file in $carried; do
    xcrun clang -fobjc-arc -fvisibility=hidden $quiet -c "$GRAPHICS/$file" -o "$BUILD/plain/$file.o"
done
for file in $carried; do
    runs_xmake l "$here/../prefix_selectors.lua" "$GRAPHICS/$file" "$BUILD/prefixed/$file" revenantHost_ --declarations="$BUILD/prefixed/declarations.h" -fobjc-arc $quiet -- "$BUILD"/plain/*.o
done
for file in $carried; do
    xcrun clang -fobjc-arc -fvisibility=hidden $quiet -include "$BUILD/prefixed/declarations.h" -c "$BUILD/prefixed/$file" -o "$BUILD/renamed/$file.o"
    perl -0777 -pi -e 's/__objc_catlist\0\0/__port_catlist\0\0/g' "$BUILD/renamed/$file.o"
done
xcrun clang -fobjc-arc $quiet "$here/differential.m" "$here/../foundation2/host-attach.c" "$BUILD"/renamed/*.o -framework CoreImage -framework CoreVideo -framework CoreGraphics -framework Foundation -o "$BUILD/differential"
"$BUILD/differential"
