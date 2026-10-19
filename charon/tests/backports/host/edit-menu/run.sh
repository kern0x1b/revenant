#!/bin/sh
# run.sh: a differential of UIEditMenuInteraction in a bundled Mac Catalyst app with the iPad idiom and a window: the class, its weak delegate,
# its attachment to a view, and the location it answers while no menu is shown. The host app is app/main.m alone. The port app adds the port's
# UIEditMenuInteraction.m and UIView+Interactions.m, with the class renamed to CharonPortUIEditMenuInteraction. Each app writes its checks to a
# file, and the two files must be the same line for line. The host's private interactions, which its own UIKit adds to the view, are written
# beside the checks as host-only evidence and not compared. EDIT_MENU_PORT_SOURCES replaces the port's files, so a planted wrong port can be
# run as a control: it must fail.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
uikit=$here/../../../../packages/a/apple-backports/UIKit
build=${EDIT_MENU_BUILD:-$(runs_fresh charon-edit-menu)}
sdk=$(xcrun --show-sdk-path)
common="-target arm64-apple-ios15.0-macabi -isysroot $sdk -iframework $sdk/System/iOSSupport/System/Library/Frameworks -fobjc-arc -w -I $uikit"
if [ -n "${EDIT_MENU_PORT_SOURCES:-}" ]; then
    port_sources=$EDIT_MENU_PORT_SOURCES
else
    port_sources="$uikit/UIEditMenuConfiguration.m $uikit/UIEditMenuInteraction.m $uikit/UIView+Interactions.m"
fi
renames=$(grep -h '^@implementation ' $port_sources | grep -v '(' | awk '{ print "-D" $2 "=CharonPort" $2 }' | sort -u)
plist="$here/app/Info.plist"
for side in host port; do
    bundle="$build/$side/CharonEditMenu.app"
    mkdir -p "$bundle/Contents/MacOS"
    cp "$plist" "$bundle/Contents/Info.plist"
    if [ "$side" = host ]; then
        xcrun clang $common "$here/app/main.m" -framework UIKit -framework Foundation -framework CoreGraphics -o "$bundle/Contents/MacOS/CharonEditMenu"
    else
        # shellcheck disable=SC2086
        xcrun clang $common $renames -DCHARON_PORT_SIDE "$here/app/main.m" $port_sources \
            -framework UIKit -framework Foundation -framework CoreGraphics -o "$bundle/Contents/MacOS/CharonEditMenu"
    fi
    codesign -s - --force --deep "$bundle" > /dev/null 2>&1
    CHARON_SCENE_OUT="$build/$side.txt" CHARON_HOST_ONLY_OUT="$build/$side.host-only.txt" timeout 120 "$bundle/Contents/MacOS/CharonEditMenu" > "$build/$side.log" 2>&1 || true
done
if [ ! -s "$build/host.txt" ] || [ ! -s "$build/port.txt" ]; then
    echo "FAIL edit-menu: an app wrote no checks (see $build/*.log)"
    exit 1
fi
cut -f2- "$build/host.txt" > "$build/host.cut"
cut -f2- "$build/port.txt" > "$build/port.cut"
checks=$(wc -l < "$build/host.cut" | tr -d ' ')
if diff "$build/host.cut" "$build/port.cut" > "$build/diff.txt"; then
    echo "ok edit-menu: $checks checks, the port's UIEditMenuInteraction answers as the host's does"
else
    echo "FAIL edit-menu: the port and the host differ"
    cat "$build/diff.txt"
    exit 1
fi
