#!/bin/sh
# run.sh - the host differential of the Spatial overlay, and the control that says it can fail.
#
# Two halves, and the second is the one that can fail:
#
#   the host half builds tests/backports/host/spatial/main.swift against Apple's own
#   Spatial.framework, which the macOS SDK carries as a swiftinterface and the running system
#   answers for;
#
#   the port half builds the same main.swift against the module this tree holds, compiled the way
#   packages/runtimes/swift-runtime builds it: gyb first, then one unit per scalar with the recipe's own
#   flags. Every value on the right-hand side is therefore Apple's answer for the same input, and
#   check.lua compares the two transcripts number by number.
#
# The differential guards nothing unless it can tell a mutation from itself, so one mutation of the
# module's own sources is run against it and the run fails if the mutant survives or does not
# build. A compiler error is a build failure and proves nothing, which is how the first attempt at
# this was measured.
#
# The compiler is the Swift 6.4.0 the package builds with (revenant@swift 6.4.0), named rather than
# taken from PATH: SPATIAL_SWIFTC overrides it. The templates are rendered by modules/gyb and the comparison and
# the control run in Lua (xmake l), so nothing here runs python.
#
# What this is not: a test of the module against itself, and not a check of the API's shape. An
# expression only one of the two modules can answer is not asked here; the two compiles are what
# measure that, and their output is in the commit message and in facts/Spatial/README.md.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
files=${SPATIAL_FILES:-$here/../../../../packages/runtimes/swift-runtime/files}
here_root=$(cd "$here/../../../.." && pwd)
build=${SPATIAL_BUILD:-$(runs_folder host-spatial)}
sdk=${SPATIAL_SDK:-$(xcrun --show-sdk-path)}
# macOS 26, not 14: Spatial's `lerp`, `smoothstep` and `AffineTransform3D.columns` are marked
# macOS 26.0 in Apple's own interface, and an expression the host cannot answer is not a
# comparison.
target=${SPATIAL_TARGET:-$(uname -m)-apple-macos26.0}
swiftc=${SPATIAL_SWIFTC:-$HOME/.xmake/packages/s/swift/6.4.0/f1d0e4f9eebe477396350986a88081e5/bin/swiftc}
[ -x "$swiftc" ] || swiftc=swiftc
rm -rf "$build"
mkdir -p "$build/gen" "$build/ours"

# gyb writes the generated sources, and the two scalars come out of one template: the framework's
# every type has a Float twin that differs only in the scalar, which is what the recipe does.
sources=""
for source in "$files"/Spatial/*.swift.gyb; do
    name=$(basename "$source" .gyb)
    xmake l "$here_root/modules/gyb/main.lua" -DCMAKE_SIZEOF_VOID_P=4 --line-directive "" -o "$build/gen/$name.swift" "$source" || {
        echo "FAIL running gyb on $source"; exit 1; }
    sources="$sources $build/gen/$name.swift"
done
for source in "$files"/Spatial/*.swift; do
    cp "$source" "$build/gen/"
    sources="$sources $source"
done
# shellcheck disable=SC2086
[ -n "$(echo "$sources" | tr ' ' '\n' | grep -c swift)" ] || { echo "FAIL no sources under $files/Spatial"; exit 1; }

# The module, built the way build_overlay builds it: one unit, the module named, the interface and
# the object emitted together.
# shellcheck disable=SC2086
"$swiftc" -target "$target" -sdk "$sdk" -swift-version 5 -parse-as-library -O -wmo -module-name Spatial \
    -emit-module -emit-module-path "$build/ours/Spatial.swiftmodule" -emit-object \
    -module-link-name swiftSpatial -o "$build/ours/Spatial.o" $sources || {
    echo "FAIL building the Spatial module"; exit 1; }

"$swiftc" -target "$target" -sdk "$sdk" -swift-version 5 -o "$build/apple" "$here/main.swift" 2> \
    "$build/apple.err" || { echo "FAIL main.swift does not build against Apple's Spatial:"; grep "error:" "$build/apple.err" | head -6; exit 1; }
"$swiftc" -target "$target" -sdk "$sdk" -swift-version 5 -I "$build/ours" -o "$build/ours/spatial-check" \
    "$build/ours/Spatial.o" "$here/main.swift" 2> "$build/ours.err" || {
    echo "FAIL main.swift does not build against this tree's Spatial:"; grep "error:" "$build/ours.err" | head -6; exit 1; }

"$build/apple" > "$build/apple.txt" 2>&1 || { echo "FAIL the host binary"; head -5 "$build/apple.txt"; exit 1; }
"$build/ours/spatial-check" > "$build/ours.txt" 2>&1 || { echo "FAIL the port binary"; tail -5 "$build/ours.txt"; exit 1; }

# The status is the checker's, not the pipe's: `check.lua | tee` reports tee's, which is 0 over a
# suite that differs, and the control below then runs over a red comparison and calls every mutant
# a survivor.
xmake l "$here/check.lua" "$build/apple.txt" "$build/ours.txt" > "$build/compare.txt" 2>&1 && compare=0 || compare=1
cat "$build/compare.txt"

# The control: one token of the module's own sources, which still compiles, and the suite must go
# red over it. A red suite cannot show that, because it is red over the mutation for the reasons it
# was red before it: so the control runs only over a green comparison, and a suite that is not
# green says the control did not run instead of reporting a mutant as survived.
if [ "${SPATIAL_MUTANTS:-1}" = "1" ] && [ "$compare" -eq 0 ]; then
    survived=0
    notbuilt=0
    mutant() {
        label=$1; file=$2; from=$3; to=$4
        rm -rf "$build/mutant"; mkdir -p "$build/mutant"
        cp -R "$files" "$build/mutant/files"
        xmake l "$here/mutate.lua" "$build/mutant/files/Spatial/$file" "$from" "$to" || {
            echo "MUTANT REFUSED: $label"; survived=$((survived + 1)); return; }
        if SPATIAL_FILES="$build/mutant/files" SPATIAL_BUILD="$build/mutant-build" SPATIAL_MUTANTS=0 \
           sh "$here/run.sh" > "$build/mutant-build.log" 2>&1; then
            echo "MUTANT SURVIVED: $label"
            survived=$((survived + 1))
        elif grep -qE "error:" "$build/mutant-build.log"; then
            echo "MUTANT DID NOT BUILD: $label - a build failure, not a caught mutation"
            notbuilt=$((notbuilt + 1))
        else
            echo "caught: $label"
        fi
        rm -rf "$build/mutant-build" "$build/mutant"
    }
    # The quaternion's own product, with the two factors the other way round: the archived sources
    # had the composition on the right where the framework has it on the left, and this is the
    # token that puts it back.
    mutant "the quaternion product's real part" SpatialMatrix.swift.gyb \
        "w1 * w2 - (x1 * x2 + y1 * y2 + z1 * z2))" \
        "w1 * w2 + (x1 * x2 + y1 * y2 + z1 * z2))"
    if [ "$survived" -ne 0 ] || [ "$notbuilt" -ne 0 ]; then
        echo "$survived mutant(s) survived and $notbuilt did not build; the differential is not holding"
        exit 1
    fi
    echo "mutations: all caught"
elif [ "${SPATIAL_MUTANTS:-1}" = "1" ]; then
    echo "mutations: the control did not run, the comparison is not green"
fi
exit $compare
