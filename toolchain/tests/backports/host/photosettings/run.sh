#!/bin/sh
# AVCapturePhotoSettings and AVCapturePhotoOutput of the port against the host's own classes (oracle.m), and the same
# oracle against the classes as main carried them up to 7bb1720d (a handful of members, every other property synthesized
# by the compiler), which it must refuse: the negative control that shows the oracle sees a member the port leaves out.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
root=$(cd "$here/../../../.." && pwd)
AV=${AV:-$root/packages/frameworks/apple-backports/AVFoundation}
BUILD=${BUILD:-$(runs_fresh revenant-photosettings)}
sdk=$(xcrun --show-sdk-path)
target="-target arm64-apple-ios15.0-macabi -isysroot $sdk -iframework $sdk/System/iOSSupport/System/Library/Frameworks"
quiet="-Wno-deprecated-declarations -Wno-unguarded-availability-new -Wno-availability -Wno-incomplete-implementation -Wno-objc-property-synthesis"
# The port's classes under names of their own, so that the host's classes stay the host's: the header's class names by
# macro, and the output's runtime name (it is a subclass of the still image output named AVCapturePhotoOutput at run time).
rename="-DAVCapturePhotoSettings=RevenantHostAVCapturePhotoSettings -DAVCapturePhotoOutput=RevenantHostAVCapturePhotoOutput
        -DAVCaptureResolvedPhotoSettings=RevenantHostAVCaptureResolvedPhotoSettings"
# The SDK the package builds with, whose header says which members the classes have.
SDK16=${SDK16:-$(ls -d "$HOME"/.xmake/packages/i/iphoneos-sdk/16.4/*/Developer.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS16.4.sdk 2>/dev/null | head -1)}
[ -d "$SDK16" ] || { echo "FAIL no iPhoneOS16.4.sdk under ~/.xmake/packages/i/iphoneos-sdk: set SDK16"; exit 1; }
rm -rf "$BUILD/photosettings" && mkdir -p "$BUILD/photosettings" && B=$BUILD/photosettings

# The members the header declares on both classes and on the output's category, from clang's own reading of it, as
# "<class> -|+ <selector>" lines.
printf '#import <AVFoundation/AVFoundation.h>\n' > "$B/header.m"
xcrun clang -fsyntax-only -target arm64-apple-ios16.4 -isysroot "$SDK16" -Xclang -ast-dump -Xclang -ast-dump-filter=AVCapturePhoto "$B/header.m" \
    | awk '/^[A-Za-z]/ {owner = ""}
           /^ObjCInterfaceDecl .* AVCapturePhoto(Settings|Output)$/ {owner = $NF}
           /^ObjCCategoryDecl .* AVCapturePhotoOutputDepthDataDeliverySupport$/ {owner = "AVCapturePhotoOutput"}
           owner != "" && /^[|`]-ObjCMethodDecl .* [-+] / {for (i = 1; i <= NF; i++) if ($i == "-" || $i == "+") {print owner, $i, $(i + 1); break}}' \
    | sort -u > "$B/declared.txt"
echo "declared: $(grep -c '^AVCapturePhotoSettings ' "$B/declared.txt") settings members, $(grep -c '^AVCapturePhotoOutput ' "$B/declared.txt") output members"

oracle() { # oracle NAME SOURCE...: the oracle over port classes built from SOURCE
    name=$1; shift
    objects=
    for source in "$@"; do
        object=$B/$name-$(basename "$source" .m).o
        xcrun clang -fobjc-arc $target $quiet $rename -D'objc_runtime_name(x)=objc_runtime_name("RevenantHostAVCapturePhotoOutput")' \
            -I"$AV" -c "$source" -o "$object"
        objects="$objects $object"
    done
    xcrun clang -fobjc-arc $target $quiet "$here/oracle.m" $objects -framework AVFoundation -framework CoreMedia -framework CoreVideo \
        -framework Accelerate -framework CoreImage -framework ImageIO -framework CoreGraphics -framework UIKit -framework Foundation -o "$B/$name"
    "$B/$name" "$B/declared.txt" "$here/divergences.tsv"
}

echo "== the port"
oracle port "$AV/AVCapturePhotoSettings.m" "$AV/AVCapturePhotoOutput.m" "$AV/AVCaptureResolvedPhotoSettings.m"

echo "== the capture's wait for the camera's flash"
xcrun clang -fobjc-arc $target $quiet -I"$AV" "$here/flashwait.m" "$B"/port-*.o -framework AVFoundation -framework CoreMedia -framework CoreVideo \
    -framework Accelerate -framework CoreImage -framework ImageIO -framework CoreGraphics -framework UIKit -framework Foundation -o "$B/flashwait"
"$B/flashwait"

echo "== the control: the classes as 7bb1720d carried them"
git -C "$root" show 7bb1720d:packages/a/apple-backports/AVFoundation/AVCapturePhotoOutput.m > "$B/control.m"
grep -q '^@implementation AVCapturePhotoSettings' "$B/control.m" || { echo "FAIL the control's classes were not found in 7bb1720d"; exit 1; }
if oracle control "$B/control.m" > "$B/control.log" 2>&1; then
    echo "FAIL the oracle passed the control, so it cannot see a member the port leaves out"
    exit 1
fi
grep -E '^FAIL' "$B/control.log" | head -5
echo "ok   the oracle refuses the control ($(grep -c '^FAIL' "$B/control.log") failures)"
