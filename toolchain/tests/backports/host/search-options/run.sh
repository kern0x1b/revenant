#!/bin/sh
# run.sh: a differential of UITextSearchOptions, the port against the Mac Catalyst host's own class, in one process.
# The port's UIKit/UITextSearchOptions.m and test.m are compiled with -DUITextSearchOptions=RevenantPortUITextSearchOptions, so the
# port's class has its own name and the host's class is still reached by name at run time. test.m prints the same checks for both;
# the run passes when the two sides print the same values, and fails on any difference or on no output.
# SEARCH_PORT_SOURCE replaces the port's source, so a planted wrong port can be run as a control: it must fail.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
port=${SEARCH_PORT_SOURCE:-$here/../../../../packages/a/apple-backports/UIKit/UITextSearchOptions.m}
build=${SEARCH_BUILD:-$(runs_fresh revenant-search-options)}
sdk=$(xcrun --show-sdk-path)
app="$build/search-options"
xcrun clang -target arm64-apple-ios15.0-macabi -isysroot "$sdk" -iframework "$sdk/System/iOSSupport/System/Library/Frameworks" \
    -fobjc-arc -w -DUITextSearchOptions=RevenantPortUITextSearchOptions \
    "$port" "$here/test.m" -framework UIKit -framework Foundation -framework CoreGraphics -o "$app"
codesign -s - --force "$app" > /dev/null 2>&1
"$app" > "$build/search-options.txt"
grep '^host	' "$build/search-options.txt" | cut -f2- > "$build/host.txt"
grep '^port	' "$build/search-options.txt" | cut -f2- > "$build/port.txt"
checks=$(wc -l < "$build/host.txt" | tr -d ' ')
if [ "$checks" -eq 0 ]; then
    echo "FAIL search-options: no checks ran"
    exit 1
fi
if [ "$checks" -ne "$(wc -l < "$build/port.txt" | tr -d ' ')" ]; then
    echo "FAIL search-options: the two sides printed different numbers of checks"
    exit 1
fi
# Named divergences, asserted: the host's class answers a set through setWordMatchMethod: and setStringCompareOptions: although the
# header declares both properties readonly, and stores what it is given; the port has no such setters. The host's hash is per object
# (two equal defaults hash differently), where the port's follows the value. Both sides' answers are asserted; the rest must match.
# If the host stops storing a set, or its hash starts to follow the value, the divergence is gone and this run fails.
host_named=$(awk -F '\t' '($1 == "wordmatch-setter" && $2 == "2") || ($1 == "compare-setter" && $2 == "1") || ($1 == "hash-equal-defaults" && $2 == "no")' "$build/host.txt" | wc -l | tr -d ' ')
port_named=$(awk -F '\t' '($1 == "wordmatch-setter" && $2 == "no setter") || ($1 == "compare-setter" && $2 == "no setter") || ($1 == "hash-equal-defaults" && $2 == "yes")' "$build/port.txt" | wc -l | tr -d ' ')
if [ "$host_named" -ne 3 ] || [ "$port_named" -ne 3 ]; then
    echo "FAIL search-options: a named divergence changed (host answers $host_named of 3, port answers $port_named of 3)"
    exit 1
fi
divergent='^(wordmatch-setter|compare-setter|hash-equal-defaults)$'
awk -F '\t' -v p="$divergent" '$1 !~ p' "$build/host.txt" > "$build/host-common.txt"
awk -F '\t' -v p="$divergent" '$1 !~ p' "$build/port.txt" > "$build/port-common.txt"
if diff "$build/host-common.txt" "$build/port-common.txt" > "$build/diff.txt"; then
    echo "ok search-options: $checks checks, $(wc -l < "$build/host-common.txt" | tr -d ' ') compared, the port answers as the host does; the 3 named divergences are asserted"
else
    echo "FAIL search-options: the port and the host differ"
    cat "$build/diff.txt"
    exit 1
fi
