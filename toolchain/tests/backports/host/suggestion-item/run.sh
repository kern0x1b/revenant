#!/bin/sh
# run.sh: a differential of UISearchSuggestionItem, the port against the Mac Catalyst host's own class, in one process.
# The port's UIKit/UISearchSuggestionItem.m and test.m are compiled with -DUISearchSuggestionItem=CharonPortUISearchSuggestionItem, so the
# port's class has its own name and the host's class is still reached by name at run time. test.m prints the same checks for both;
# the run passes when the two sides print the same values, and fails on any difference or on no output.
# SUGGESTION_PORT_SOURCE replaces the port's source, so a planted wrong port can be run as a control: it must fail.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
port=${SUGGESTION_PORT_SOURCE:-$here/../../../../packages/a/apple-backports/UIKit/UISearchSuggestionItem.m}
build=${SUGGESTION_BUILD:-$(runs_fresh charon-suggestion-item)}
sdk=$(xcrun --show-sdk-path)
app="$build/suggestion-item"
xcrun clang -target arm64-apple-ios15.0-macabi -isysroot "$sdk" -iframework "$sdk/System/iOSSupport/System/Library/Frameworks" \
    -fobjc-arc -w -DUISearchSuggestionItem=CharonPortUISearchSuggestionItem \
    "$port" "$here/test.m" -framework UIKit -framework Foundation -framework CoreGraphics -o "$app"
codesign -s - --force "$app" > /dev/null 2>&1
"$app" > "$build/suggestion-item.txt"
grep '^host	' "$build/suggestion-item.txt" | cut -f2- > "$build/host.txt"
grep '^port	' "$build/suggestion-item.txt" | cut -f2- > "$build/port.txt"
checks=$(wc -l < "$build/host.txt" | tr -d ' ')
if [ "$checks" -eq 0 ]; then
    echo "FAIL suggestion-item: no checks ran"
    exit 1
fi
if [ "$checks" -ne "$(wc -l < "$build/port.txt" | tr -d ' ')" ]; then
    echo "FAIL suggestion-item: the two sides printed different numbers of checks"
    exit 1
fi
if diff "$build/host.txt" "$build/port.txt" > "$build/diff.txt"; then
    echo "ok suggestion-item: $checks checks, the port answers as the host does"
else
    echo "FAIL suggestion-item: the port and the host differ"
    cat "$build/diff.txt"
    exit 1
fi
