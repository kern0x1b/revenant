#!/bin/sh
# The port's two UIPasteboard categories, LINKED against a stand-in for the release's own UIPasteboard
# and READ back: what the port asked of the release's primitives, and what it recorded for the two
# options the release cannot honour.
#
# The stand-in declares the RELEASE's surface - the selectors its selector table holds on 6.1.3 and on
# 4.3, and the type lists that are its own symbols - and records every call. The port's real objects
# are compiled unmodified and linked against it, so a call the port sends to the wrong receiver raises
# here, which a single-file compile cannot see.
#
# Two plants, each of which must make this FAIL: the stand-in MISREPORTS what it was told, so a check
# that compared only its own expectations would go green with a plant in place. all-wrong misreports
# every line; one-wrong misreports the one line about the type the release's list holds.
#
#   sh tests/backports/host/uikit-pasteboard/run.sh
#
# Not run through heavy.sh: it compiles four files and runs one binary, and the fleet's heavy lane is
# for the gate.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
tree=$(cd "$here/../../../.." && pwd)
port=$tree/packages/a/apple-backports/UIKit
build=${BUILD:-$(runs_folder uikit-pasteboard)}
mkdir -p "$build"

# the port's own objects, compiled UNMODIFIED: the categories must attach to the stand-in's class
FLAGS="-fobjc-arc -I $here/standin -w"
xcrun clang $FLAGS -c "$port/UIPasteboard+Items10.m" -o "$build/items10.o"
xcrun clang $FLAGS -c "$port/UIPasteboard+Objects11.m" -o "$build/objects11.o"
xcrun clang $FLAGS -c "$here/standin/standin.m" -o "$build/standin.o"
xcrun clang $FLAGS -c "$here/probe.m" -o "$build/probe.o"
# THE LINK. A port object that referenced a symbol no one defines fails here and not before.
xcrun clang $FLAGS "$build/items10.o" "$build/objects11.o" "$build/standin.o" "$build/probe.o" \
    -framework Foundation -o "$build/harness" 2> "$build/link.log" || {
    echo "LINK the port's objects against the stand-in did not link:"; sed 's/^/    /' "$build/link.log" | head -8; exit 1; }

expect() {
    # $1 the plant, $2 a line the run must print, $3 whether the run must fail
    out=$("$build/harness" "$1" 2>&1) || rc=$?
    rc=${rc:-0}
    if echo "$out" | grep -qF "$2"; then
        found=yes
    else
        found=no
    fi
    if [ "$3" = fail ]; then
        if [ "$rc" -eq 0 ] || [ "$found" = yes ]; then
            echo "PLANT $1: the harness did not notice it (exit $rc, line found: $found)"
            return 1
        fi
        echo "PLANT $1: noticed — $(echo "$out" | grep -c .) lines, exit $rc, and the expected line is absent"
    else
        if [ "$rc" -ne 0 ] || [ "$found" != yes ]; then
            echo "the clean run did not produce '$2' (exit $rc)"
            echo "$out" | sed 's/^/    /'
            return 1
        fi
        echo "CLEAN: $2"
    fi
    return 0
}

echo "== the clean run, which must print what the port asked of the release"
"$build/harness" clean > "$build/clean.txt" 2>&1 || { echo "the clean run failed:"; sed 's/^/    /' "$build/clean.txt"; exit 1; }
sed 's/^/    /' "$build/clean.txt"
lines=$(grep -c . "$build/clean.txt")
[ "$lines" -ge 6 ] || { echo "the harness printed $lines lines, which is too few to be a verdict"; exit 1; }

echo
echo
echo "== the clean run, judged by the one reader every run is judged by"
if ! xmake l "$here/check.lua" "$build/clean.txt"; then
    echo "  the clean run does not say what the port must say"
    exit 1
fi

echo
echo "== the plants, each of which must make the READER fail, naming the line it refused"
# The stand-in MISREPORTS what it was told, so a reader that compared only its own expectations would go
# green with a plant in place. The plant is proved by the reader going red, not by the output changing:
# the output changing is what a diff sees, and a diff is not the check.
for plant in all-wrong one-wrong; do
    "$build/harness" "$plant" > "$build/$plant.txt" 2>&1 || true
    if xmake l "$here/check.lua" "$build/$plant.txt" > "$build/$plant.check" 2>&1; then
        echo "PLANT $plant: FAILED - the reader passed a run the stand-in misreported"
        sed 's/^/    /' "$build/$plant.check"
        exit 1
    fi
    echo "PLANT $plant: the reader refused it, on:"
    grep "  FAIL" "$build/$plant.check" | head -3 | sed 's/^/    /'
    # and the clean run must still pass, or the reader is broken rather than strict
    xmake l "$here/check.lua" "$build/clean.txt" > /dev/null 2>&1 || {
        echo "PLANT $plant: the reader also refuses the CLEAN run, so it is not discriminating"; exit 1; }
done

echo
echo "harness: the port's objects link against the stand-in, and the same reader judged the clean run
and both plants - clean green, each plant red, naming the line it refused"
