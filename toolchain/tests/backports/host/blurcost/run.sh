#!/bin/sh
# run.sh -- what the blur's shading costs, and so how much of a UIVisualEffectView refresh has to be
# on the main thread at all.
#
# Compiles the port's own RevenantBlur.m against a C shim for its Objective-C header
# (blurcost/RevenantBlur.h) and times revenant_blur_pixels at the three sizes
# packages/a/apple-backports/facts/UIKit/UIVisualEffect.md reports a whole refresh at. That is the
# BEFORE figure for moving the shading off the main thread: the read stays there whatever happens, and
# this is not it.
#
# The shim is a copy, not a -I path: RevenantBlur.m includes its header with quotes, and a quoted include
# looks in the including file's own directory before any -I, so the package's Objective-C header wins
# from wherever the compiler is run. The source is therefore copied beside the shim -- and `cmp` says
# the copy is the package's file, so a measurement cannot be taken against a source that has drifted
# from the one the port ships.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
root=$(cd "$here/../../../.." && pwd)
sources=${BLURCOST_SOURCES:-$root/packages/a/apple-backports/UIKit}
build=${BLURCOST_BUILD:-$(runs_folder revenant-blurcost)}
rm -rf "$build"
mkdir -p "$build"

cp "$here/RevenantBlur.h" "$build/RevenantBlur.h"
cp "$sources/RevenantBlur.m" "$build/RevenantBlur.m"
if ! cmp -s "$sources/RevenantBlur.m" "$build/RevenantBlur.m"; then
    echo "blurcost: the copy of RevenantBlur.m differs from the package's; refusing to measure" >&2
    exit 2
fi
printf '  source: %s\n' "$sources/RevenantBlur.m" >&2

cc -O2 -Wall -Wno-unused-parameter -I"$build" -c "$build/RevenantBlur.m" -o "$build/RevenantBlur.o"
cc -O2 -Wall -Wno-unused-parameter -I"$build" -o "$build/blurcost" "$here/blurcost.c" "$build/RevenantBlur.m"
"$build/blurcost"

# The shading is run off the main thread, and the reason it may be is that it touches no framework:
# it is arithmetic over a buffer its caller owns, plus malloc and free. That is checkable, so it is
# checked, and the check fails loudly if a later change gives it a call into UIKit, CoreGraphics or
# Foundation -- because then the same reasoning would no longer hold and the shading would have to
# come back to the thread that owns those.
# nm's own failure has to be a failure here, and an empty list has to be too: both mean the check
# did not run, and a check that passes when it did not is worse than no check. The first version read
# nm through `2>/dev/null` and compared whatever came back, so a missing nm made it pass.
if ! imports=$(nm -u "$build/RevenantBlur.o" | sed 's/^ *//' | sort -u | tr '\n' ' '); then
    echo "blurcost: nm could not read $build/RevenantBlur.o, so the framework-freedom check did not" >&2
    echo "  run. Refusing to pass a check that did not happen." >&2
    exit 2
fi
if [ -z "$imports" ]; then
    echo "blurcost: RevenantBlur.o reports no undefined symbols at all, which no build of it does." >&2
    echo "  The check did not run; refusing to pass it." >&2
    exit 2
fi
printf '  undefined symbols in RevenantBlur.o: %s\n' "$imports" >&2
for symbol in $imports; do
    case "$symbol" in
        _malloc|_free) ;;
        *)
            echo "blurcost: revenant_blur_pixels now needs $symbol, so it is no longer free of the" >&2
            echo "  framework and may not be shaded off the main thread. Undo that, or move the call" >&2
            echo "  back onto the thread that owns the framework and say why here." >&2
            exit 2
            ;;
    esac
done
echo "  the shading imports malloc and free only: it is free of the framework" >&2
