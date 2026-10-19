#!/bin/sh
# run.sh: a differential of the layout guides UIKeyboardLayoutGuide, UITrackingLayoutGuide and UIWindow's safeAreaAspectFitLayoutGuide, the host's
# own in a bundled Mac Catalyst app with a window, and the port's. The host app is app/main.m alone. The port app adds the port's
# UITrackingLayoutGuide.m, UIKeyboardLayoutGuide.m and UIWindow+AspectFit16.m. The two classes are renamed to CharonPort*; the view and window
# categories have the host's method names, so in the port's process they replace the host's, and the checks read the port's answers. Each app
# writes its checks to a file, and the two files must be the same line for line. The host's class names are host-only evidence
# (CHARON_HOST_ONLY_OUT). LAYOUT_GUIDE_PORT_SOURCES replaces the port's files, so a planted wrong port can be run as a control: it must fail.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
uikit=$here/../../../../packages/a/apple-backports/UIKit
build=${LAYOUT_GUIDE_BUILD:-$(runs_fresh charon-layout-guides)}
sdk=$(xcrun --show-sdk-path)
common="-target arm64-apple-ios15.0-macabi -isysroot $sdk -iframework $sdk/System/iOSSupport/System/Library/Frameworks -fobjc-arc -w -I $uikit"
if [ -n "${LAYOUT_GUIDE_PORT_SOURCES:-}" ]; then
    port_sources=$LAYOUT_GUIDE_PORT_SOURCES
else
    port_sources="$uikit/UITrackingLayoutGuide.m $uikit/UIKeyboardLayoutGuide.m $uikit/UIWindow+AspectFit16.m"
fi
plist="$here/app/Info.plist"
for side in host port; do
    bundle="$build/$side/CharonLayoutGuides.app"
    mkdir -p "$bundle/Contents/MacOS"
    cp "$plist" "$bundle/Contents/Info.plist"
    if [ "$side" = host ]; then
        xcrun clang $common "$here/app/main.m" -framework UIKit -framework Foundation -framework CoreGraphics -o "$bundle/Contents/MacOS/CharonLayoutGuides"
    else
        # shellcheck disable=SC2086
        xcrun clang $common -DCHARON_PORT_SIDE -DUIKeyboardLayoutGuide=CharonPortUIKeyboardLayoutGuide -DUITrackingLayoutGuide=CharonPortUITrackingLayoutGuide \
            "$here/app/main.m" $port_sources -framework UIKit -framework Foundation -framework CoreGraphics -o "$bundle/Contents/MacOS/CharonLayoutGuides"
    fi
    codesign -s - --force --deep "$bundle" > /dev/null 2>&1
    CHARON_SCENE_OUT="$build/$side.txt" CHARON_HOST_ONLY_OUT="$build/$side.host-only.txt" timeout 120 "$bundle/Contents/MacOS/CharonLayoutGuides" > "$build/$side.log" 2>&1 || true
done
if [ ! -s "$build/host.txt" ] || [ ! -s "$build/port.txt" ]; then
    echo "FAIL layout-guides: an app wrote no checks (see $build/*.log)"
    exit 1
fi
cut -f2- "$build/host.txt" > "$build/host.cut"
cut -f2- "$build/port.txt" > "$build/port.cut"
checks=$(wc -l < "$build/host.cut" | tr -d ' ')
if diff "$build/host.cut" "$build/port.cut" > "$build/diff.txt"; then
    echo "ok layout-guides: $checks checks, the port's keyboard, tracking and aspect-fit guides answer as the host's do"
else
    echo "FAIL layout-guides: the port and the host differ"
    cat "$build/diff.txt"
    exit 1
fi
