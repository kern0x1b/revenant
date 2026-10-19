#!/bin/sh
# run.sh: a differential of UIPasteControlConfiguration, the port against the Mac Catalyst host's own class, in one process.
# The port's UIKit/UIPasteControlConfiguration.m and test.m are compiled with -DUIPasteControlConfiguration=CharonPortUIPasteControlConfiguration,
# so the port's class has its own name and the host's class is still reached by name at run time. test.m prints the same
# checks for both; the run passes when the two sides print the same values, and fails on any difference or on no output.
# PASTE_PORT_SOURCE replaces the port's source, so a planted wrong port can be run as a control: it must fail.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
port=${PASTE_PORT_SOURCE:-$here/../../../../packages/a/apple-backports/UIKit/UIPasteControlConfiguration.m}
build=${PASTE_BUILD:-$(runs_fresh charon-paste-config)}
sdk=$(xcrun --show-sdk-path)
app="$build/paste-config"
xcrun clang -target arm64-apple-ios15.0-macabi -isysroot "$sdk" -iframework "$sdk/System/iOSSupport/System/Library/Frameworks" \
    -fobjc-arc -w -DUIPasteControlConfiguration=CharonPortUIPasteControlConfiguration \
    "$port" "$here/test.m" -framework UIKit -framework Foundation -framework CoreGraphics -o "$app"
codesign -s - --force "$app" > /dev/null 2>&1
"$app" > "$build/paste-config.txt"
awk -F '\t' '$1 == "host" {print $2 "\t" $3}' "$build/paste-config.txt" > "$build/host.txt"
awk -F '\t' '$1 == "port" {print $2 "\t" $3}' "$build/paste-config.txt" > "$build/port.txt"
checks=$(wc -l < "$build/host.txt" | tr -d ' ')
if [ "$checks" -eq 0 ]; then
    echo "FAIL paste-config: no checks ran"
    exit 1
fi
if [ "$checks" -ne "$(wc -l < "$build/port.txt" | tr -d ' ')" ]; then
    echo "FAIL paste-config: the two sides printed different numbers of checks"
    exit 1
fi
if diff "$build/host.txt" "$build/port.txt" > "$build/diff.txt"; then
    echo "ok paste-config: $checks checks, the port answers as the host does"
else
    echo "FAIL paste-config: the port and the host differ"
    cat "$build/diff.txt"
    exit 1
fi
