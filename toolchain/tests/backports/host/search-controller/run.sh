#!/bin/sh
# run.sh: a differential of UISearchController in a bundled Mac Catalyst app with the iPad idiom: the defaults, the iOS 16 placement (bare, and held
# by a navigation item under each preference), the scope bar activation and its flag, the suggestions' flag, and the suggestions in each placement.
# The host app is app/main.m alone. The port app adds the port's UISearchController files with the class renamed to RevenantPortUISearchController,
# so the host's class is still the one the controller is. Each app writes its checks to a file, and the two files must be the same line for line.
# SEARCH_CONTROLLER_PORT_SOURCES replaces the port's files, so a planted wrong port can be run as a control: it must fail.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
uikit=$here/../../../../packages/a/apple-backports/UIKit
build=${SEARCH_CONTROLLER_BUILD:-$(runs_fresh revenant-search-controller)}
sdk=$(xcrun --show-sdk-path)
common="-target arm64-apple-ios15.0-macabi -isysroot $sdk -iframework $sdk/System/iOSSupport/System/Library/Frameworks -fobjc-arc -w -I $uikit"
if [ -n "${SEARCH_CONTROLLER_PORT_SOURCES:-}" ]; then
    port_sources=$SEARCH_CONTROLLER_PORT_SOURCES
else
    port_sources="$uikit/UISearchController.m $uikit/UISearchController+ScopeBar.m $uikit/UINavigationItem+SearchController.m $uikit/UINavigationItem+SearchBarPlacement16.m"
fi
plist="$here/app/Info.plist"
for side in host port; do
    bundle="$build/$side/RevenantSearchController.app"
    mkdir -p "$bundle/Contents/MacOS"
    cp "$plist" "$bundle/Contents/Info.plist"
    if [ "$side" = host ]; then
        xcrun clang $common "$here/app/main.m" -framework UIKit -framework Foundation -framework CoreGraphics -o "$bundle/Contents/MacOS/RevenantSearchController"
    else
        # shellcheck disable=SC2086
        xcrun clang $common -DREVENANT_PORT_SIDE -DUISearchController=RevenantPortUISearchController "$here/app/main.m" $port_sources \
            -framework UIKit -framework Foundation -framework CoreGraphics -o "$bundle/Contents/MacOS/RevenantSearchController"
    fi
    codesign -s - --force --deep "$bundle" > /dev/null 2>&1
    REVENANT_SCENE_OUT="$build/$side.txt" timeout 120 "$bundle/Contents/MacOS/RevenantSearchController" > "$build/$side.log" 2>&1 || true
done
if [ ! -s "$build/host.txt" ] || [ ! -s "$build/port.txt" ]; then
    echo "FAIL search-controller: an app wrote no checks (see $build/*.log)"
    exit 1
fi
cut -f2- "$build/host.txt" > "$build/host.cut"
cut -f2- "$build/port.txt" > "$build/port.cut"
checks=$(wc -l < "$build/host.cut" | tr -d ' ')
if diff "$build/host.cut" "$build/port.cut" > "$build/diff.txt"; then
    echo "ok search-controller: $checks checks, the port's UISearchController answers as the host's does"
else
    echo "FAIL search-controller: the port and the host differ"
    cat "$build/diff.txt"
    exit 1
fi
