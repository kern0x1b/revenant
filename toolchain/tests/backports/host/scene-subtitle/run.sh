#!/bin/sh
# run.sh: a differential of UIScene.subtitle, the host's own scene and the port's UIScene, each in a bundled Mac Catalyst app.
# The host app is app/main.m alone. The port app adds UIKit/UIScene.m with the class renamed to RevenantPortUIScene, so the host's class
# is still the one the scene is. Each app writes its checks to a file, and the two files must be the same line for line.
# SCENE_PORT_SOURCE replaces the port's UIScene source, so a planted wrong port can be run as a control: it must fail.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
uikit=$here/../../../../packages/frameworks/apple-backports/UIKit
scene=${SCENE_PORT_SOURCE:-$uikit/UIScene.m}
build=${SCENE_BUILD:-$(runs_fresh revenant-scene-subtitle)}
sdk=$(xcrun --show-sdk-path)
common="-target arm64-apple-ios15.0-macabi -isysroot $sdk -iframework $sdk/System/iOSSupport/System/Library/Frameworks -fobjc-arc -w -I $uikit"
plist="$here/app/Info.plist"
for side in host port; do
    bundle="$build/$side/RevenantSceneSubtitle.app"
    mkdir -p "$bundle/Contents/MacOS"
    cp "$plist" "$bundle/Contents/Info.plist"
    if [ "$side" = host ]; then
        xcrun clang $common "$here/app/main.m" -framework UIKit -framework Foundation -o "$bundle/Contents/MacOS/RevenantSceneSubtitle"
    else
        xcrun clang $common -DREVENANT_PORT_SIDE -DUIScene=RevenantPortUIScene "$here/app/main.m" "$scene" \
            -framework UIKit -framework Foundation -o "$bundle/Contents/MacOS/RevenantSceneSubtitle"
    fi
    codesign -s - --force --deep "$bundle" > /dev/null 2>&1
    REVENANT_SCENE_OUT="$build/$side.txt" timeout 120 "$bundle/Contents/MacOS/RevenantSceneSubtitle" > "$build/$side.log" 2>&1 || true
done
checks=$(grep -c '^host	' "$build/host.txt" | tr -d ' ' || true)
if [ ! -s "$build/host.txt" ] || [ ! -s "$build/port.txt" ]; then
    echo "FAIL scene-subtitle: an app wrote no checks (see $build/*.log)"
    exit 1
fi
cut -f2- "$build/host.txt" > "$build/host.cut"
cut -f2- "$build/port.txt" > "$build/port.cut"
checks=$(wc -l < "$build/host.cut" | tr -d ' ')
if diff "$build/host.cut" "$build/port.cut" > "$build/diff.txt"; then
    echo "ok scene-subtitle: $checks checks, the port's UIScene answers as the host's scene does"
else
    echo "FAIL scene-subtitle: the port and the host differ"
    cat "$build/diff.txt"
    exit 1
fi
