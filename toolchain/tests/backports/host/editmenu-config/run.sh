#!/bin/sh
# run.sh: a differential of UIEditMenuConfiguration, the port against the Mac Catalyst host's own class, in one process.
# The port's UIKit/UIEditMenuConfiguration.m and test.m are compiled with -DUIEditMenuConfiguration=RevenantPortUIEditMenuConfiguration,
# so the port's class has its own name and the host's class is still reached by name at run time. test.m prints the same
# checks for both; the run passes when the two sides print the same values, and fails on any difference or on no output.
# EDITMENU_PORT_SOURCE replaces the port's source, so a planted wrong port can be run as a control: it must fail.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
port=${EDITMENU_PORT_SOURCE:-$here/../../../../packages/frameworks/apple-backports/UIKit/UIEditMenuConfiguration.m}
build=${EDITMENU_BUILD:-$(runs_fresh revenant-editmenu-config)}
sdk=$(xcrun --show-sdk-path)
app="$build/editmenu-config"
xcrun clang -target arm64-apple-ios15.0-macabi -isysroot "$sdk" -iframework "$sdk/System/iOSSupport/System/Library/Frameworks" \
    -fobjc-arc -w -DUIEditMenuConfiguration=RevenantPortUIEditMenuConfiguration \
    "$port" "$here/test.m" -framework UIKit -framework Foundation -framework CoreGraphics -o "$app"
codesign -s - --force "$app" > /dev/null 2>&1
"$app" > "$build/editmenu-config.txt"
grep '^host	' "$build/editmenu-config.txt" | cut -f2- > "$build/host.txt"
grep '^port	' "$build/editmenu-config.txt" | cut -f2- > "$build/port.txt"
checks=$(wc -l < "$build/host.txt" | tr -d ' ')
if [ "$checks" -eq 0 ]; then
    echo "FAIL editmenu-config: no checks ran"
    exit 1
fi
if [ "$checks" -ne "$(wc -l < "$build/port.txt" | tr -d ' ')" ]; then
    echo "FAIL editmenu-config: the two sides printed different numbers of checks"
    exit 1
fi
# A known divergence, named: the host's class answers YES to setIdentifier: and setSourcePoint: although the header declares
# both properties readonly. The port answers NO, as the header says. Both facts are asserted, and the rest must match.
# If the host stops answering YES, the divergence is gone and this run fails so the port can be revisited.
divergent='^instances-respond-set(Identifier|SourcePoint)$'
host_yes=$(awk -F '\t' -v p="$divergent" '$1 ~ p && $2 == "yes"' "$build/host.txt" | wc -l | tr -d ' ')
port_no=$(awk -F '\t' -v p="$divergent" '$1 ~ p && $2 == "no"' "$build/port.txt" | wc -l | tr -d ' ')
if [ "$host_yes" -ne 2 ] || [ "$port_no" -ne 2 ]; then
    echo "FAIL editmenu-config: the named setter divergence changed (host yes $host_yes of 2, port no $port_no of 2)"
    exit 1
fi
awk -F '\t' -v p="$divergent" '$1 !~ p' "$build/host.txt" > "$build/host-common.txt"
awk -F '\t' -v p="$divergent" '$1 !~ p' "$build/port.txt" > "$build/port-common.txt"
if diff "$build/host-common.txt" "$build/port-common.txt" > "$build/diff.txt"; then
    echo "ok editmenu-config: $checks checks, $(wc -l < "$build/host-common.txt" | tr -d ' ') compared, the port answers as the host does; the 2 setter answers are the named divergence"
else
    echo "FAIL editmenu-config: the port and the host differ"
    cat "$build/diff.txt"
    exit 1
fi
