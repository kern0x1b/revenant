#!/bin/sh
# factory-probe.sh - build and run the port's own +revenant_mapWithDimensions: check.
#
# The system's AXBrailleMap has no public initialiser, so there is no counterpart to compare a sized map
# against. This builds the port's class alone, with no Accessibility framework linked, and asks it the
# questions the two-sided case cannot ask: that the map comes back the size it was handed, that every pin
# of a grid reads back, and that two sized maps do not share one.
#
# The run.sh that calls this does not diff anything against it, and a probe that were compared against
# something that does not exist would be a check of nothing - so it prints its own answers and a caller
# that wants to see them changed reads the log.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
root=$(cd "$here/../../../.." && pwd)
sources=${ACCESSIBILITY_SRC:-$root/packages/a/apple-backports/Accessibility}
build=${FACTORY_BUILD:-$(runs_folder revenant-accessibilitymap-factory)}
rm -rf "$build"
mkdir -p "$build"
sdk=$(xcrun --show-sdk-path)
xcrun clang -target arm64-apple-macos26.0 -isysroot "$sdk" -fobjc-arc -O0 -Wall -Wno-nonnull \
    -DAXBrailleMap=RevenantPortAXBrailleMap -DAXBrailleMapRenderer=RevenantPortAXBrailleMapRenderer \
    "$here/factory-probe.m" "$sources/RevenantBrailleMap.m" \
    -I"$root/packages/a/apple-backports" -I"$root/packages/a/apple-backports/Accessibility" \
    -framework Foundation -framework CoreGraphics \
    -o "$build/factory" 2> "$build/build.log" || {
        echo "the factory probe did not build" >&2
        tail -20 "$build/build.log" >&2
        exit 1
    }
"$build/factory"
