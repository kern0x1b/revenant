#!/bin/sh
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
GRAPHICS=${GRAPHICS:-$here/../../../../packages/a/apple-backports/.gen/CoreImage}
BUILD=${BUILD:-$(runs_fresh revenant-ciimagefilter)}
# CoreImage is on the host itself: the port's categories are built for macOS with their selectors
# prefixed, so the host's +[CIFilter gaussianBlurFilter] and the port's +revenantHost_gaussianBlurFilter
# answer side by side in one process and the differential compares them.
quiet="-Wno-nonnull -Wno-deprecated-declarations -Wno-unguarded-availability-new -Wno-objc-protocol-method-implementation -Wno-nullability-completeness -Wno-availability"
carried="CIFilterBuiltins7.m CIFilterBuiltins80.m CIFilterBuiltins841.m CIFilterBuiltins11.m CIFilterBuiltins16.m CIFilterBuiltins18.m CIFilterBuiltins26.m"
rm -rf "$BUILD/plain" "$BUILD/prefixed" "$BUILD/renamed"
mkdir -p "$BUILD/plain" "$BUILD/prefixed" "$BUILD/renamed"
printf '#import <CoreImage/CoreImage.h>\n' > "$BUILD/prefixed/declarations.h"
for file in $carried; do
    xcrun clang -fobjc-arc -fvisibility=hidden $quiet -c "$GRAPHICS/$file" -o "$BUILD/plain/$file.o"
done
for file in $carried; do
    runs_xmake l "$here/../prefix_selectors.lua" "$GRAPHICS/$file" "$BUILD/prefixed/$file" charonHost_ --declarations="$BUILD/prefixed/declarations.h" -fobjc-arc $quiet -- "$BUILD"/plain/*.o
done
for file in $carried; do
    # No rename of __objc_catlist here: these categories have names of their own, so nothing clashes,
    # and the section is what makes the runtime register the methods the differential enumerates.
    xcrun clang -fobjc-arc -fvisibility=hidden $quiet -include "$BUILD/prefixed/declarations.h" -c "$BUILD/prefixed/$file" -o "$BUILD/renamed/$file.o"
done
xcrun clang -fobjc-arc $quiet "$here/differential.m" "$BUILD"/renamed/*.o -framework CoreImage -framework CoreGraphics -framework Foundation -o "$BUILD/differential"
"$BUILD/differential"
