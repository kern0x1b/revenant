#!/bin/sh
# run.sh: a differential of UIToolTipConfiguration, the port against the Mac Catalyst host's own class, in one process.
# The port's UIKit/UIToolTipConfiguration.m and test.m are compiled with -DUIToolTipConfiguration=RevenantPortUIToolTipConfiguration,
# so the port's class has its own name and the host's class is still reached by name at run time. test.m prints the same
# checks for both; the run passes when the two sides print the same values, and fails on any difference or on no output.
# TOOLTIP_PORT_SOURCE replaces the port's source, so a planted wrong port can be run as a control: it must fail.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
port=${TOOLTIP_PORT_SOURCE:-$here/../../../../packages/frameworks/apple-backports/UIKit/UIToolTipConfiguration.m}
build=${TOOLTIP_BUILD:-$(runs_fresh revenant-tooltip-config)}
sdk=$(xcrun --show-sdk-path)
app="$build/tooltip-config"
xcrun clang -target arm64-apple-ios15.0-macabi -isysroot "$sdk" -iframework "$sdk/System/iOSSupport/System/Library/Frameworks" \
    -fobjc-arc -w -DUIToolTipConfiguration=RevenantPortUIToolTipConfiguration \
    "$port" "$here/test.m" -framework UIKit -framework Foundation -framework CoreGraphics -o "$app"
codesign -s - --force "$app" > /dev/null 2>&1
"$app" > "$build/tooltip-config.txt"
awk -F '\t' '$1 == "host" {print $2 "\t" $3}' "$build/tooltip-config.txt" > "$build/host.txt"
awk -F '\t' '$1 == "port" {print $2 "\t" $3}' "$build/tooltip-config.txt" > "$build/port.txt"
checks=$(wc -l < "$build/host.txt" | tr -d ' ')
if [ "$checks" -eq 0 ]; then
    echo "FAIL tooltip-config: no checks ran"
    exit 1
fi
if [ "$checks" -ne "$(wc -l < "$build/port.txt" | tr -d ' ')" ]; then
    echo "FAIL tooltip-config: the two sides printed different numbers of checks"
    exit 1
fi
# A known divergence, named: the host's class answers a set through its setToolTip: and setSourceRect: although the header declares both
# properties readonly; the set is stored. The port has no such setter, as the header says. Both facts are asserted, and the rest must match.
# If the host stops storing the set, the divergence is gone and this run fails so the port can be revisited.
divergent='^(tooltip|rect)-setter-stores$'
host_set=$(awk -F '\t' -v p="$divergent" '$1 ~ p && $2 == "Changed" || $1 ~ p && $2 == "{{9, 9}, {9, 9}}"' "$build/host.txt" | wc -l | tr -d ' ')
port_none=$(awk -F '\t' -v p="$divergent" '$1 ~ p && $2 == "no setter"' "$build/port.txt" | wc -l | tr -d ' ')
if [ "$host_set" -ne 2 ] || [ "$port_none" -ne 2 ]; then
    echo "FAIL tooltip-config: the named setter divergence changed (host stores $host_set of 2, port has no setter $port_none of 2)"
    exit 1
fi
awk -F '\t' -v p="$divergent" '$1 !~ p' "$build/host.txt" > "$build/host-common.txt"
awk -F '\t' -v p="$divergent" '$1 !~ p' "$build/port.txt" > "$build/port-common.txt"
if diff "$build/host-common.txt" "$build/port-common.txt" > "$build/diff.txt"; then
    echo "ok tooltip-config: $checks checks, $(wc -l < "$build/host-common.txt" | tr -d ' ') compared, the port answers as the host does; the 2 setter answers are the named divergence"
else
    echo "FAIL tooltip-config: the port and the host differ"
    cat "$build/diff.txt"
    exit 1
fi
