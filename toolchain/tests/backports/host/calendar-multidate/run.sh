#!/bin/sh
# run.sh: a differential of UICalendarSelection and UICalendarSelectionMultiDate, the port against the Mac Catalyst host's own classes, in one
# process. The port's UIKit/UICalendarSelection.m and UIKit/UICalendarSelectionMultiDate.m and test.m are compiled with the classes renamed to
# RevenantPort..., so the port's classes have their own names and the host's are still reached by name at run time. test.m prints the shared
# checks for both sides and the port-only tap checks; the run passes when the shared lines agree, every port-only check holds, and the output
# is complete. MULTIDATE_PORT_SOURCE replaces the port's multi-date source, so a planted wrong port can be run as a control: it must fail.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
uikit=$here/../../../../packages/frameworks/apple-backports/UIKit
multi=${MULTIDATE_PORT_SOURCE:-$uikit/UICalendarSelectionMultiDate.m}
build=${MULTIDATE_BUILD:-$(runs_fresh revenant-calendar-multidate)}
sdk=$(xcrun --show-sdk-path)
app="$build/calendar-multidate"
xcrun clang -target arm64-apple-ios15.0-macabi -isysroot "$sdk" -iframework "$sdk/System/iOSSupport/System/Library/Frameworks" \
    -fobjc-arc -w -I "$uikit" \
    -DUICalendarSelection=RevenantPortUICalendarSelection -DUICalendarSelectionMultiDate=RevenantPortUICalendarSelectionMultiDate \
    "$uikit/UICalendarSelection.m" "$multi" "$here/test.m" -framework UIKit -framework Foundation -framework CoreGraphics -o "$app"
codesign -s - --force "$app" > /dev/null 2>&1
"$app" > "$build/calendar-multidate.txt"
grep '^host	' "$build/calendar-multidate.txt" | cut -f2- > "$build/host.txt"
grep '^port	' "$build/calendar-multidate.txt" | cut -f2- > "$build/port.txt"
grep '^only	' "$build/calendar-multidate.txt" | cut -f2- > "$build/only.txt"
checks=$(wc -l < "$build/host.txt" | tr -d ' ')
if [ "$checks" -eq 0 ]; then
    echo "FAIL calendar-multidate: no checks ran"
    exit 1
fi
if [ "$checks" -ne "$(wc -l < "$build/port.txt" | tr -d ' ')" ]; then
    echo "FAIL calendar-multidate: the two sides printed different numbers of checks"
    exit 1
fi
only=$(wc -l < "$build/only.txt" | tr -d ' ')
if [ "$only" -eq 0 ]; then
    echo "FAIL calendar-multidate: the port-only checks did not run"
    exit 1
fi
bad=$(awk -F '\t' '$2 != "yes"' "$build/only.txt")
if [ -n "$bad" ]; then
    echo "FAIL calendar-multidate: port-only checks failed"
    echo "$bad"
    exit 1
fi
if diff "$build/host.txt" "$build/port.txt" > "$build/diff.txt"; then
    echo "ok calendar-multidate: $checks shared checks, the port answers as the host does; $only port-only tap checks hold"
else
    echo "FAIL calendar-multidate: the port and the host differ"
    cat "$build/diff.txt"
    exit 1
fi
