#!/bin/sh
# run.sh: a differential of UIControl's tool tip, the host's own control and the port's category on it, each in its own process.
# The host's process is test.m alone. The port's process adds UIKit/UIControl+ToolTip15.m, the port's UIToolTipInteraction (renamed, so it
# does not clash with the host's class in one process), and the port's interaction attach (UIView+Interactions.m), which the device's
# UIKit lacks as well. The two outputs must be the same line for line.
# CONTROL_TOOLTIP_PORT_SOURCE replaces the port's category, so a planted wrong port can be run as a control: it must fail.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
uikit=$here/../../../../packages/a/apple-backports/UIKit
category=${CONTROL_TOOLTIP_PORT_SOURCE:-$uikit/UIControl+ToolTip15.m}
build=${CONTROL_TOOLTIP_BUILD:-$(runs_fresh revenant-control-tooltip)}
sdk=$(xcrun --show-sdk-path)
common="-target arm64-apple-ios15.0-macabi -isysroot $sdk -iframework $sdk/System/iOSSupport/System/Library/Frameworks -fobjc-arc -w -I $uikit"
host_app="$build/control-tooltip-host"
port_app="$build/control-tooltip-port"
xcrun clang $common "$here/test.m" -framework UIKit -framework Foundation -framework CoreGraphics -o "$host_app"
xcrun clang $common -DUIToolTipInteraction=RevenantPortUIToolTipInteraction \
    "$category" "$uikit/UIToolTipInteraction.m" "$uikit/UIView+Interactions.m" "$here/test.m" \
    -framework UIKit -framework Foundation -framework CoreGraphics -o "$port_app"
codesign -s - --force "$host_app" > /dev/null 2>&1
codesign -s - --force "$port_app" > /dev/null 2>&1
"$host_app" > "$build/host.txt"
"$port_app" > "$build/port.txt"
checks=$(wc -l < "$build/host.txt" | tr -d ' ')
if [ "$checks" -eq 0 ]; then
    echo "FAIL control-tooltip: no checks ran"
    exit 1
fi
if diff "$build/host.txt" "$build/port.txt" > "$build/diff.txt"; then
    echo "ok control-tooltip: $checks checks, the port's category answers as the host's control does"
else
    echo "FAIL control-tooltip: the port and the host differ"
    cat "$build/diff.txt"
    exit 1
fi
