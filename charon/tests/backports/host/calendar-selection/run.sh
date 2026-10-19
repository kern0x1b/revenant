#!/bin/sh
# run.sh: a differential of UICalendarSelection and UICalendarSelectionSingleDate, the port against the Mac Catalyst host's own classes, in one
# process. The port's UIKit/UICalendarSelection.m and UIKit/UICalendarSelectionSingleDate.m and test.m are compiled with the classes renamed to
# CharonPort..., so the port's classes have their own names and the host's are still reached by name at run time. test.m prints the shared
# checks for both sides and the port-only tap checks; the run passes when the shared lines agree, every port-only check holds, and the output
# is complete. SELECTION_PORT_SOURCE replaces the port's single-date source, so a planted wrong port can be run as a control: it must fail.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
uikit=$here/../../../../packages/a/apple-backports/UIKit
single=${SELECTION_PORT_SOURCE:-$uikit/UICalendarSelectionSingleDate.m}
build=${SELECTION_BUILD:-$(runs_fresh charon-calendar-selection)}
sdk=$(xcrun --show-sdk-path)
app="$build/calendar-selection"
xcrun clang -target arm64-apple-ios15.0-macabi -isysroot "$sdk" -iframework "$sdk/System/iOSSupport/System/Library/Frameworks" \
    -fobjc-arc -w -I "$uikit" \
    -DUICalendarSelection=CharonPortUICalendarSelection -DUICalendarSelectionSingleDate=CharonPortUICalendarSelectionSingleDate \
    "$uikit/UICalendarSelection.m" "$single" "$here/test.m" -framework UIKit -framework Foundation -framework CoreGraphics -o "$app"
codesign -s - --force "$app" > /dev/null 2>&1
"$app" > "$build/calendar-selection.txt"
grep '^host	' "$build/calendar-selection.txt" | cut -f2- > "$build/host.txt"
grep '^port	' "$build/calendar-selection.txt" | cut -f2- > "$build/port.txt"
grep '^only	' "$build/calendar-selection.txt" | cut -f2- > "$build/only.txt"
checks=$(wc -l < "$build/host.txt" | tr -d ' ')
if [ "$checks" -eq 0 ]; then
    echo "FAIL calendar-selection: no checks ran"
    exit 1
fi
if [ "$checks" -ne "$(wc -l < "$build/port.txt" | tr -d ' ')" ]; then
    echo "FAIL calendar-selection: the two sides printed different numbers of checks"
    exit 1
fi
only=$(wc -l < "$build/only.txt" | tr -d ' ')
if [ "$only" -eq 0 ]; then
    echo "FAIL calendar-selection: the port-only checks did not run"
    exit 1
fi
bad=$(awk -F '\t' '$2 != "yes"' "$build/only.txt")
if [ -n "$bad" ]; then
    echo "FAIL calendar-selection: port-only checks failed"
    echo "$bad"
    exit 1
fi
if diff "$build/host.txt" "$build/port.txt" > "$build/diff.txt"; then
    echo "ok calendar-selection: $checks shared checks, the port answers as the host does; $only port-only tap checks hold"
else
    echo "FAIL calendar-selection: the port and the host differ"
    cat "$build/diff.txt"
    exit 1
fi
