#!/bin/sh
# run.sh: a differential of UICalendarView and UICalendarViewDecoration, the port against the Mac Catalyst host's own classes, in one process.
# The port's UIKit/UICalendarView.m and UIKit/UICalendarViewDecoration.m and test.m are compiled with the classes renamed to CharonPort...,
# so the port's classes have their own names and the host's are still reached by name at run time. test.m prints the shared checks for both
# sides and the port-only checks; the run passes when the shared lines agree, every port-only check holds, and the output is complete.
# CALENDAR_PORT_SOURCE replaces the port's view source, so a planted wrong port can be run as a control: it must fail.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
uikit=$here/../../../../packages/a/apple-backports/UIKit
view=${CALENDAR_PORT_SOURCE:-$uikit/UICalendarView.m}
build=${CALENDAR_BUILD:-$(runs_fresh charon-calendar-view)}
sdk=$(xcrun --show-sdk-path)
app="$build/calendar-view"
xcrun clang -target arm64-apple-ios15.0-macabi -isysroot "$sdk" -iframework "$sdk/System/iOSSupport/System/Library/Frameworks" \
    -fobjc-arc -w -I "$uikit" \
    -DUICalendarView=CharonPortUICalendarView -DUICalendarViewDecoration=CharonPortUICalendarViewDecoration \
    "$view" "$uikit/UICalendarViewDecoration.m" "$here/test.m" -framework UIKit -framework Foundation -framework CoreGraphics -o "$app"
codesign -s - --force "$app" > /dev/null 2>&1
"$app" > "$build/calendar-view.txt"
grep '^host	' "$build/calendar-view.txt" | cut -f2- > "$build/host.txt"
grep '^port	' "$build/calendar-view.txt" | cut -f2- > "$build/port.txt"
grep '^only	' "$build/calendar-view.txt" | cut -f2- > "$build/only.txt"
checks=$(wc -l < "$build/host.txt" | tr -d ' ')
if [ "$checks" -eq 0 ]; then
    echo "FAIL calendar-view: no checks ran"
    exit 1
fi
if [ "$checks" -ne "$(wc -l < "$build/port.txt" | tr -d ' ')" ]; then
    echo "FAIL calendar-view: the two sides printed different numbers of checks"
    exit 1
fi
# Port-only checks: each is "yes", except the first-day check, which must name May 1 2024.
only=$(wc -l < "$build/only.txt" | tr -d ' ')
if [ "$only" -eq 0 ]; then
    echo "FAIL calendar-view: the port-only checks did not run"
    exit 1
fi
bad=$(awk -F '\t' '!(($1 == "tap-first-day-of-may" && $2 == "2024/5/1") || $2 == "yes")' "$build/only.txt")
if [ -n "$bad" ]; then
    echo "FAIL calendar-view: port-only checks failed"
    echo "$bad"
    exit 1
fi
if diff "$build/host.txt" "$build/port.txt" > "$build/diff.txt"; then
    echo "ok calendar-view: $checks shared checks, the port answers as the host does; $only port-only checks hold"
else
    echo "FAIL calendar-view: the port and the host differ"
    cat "$build/diff.txt"
    exit 1
fi
