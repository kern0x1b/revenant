#!/bin/sh
# run.sh - asks the host's UIKit and Core Animation, under Mac Catalyst, what UIKit's "magic" sheet shadow is made of, and
# holds the port's shadow (packages/a/apple-backports/UIKit/CharonSheetShadow.c) to it: the vibrant colour matrix 16.0
# gives it (-[_UIShadowView _updateShadowVisualStyling], with the lower intensity the sheet's drop shadow view sets) takes
# its colour from what lies behind the layer, over red, blue, grey and white, and a view's alpha scales it; the port's
# matrix and cap insets are the host shadow view's, its generated image is _UIPopoverShadow, and its pixel leaves what the
# filter leaves. A colour matrix that makes the layer red is the control that the capture shows filters at all. The
# host's image along an edge and its matrix go where device/sheet-cases.m reads them.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
device=${DEVICE:-$here/../../device}
uikit=$here/../../../../packages/a/apple-backports/UIKit
build=${BUILD:-$(runs_fresh charon-sheetshadow)}
sdk=$(xcrun --show-sdk-path)
app="$build/sheetshadow.app"
mkdir -p "$app/Contents/MacOS"
xcrun clang -target arm64-apple-ios16.0-macabi -isysroot "$sdk" -iframework "$sdk/System/iOSSupport/System/Library/Frameworks" -fobjc-arc -w -I"$uikit" \
    "$here/record.m" "$uikit/CharonSheetShadow.c" -framework UIKit -framework Foundation -framework QuartzCore -framework CoreGraphics -o "$app/Contents/MacOS/app"
cp "$here/record.plist" "$app/Contents/Info.plist"
codesign -s - --force "$app" > /dev/null 2>&1
SHADOW_RECORDS="$build/shadow.json" timeout 60 "$app/Contents/MacOS/app"
xmake l "$here/../../common/embed.lua" "$build/shadow.json" "$device/sheet-shadow-expectations.h" foundation2_expectations
sed -i.bak 's/foundation2_expectations/sheet_shadow_expectations/' "$device/sheet-shadow-expectations.h" && rm -f "$device/sheet-shadow-expectations.h.bak"
