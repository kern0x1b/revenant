#!/bin/sh
# AVCaptureResolvedPhotoSettings of the port against the host's own class (oracle.m), and the same oracle against the
# class as main carried it up to 7bb1720d (uniqueID alone, every other property synthesized by the compiler), which it
# must refuse: the negative control that shows the oracle sees a member answered by a synthesized zero.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
root=$(cd "$here/../../../.." && pwd)
AV=${AV:-$root/packages/a/apple-backports/AVFoundation}
BUILD=${BUILD:-$(runs_fresh charon-resolvedphoto)}
sdk=$(xcrun --show-sdk-path)
target="-target arm64-apple-ios15.0-macabi -isysroot $sdk -iframework $sdk/System/iOSSupport/System/Library/Frameworks"
quiet="-Wno-deprecated-declarations -Wno-unguarded-availability-new -Wno-availability -Wno-incomplete-implementation -Wno-objc-property-synthesis"
# The SDK the package builds with, whose header says which members the class has.
SDK16=${SDK16:-$(ls -d "$HOME"/.xmake/packages/i/iphoneos-sdk/16.4/*/Developer.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS16.4.sdk 2>/dev/null | head -1)}
[ -d "$SDK16" ] || { echo "FAIL no iPhoneOS16.4.sdk under ~/.xmake/packages/i/iphoneos-sdk: set SDK16"; exit 1; }
rm -rf "$BUILD/resolvedphoto" && mkdir -p "$BUILD/resolvedphoto" && B=$BUILD/resolvedphoto

# The instance members the header declares on the class, from clang's own reading of it.
printf '#import <AVFoundation/AVFoundation.h>\n' > "$B/header.m"
xcrun clang -fsyntax-only -target arm64-apple-ios16.4 -isysroot "$SDK16" -Xclang -ast-dump -Xclang -ast-dump-filter=AVCaptureResolvedPhotoSettings "$B/header.m" \
    | awk '/ObjCInterfaceDecl .* AVCaptureResolvedPhotoSettings$/ {inside = 1; next} /^Dumping / {inside = 0} inside && /ObjCMethodDecl .* - / {for (i = 1; i <= NF; i++) if ($i == "-") {print $(i + 1); break}}' \
    | sort -u > "$B/declared.txt"
echo "declared: $(wc -l < "$B/declared.txt" | tr -d ' ') members"

oracle() { # oracle NAME SOURCE...: the oracle over a port class built from SOURCE
    name=$1; shift
    xcrun clang -fobjc-arc $target $quiet -DAVCaptureResolvedPhotoSettings=CharonHostAVCaptureResolvedPhotoSettings -I"$AV" -c "$@" -o "$B/$name.o"
    xcrun clang -fobjc-arc $target $quiet "$here/oracle.m" "$B/$name.o" -framework AVFoundation -framework CoreMedia -framework Foundation -o "$B/$name"
    "$B/$name" "$B/declared.txt"
}

echo "== the port"
oracle port "$AV/AVCaptureResolvedPhotoSettings.m"

echo "== the control: the class as 7bb1720d carried it"
git -C "$root" show 7bb1720d:packages/a/apple-backports/AVFoundation/AVCapturePhotoOutput.m \
    | awk '/^@interface AVCaptureResolvedPhotoSettings \(\)/ {on = 1} on {print} on && /^@end/ {ends++; if (ends == 2) exit}' > "$B/control-body.m"
{ printf '#import <AVFoundation/AVFoundation.h>\n'; cat "$B/control-body.m"; } > "$B/control.m"
grep -q '@synthesize uniqueID' "$B/control.m" || { echo "FAIL the control's class was not found in 7bb1720d"; exit 1; }
if oracle control "$B/control.m" > "$B/control.log"; then
    echo "FAIL the oracle passed the control, so it cannot see a synthesized member"
    exit 1
fi
grep -E '^FAIL' "$B/control.log" | head -5
echo "ok   the oracle refuses the control ($(grep -c '^FAIL' "$B/control.log") failures)"
