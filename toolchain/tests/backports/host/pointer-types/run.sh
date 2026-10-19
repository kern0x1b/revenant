#!/bin/sh
# run.sh: a differential of UIPointerInteraction, UIButton's pointer members and the pointer lock state (UIPointerLockState, UIScene's
# pointerLockState, UIViewController's prefersPointerLocked), the host's own in a bundled Mac Catalyst app with the iPad idiom and a window, and
# the port's. The host app is app/main.m alone. The port app adds the port's UIPointerInteraction.m, UIButton+Pointer.m and UIPointerLockState.m,
# with the two classes renamed to CharonPort*; the categories have the host's method names, so in the port's process they replace the host's.
# Each app writes its checks to a file, and the two files must be the same line for line. POINTER_TYPES_PORT_SOURCES replaces the port's files,
# so a planted wrong port can be run as a control: it must fail.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
uikit=$here/../../../../packages/a/apple-backports/UIKit
build=${POINTER_TYPES_BUILD:-$(runs_fresh charon-pointer-types)}
sdk=$(xcrun --show-sdk-path)
common="-target arm64-apple-ios15.0-macabi -isysroot $sdk -iframework $sdk/System/iOSSupport/System/Library/Frameworks -fobjc-arc -w -I $uikit"
if [ -n "${POINTER_TYPES_PORT_SOURCES:-}" ]; then
    port_sources=$POINTER_TYPES_PORT_SOURCES
else
    port_sources="$uikit/UIPointerInteraction.m $uikit/UIButton+Pointer.m $uikit/UIPointerLockState.m"
fi
plist="$here/app/Info.plist"
for side in host port; do
    bundle="$build/$side/CharonPointerTypes.app"
    mkdir -p "$bundle/Contents/MacOS"
    cp "$plist" "$bundle/Contents/Info.plist"
    if [ "$side" = host ]; then
        xcrun clang $common "$here/app/main.m" -framework UIKit -framework Foundation -framework CoreGraphics -o "$bundle/Contents/MacOS/CharonPointerTypes"
    else
        # shellcheck disable=SC2086
        xcrun clang $common -DCHARON_PORT_SIDE -DUIPointerInteraction=CharonPortUIPointerInteraction -DUIPointerLockState=CharonPortUIPointerLockState \
            "$here/app/main.m" $port_sources -framework UIKit -framework Foundation -framework CoreGraphics -o "$bundle/Contents/MacOS/CharonPointerTypes"
    fi
    codesign -s - --force --deep "$bundle" > /dev/null 2>&1
    CHARON_SCENE_OUT="$build/$side.txt" timeout 120 "$bundle/Contents/MacOS/CharonPointerTypes" > "$build/$side.log" 2>&1 || true
done
if [ ! -s "$build/host.txt" ] || [ ! -s "$build/port.txt" ]; then
    echo "FAIL pointer-types: an app wrote no checks (see $build/*.log)"
    exit 1
fi
cut -f2- "$build/host.txt" > "$build/host.cut"
cut -f2- "$build/port.txt" > "$build/port.cut"
checks=$(wc -l < "$build/host.cut" | tr -d ' ')
if diff "$build/host.cut" "$build/port.cut" > "$build/diff.txt"; then
    echo "ok pointer-types: $checks checks, the port's pointer interaction, button pointer members and lock state answer as the host's do"
else
    echo "FAIL pointer-types: the port and the host differ"
    cat "$build/diff.txt"
    exit 1
fi
