#!/bin/sh
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
AV=${AV:-$here/../../../../packages/frameworks/apple-backports/AVFoundation}
BUILD=${BUILD:-$(runs_fresh revenant-avcapture)}
sdk=$(xcrun --show-sdk-path)
target="-target arm64-apple-ios15.0-macabi -isysroot $sdk -iframework $sdk/System/iOSSupport/System/Library/Frameworks"
quiet="-Wno-deprecated-declarations -Wno-unguarded-availability-new -Wno-incomplete-implementation -Wno-objc-protocol-method-implementation -Wno-nullability-completeness -Wno-availability"
carried="AVCaptureDevice+DeviceType.m RevenantAVCapture.m AVCaptureDeviceDiscoverySession.m"
constants="AVCaptureDeviceType.m AVCaptureDeviceType102.m"
rm -rf "$BUILD/plain" "$BUILD/prefixed" "$BUILD/renamed"
mkdir -p "$BUILD/plain" "$BUILD/prefixed" "$BUILD/renamed"
renames="-DAVCaptureDeviceDiscoverySession=RevenantHostAVCaptureDeviceDiscoverySession"
for file in $constants; do
    xcrun clang -fobjc-arc $target -fvisibility=hidden $quiet -c "$AV/$file" -o "$BUILD/plain/$file.o"
    for name in $(xcrun nm -gU "$BUILD/plain/$file.o" | awk 'NF == 3 {print $3}' | sed 's/^_//'); do
        renames="$renames -D$name=RevenantHost$name"
    done
done
for file in $constants; do
    xcrun clang -fobjc-arc $target -fvisibility=hidden $quiet $renames -c "$AV/$file" -o "$BUILD/renamed/$file.o"
done
printf '#import <AVFoundation/AVFoundation.h>\n' > "$BUILD/prefixed/declarations.h"
for file in $carried; do
    xcrun clang -fobjc-arc $target -fvisibility=hidden $quiet $renames -I"$AV" -c "$AV/$file" -o "$BUILD/plain/$file.o"
done
for file in $carried; do
    runs_xmake l "$here/../prefix_selectors.lua" "$AV/$file" "$BUILD/prefixed/$file" revenantHost_ --declarations="$BUILD/prefixed/declarations.h" -fobjc-arc $target $quiet $renames -I"$AV" -- "$BUILD"/plain/*.o
done
for file in $carried; do
    xcrun clang -fobjc-arc $target -fvisibility=hidden $quiet $renames -I"$AV" -include "$BUILD/prefixed/declarations.h" -c "$BUILD/prefixed/$file" -o "$BUILD/renamed/$file.o"
    perl -0777 -pi -e 's/__objc_catlist\0\0/__port_catlist\0\0/g' "$BUILD/renamed/$file.o"
done
xcrun clang -fobjc-arc $target $quiet $renames "$here/differential.m" "$here/../foundation2/host-attach.c" "$BUILD"/renamed/*.o -framework AVFoundation -framework Foundation -o "$BUILD/differential"
"$BUILD/differential"
