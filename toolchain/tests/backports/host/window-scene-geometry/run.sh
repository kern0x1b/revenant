#!/bin/sh
# run.sh: a differential of -[UIWindowScene requestGeometryUpdateWithPreferences:errorHandler:] and UISceneWindowingBehaviors, the host's own in a
# bundled Mac Catalyst app with the iPad idiom and a window, and the port's. The host app is app/main.m alone. The port app adds the port's
# UIWindowScene.m, UIScene.m, UIWindowScene+Geometry16.m and UISceneWindowingBehaviors.m, with the classes renamed to RevenantPort*, so the host's
# are still the ones the checks name. Each app writes its checks to a file, and the two files must be the same line for line. The scene's own
# windowingBehaviors is written beside them as host-only evidence (REVENANT_HOST_ONLY_OUT), not compared, since the port answers nil there.
# The checks run in the English locale: the refusal's description is the host's own key lookup, whose German translation is not reached through
# NSBundle on the host (facts/UIKit/UIWindowSceneWindowing16.md). GEOMETRY_PORT_SOURCES replaces the port's files, so a planted wrong port can be
# run as a control: it must fail.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
uikit=$here/../../../../packages/a/apple-backports/UIKit
build=${GEOMETRY_BUILD:-$(runs_fresh revenant-window-scene-geometry)}
sdk=$(xcrun --show-sdk-path)
common="-target arm64-apple-ios15.0-macabi -isysroot $sdk -iframework $sdk/System/iOSSupport/System/Library/Frameworks -fobjc-arc -w -I $uikit"
if [ -n "${GEOMETRY_PORT_SOURCES:-}" ]; then
    port_sources=$GEOMETRY_PORT_SOURCES
else
    port_sources="$uikit/UIWindowScene.m $uikit/UIScene.m $uikit/UIWindowScene+Geometry16.m $uikit/UISceneWindowingBehaviors.m"
fi
plist="$here/app/Info.plist"
for side in host port; do
    bundle="$build/$side/RevenantWindowSceneGeometry.app"
    mkdir -p "$bundle/Contents/MacOS"
    cp "$plist" "$bundle/Contents/Info.plist"
    if [ "$side" = host ]; then
        xcrun clang $common "$here/app/main.m" -framework UIKit -framework Foundation -o "$bundle/Contents/MacOS/RevenantWindowSceneGeometry"
    else
        # shellcheck disable=SC2086
        xcrun clang $common -DREVENANT_PORT_SIDE -DUIWindowScene=RevenantPortUIWindowScene -DUIScene=RevenantPortUIScene \
            -DUIStatusBarManager=RevenantPortUIStatusBarManager -DUISceneWindowingBehaviors=RevenantPortUISceneWindowingBehaviors \
            "$here/app/main.m" $port_sources -framework UIKit -framework Foundation -framework CoreGraphics \
            -o "$bundle/Contents/MacOS/RevenantWindowSceneGeometry"
    fi
    codesign -s - --force --deep "$bundle" > /dev/null 2>&1
    REVENANT_SCENE_OUT="$build/$side.txt" REVENANT_HOST_ONLY_OUT="$build/$side.host-only.txt" timeout 120 "$bundle/Contents/MacOS/RevenantWindowSceneGeometry" > "$build/$side.log" 2>&1 || true
done
if [ ! -s "$build/host.txt" ] || [ ! -s "$build/port.txt" ]; then
    echo "FAIL window-scene-geometry: an app wrote no checks (see $build/*.log)"
    exit 1
fi
cut -f2- "$build/host.txt" > "$build/host.cut"
cut -f2- "$build/port.txt" > "$build/port.cut"
checks=$(wc -l < "$build/host.cut" | tr -d ' ')
if diff "$build/host.cut" "$build/port.cut" > "$build/diff.txt"; then
    echo "ok window-scene-geometry: $checks checks, the port's geometry request and windowing behaviours answer as the host's do"
else
    echo "FAIL window-scene-geometry: the port and the host differ"
    cat "$build/diff.txt"
    exit 1
fi
