#!/bin/sh
# run.sh: a differential of UIToolTipInteraction, the port against the Mac Catalyst host's own class, in one process.
# The port's UIKit/UIToolTipInteraction.m and test.m are compiled with -DUIToolTipInteraction=RevenantPortUIToolTipInteraction, so the
# port's class has its own name and the host's class is still reached by name at run time. test.m prints the same checks for both;
# the run passes when the two sides print the same values, and fails on any difference or on no output.
# TOOLTIP_PORT_SOURCE replaces the port's source, so a planted wrong port can be run as a control: it must fail.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
port=${TOOLTIP_PORT_SOURCE:-$here/../../../../packages/frameworks/apple-backports/UIKit/UIToolTipInteraction.m}
build=${TOOLTIP_BUILD:-$(runs_fresh revenant-tooltip-interaction)}
sdk=$(xcrun --show-sdk-path)
app="$build/tooltip-interaction"
xcrun clang -target arm64-apple-ios15.0-macabi -isysroot "$sdk" -iframework "$sdk/System/iOSSupport/System/Library/Frameworks" \
    -fobjc-arc -w -DUIToolTipInteraction=RevenantPortUIToolTipInteraction \
    "$port" "$here/test.m" -framework UIKit -framework Foundation -framework CoreGraphics -o "$app"
codesign -s - --force "$app" > /dev/null 2>&1
"$app" > "$build/tooltip-interaction.txt"
grep '^host	' "$build/tooltip-interaction.txt" | cut -f2- > "$build/host.txt"
grep '^port	' "$build/tooltip-interaction.txt" | cut -f2- > "$build/port.txt"
checks=$(wc -l < "$build/host.txt" | tr -d ' ')
if [ "$checks" -eq 0 ]; then
    echo "FAIL tooltip-interaction: no checks ran"
    exit 1
fi
if [ "$checks" -ne "$(wc -l < "$build/port.txt" | tr -d ' ')" ]; then
    echo "FAIL tooltip-interaction: the two sides printed different numbers of checks"
    exit 1
fi
if diff "$build/host.txt" "$build/port.txt" > "$build/diff.txt"; then
    echo "ok tooltip-interaction: $checks checks, the port answers as the host does"
else
    echo "FAIL tooltip-interaction: the port and the host differ"
    cat "$build/diff.txt"
    exit 1
fi
