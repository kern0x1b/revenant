#!/bin/sh
# The engine of UIKit Dynamics as revenant@box2d builds it gives, bit for bit, what upstream Box2D 2.2.1
# gives built the way its own CMake builds it: the recipe's flags (hidden symbols, no exceptions or
# RTTI, -Os) change nothing in the physics. A copy with one constant changed must differ, or the
# comparison proves nothing. The source is the recipe's own pinned archive, checked by its digest.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
box2d=$here
BUILD=${BUILD:-$(runs_fresh revenant-box2d)}
. "$here/source.sh"
rm -rf "$BUILD/mutant"
cp -R "$source" "$BUILD/mutant"
sed -i '' 's/#define b2_baumgarte[[:space:]]*0.2f/#define b2_baumgarte 0.21f/' "$BUILD/mutant/Box2D/Common/b2Settings.h"
cmp -s "$source/Box2D/Common/b2Settings.h" "$BUILD/mutant/Box2D/Common/b2Settings.h" && { echo "FAIL: the mutant changed nothing"; exit 1; }

build() {
    name=$1 root=$2
    shift 2
    mkdir -p "$BUILD/$name"
    for file in $(cd "$root" && find Box2D -name '*.cpp'); do
        xcrun clang++ -w "$@" -I"$root" -c "$root/$file" -o "$BUILD/$name/$(echo "$file" | tr / _).o"
    done
    xcrun clang++ -w "$@" -I"$root" "$here/scene.cpp" "$BUILD/$name"/*.o -o "$BUILD/$name/scene"
    "$BUILD/$name/scene" > "$BUILD/$name.txt"
}

# Optimising for macOS, clang joins sinf and cosf of one angle into __sincosf_stret, which the host's
# libm rounds differently. For armv7 before iOS 7 it has no such function to join them into and calls
# both, as upstream's unoptimised build does here; so the recipe's flags are compared with that join
# turned off, and the host must still diverge with it on, for the reason named.
separate="-fno-builtin-sinf -fno-builtin-cosf"
build upstream "$source"
build recipe "$source" $flags $separate
build joined "$source" $flags
build mutant "$BUILD/mutant" $flags $separate
lines=$(wc -l < "$BUILD/upstream.txt" | tr -d ' ')
[ "$lines" -gt 0 ] || { echo "FAIL: the scene printed nothing"; exit 1; }
if cmp -s "$BUILD/upstream.txt" "$BUILD/recipe.txt"; then
    echo "ok recipe flags ($flags) equal upstream's build bit for bit over $lines states"
else
    echo "FAIL recipe flags change the physics:"; diff "$BUILD/upstream.txt" "$BUILD/recipe.txt" | head -5; exit 1
fi
if cmp -s "$BUILD/upstream.txt" "$BUILD/joined.txt"; then
    echo "FAIL the host no longer diverges with sinf and cosf joined: drop $separate from this test"; exit 1
fi
if ! nm -u "$BUILD"/joined/*.o | grep -q '___sincosf_stret' || nm -u "$BUILD"/recipe/*.o | grep -q '___sincosf_stret'; then
    echo "FAIL the host diverges, but not by __sincosf_stret alone"; exit 1
fi
echo "ok the host diverges only where clang joins sinf and cosf into __sincosf_stret, as named"
if cmp -s "$BUILD/upstream.txt" "$BUILD/mutant.txt"; then
    echo "FAIL a changed b2_baumgarte gives the same states: the comparison sees nothing"; exit 1
fi
echo "ok the mutant (b2_baumgarte 0.21) differs in $(diff "$BUILD/upstream.txt" "$BUILD/mutant.txt" | grep -c '^<') of $lines states"
