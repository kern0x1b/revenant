#!/bin/sh
# run.sh: a differential of UIMenu and UIMenuElement, the port against the Mac Catalyst host's own classes, in one process.
# The port's UIKit/UIMenu.m and UIKit/UIMenuElement.m and test.m are compiled with the two classes renamed to CharonPort..., so the port's
# classes have their own names and the host's are still reached by name at run time. test.m prints the shared checks for both sides and the
# port-only checks; the run passes when the shared lines agree, every port-only check holds, and the output is complete.
# MENU_PORT_SOURCE replaces the port's UIMenu source, so a planted wrong port can be run as a control: it must fail.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
uikit=$here/../../../../packages/a/apple-backports/UIKit
menu=${MENU_PORT_SOURCE:-$uikit/UIMenu.m}
build=${MENU_BUILD:-$(runs_fresh charon-menu-selection)}
sdk=$(xcrun --show-sdk-path)
app="$build/menu-selection"
xcrun clang -target arm64-apple-ios15.0-macabi -isysroot "$sdk" -iframework "$sdk/System/iOSSupport/System/Library/Frameworks" \
    -fobjc-arc -w -I "$uikit" \
    -DUIMenu=CharonPortUIMenu -DUIMenuElement=CharonPortUIMenuElement \
    "$menu" "$uikit/UIMenuElement.m" "$here/test.m" -framework UIKit -framework Foundation -o "$app"
codesign -s - --force "$app" > /dev/null 2>&1
"$app" > "$build/menu-selection.txt"
grep '^host	' "$build/menu-selection.txt" | cut -f2- > "$build/host.txt"
grep '^port	' "$build/menu-selection.txt" | cut -f2- > "$build/port.txt"
grep '^only	' "$build/menu-selection.txt" | cut -f2- > "$build/only.txt"
checks=$(wc -l < "$build/host.txt" | tr -d ' ')
if [ "$checks" -eq 0 ]; then
    echo "FAIL menu-selection: no checks ran"
    exit 1
fi
if [ "$checks" -ne "$(wc -l < "$build/port.txt" | tr -d ' ')" ]; then
    echo "FAIL menu-selection: the two sides printed different numbers of checks"
    exit 1
fi
only=$(wc -l < "$build/only.txt" | tr -d ' ')
if [ "$only" -eq 0 ]; then
    echo "FAIL menu-selection: the port-only checks did not run"
    exit 1
fi
bad=$(awk -F '\t' '$2 != "yes"' "$build/only.txt")
if [ -n "$bad" ]; then
    echo "FAIL menu-selection: a port-only check did not hold"
    echo "$bad"
    exit 1
fi
if diff "$build/host.txt" "$build/port.txt" > "$build/diff.txt"; then
    echo "ok menu-selection: $checks shared checks and $only port-only checks, the port answers as the host does"
else
    echo "FAIL menu-selection: the port and the host differ"
    cat "$build/diff.txt"
    exit 1
fi
