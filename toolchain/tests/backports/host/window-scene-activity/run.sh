#!/bin/sh
# run.sh: a differential of UIWindowScene.activityItemsConfigurationSource, the host's own window scene and the port's UIWindowScene, each in a
# bundled Mac Catalyst app. The host app is app/main.m alone. The port app adds UIKit/UIWindowScene.m and UIKit/UIScene.m with the classes
# renamed to RevenantPort*, so the host's classes are still the ones the scene is. Each app writes its checks to a file, and the two files must
# be the same line for line. WINDOW_SCENE_PORT_SOURCES replaces the port's files, so a planted wrong port can be run as a control: it must fail.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
uikit=$here/../../../../packages/a/apple-backports/UIKit
build=${WINDOW_SCENE_BUILD:-$(runs_fresh revenant-window-scene-activity)}
sdk=$(xcrun --show-sdk-path)
common="-target arm64-apple-ios15.0-macabi -isysroot $sdk -iframework $sdk/System/iOSSupport/System/Library/Frameworks -fobjc-arc -w -I $uikit"
if [ -n "${WINDOW_SCENE_PORT_SOURCES:-}" ]; then
    port_sources=$WINDOW_SCENE_PORT_SOURCES
else
    port_sources="$uikit/UIWindowScene.m $uikit/UIScene.m"
fi
plist="$here/app/Info.plist"
for side in host port; do
    bundle="$build/$side/RevenantWindowSceneActivity.app"
    mkdir -p "$bundle/Contents/MacOS"
    cp "$plist" "$bundle/Contents/Info.plist"
    if [ "$side" = host ]; then
        xcrun clang $common "$here/app/main.m" -framework UIKit -framework Foundation -o "$bundle/Contents/MacOS/RevenantWindowSceneActivity"
    else
        # shellcheck disable=SC2086
        xcrun clang $common -DREVENANT_PORT_SIDE -DUIWindowScene=RevenantPortUIWindowScene -DUIScene=RevenantPortUIScene \
            -DUIStatusBarManager=RevenantPortUIStatusBarManager "$here/app/main.m" $port_sources \
            -framework UIKit -framework Foundation -framework CoreGraphics -o "$bundle/Contents/MacOS/RevenantWindowSceneActivity"
    fi
    codesign -s - --force --deep "$bundle" > /dev/null 2>&1
    REVENANT_SCENE_OUT="$build/$side.txt" timeout 120 "$bundle/Contents/MacOS/RevenantWindowSceneActivity" > "$build/$side.log" 2>&1 || true
done
if [ ! -s "$build/host.txt" ] || [ ! -s "$build/port.txt" ]; then
    echo "FAIL window-scene-activity: an app wrote no checks (see $build/*.log)"
    exit 1
fi
cut -f2- "$build/host.txt" > "$build/host.cut"
cut -f2- "$build/port.txt" > "$build/port.cut"
checks=$(wc -l < "$build/host.cut" | tr -d ' ')
if diff "$build/host.cut" "$build/port.cut" > "$build/diff.txt"; then
    echo "ok window-scene-activity: $checks checks, the port's UIWindowScene answers as the host's does"
else
    echo "FAIL window-scene-activity: the port and the host differ"
    cat "$build/diff.txt"
    exit 1
fi
