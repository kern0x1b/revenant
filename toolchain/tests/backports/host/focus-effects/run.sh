#!/bin/sh
# run.sh: a differential of UIFocusEffect, UIFocusHaloEffect, UIView's focusEffect and focusGroupPriority, and the focus-group identifiers of
# UIView and UIViewController, the host's own in a bundled Mac Catalyst app with the iPad idiom and a window, and the port's. The host app is
# app/main.m alone. The port app adds the port's UIFocusEffect.m, UIFocusHaloEffect.m, UIView+Focus15.m, UIView+FocusGroup14.m and
# UIViewController+FocusGroup15.m; the two effect classes are renamed to CharonPort*, and the categories have the host's method names, so in the
# port's process they replace the host's and the checks read the port's answers. Each app writes its checks to a file, and the two files must be
# the same line for line. FOCUS_EFFECTS_PORT_SOURCES replaces the port's files, so a planted wrong port can be run as a control: it must fail.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
uikit=$here/../../../../packages/a/apple-backports/UIKit
build=${FOCUS_EFFECTS_BUILD:-$(runs_fresh charon-focus-effects)}
sdk=$(xcrun --show-sdk-path)
common="-target arm64-apple-ios15.0-macabi -isysroot $sdk -iframework $sdk/System/iOSSupport/System/Library/Frameworks -fobjc-arc -w -I $uikit"
if [ -n "${FOCUS_EFFECTS_PORT_SOURCES:-}" ]; then
    port_sources=$FOCUS_EFFECTS_PORT_SOURCES
else
    port_sources="$uikit/UIFocusEffect.m $uikit/UIFocusHaloEffect.m $uikit/UIView+Focus15.m $uikit/UIView+FocusGroup14.m $uikit/UIViewController+FocusGroup15.m"
fi
plist="$here/app/Info.plist"
for side in host port; do
    bundle="$build/$side/CharonFocusEffects.app"
    mkdir -p "$bundle/Contents/MacOS"
    cp "$plist" "$bundle/Contents/Info.plist"
    if [ "$side" = host ]; then
        xcrun clang $common "$here/app/main.m" -framework UIKit -framework Foundation -framework QuartzCore -framework CoreGraphics -o "$bundle/Contents/MacOS/CharonFocusEffects"
    else
        # shellcheck disable=SC2086
        xcrun clang $common -DCHARON_PORT_SIDE -DUIFocusEffect=CharonPortUIFocusEffect -DUIFocusHaloEffect=CharonPortUIFocusHaloEffect \
            "$here/app/main.m" $port_sources -framework UIKit -framework Foundation -framework QuartzCore -framework CoreGraphics \
            -o "$bundle/Contents/MacOS/CharonFocusEffects"
    fi
    codesign -s - --force --deep "$bundle" > /dev/null 2>&1
    CHARON_SCENE_OUT="$build/$side.txt" timeout 120 "$bundle/Contents/MacOS/CharonFocusEffects" > "$build/$side.log" 2>&1 || true
done
if [ ! -s "$build/host.txt" ] || [ ! -s "$build/port.txt" ]; then
    echo "FAIL focus-effects: an app wrote no checks (see $build/*.log)"
    exit 1
fi
cut -f2- "$build/host.txt" > "$build/host.cut"
cut -f2- "$build/port.txt" > "$build/port.cut"
checks=$(wc -l < "$build/host.cut" | tr -d ' ')
if diff "$build/host.cut" "$build/port.cut" > "$build/diff.txt"; then
    echo "ok focus-effects: $checks checks, the port's focus effects and focus groups answer as the host's do"
else
    echo "FAIL focus-effects: the port and the host differ"
    cat "$build/diff.txt"
    exit 1
fi
