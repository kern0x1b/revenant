#!/bin/sh
# run.sh - the port's SensorKit names against the host's own SensorKit, in two processes, with the
# mutation layer that makes the comparison falsifiable.
#
#   1. the port's own sources are COMPILED and LINKED into the differential, which prints what the port
#      holds - two of them, because an object carries the API of one release and the family now spans
#      seven: SensorKitNames14.m for the 39 names of iOS 14.0, and names-extra.m, which imports
#      CharonSensorKitNames.h with all six later guards, for the 18 of 15.0 .. 26.0
#   2. the reader is COMPILED and LINKED separately, and opens the host's framework to print what it holds
#   3. compare.lua puts the two side by side, name by name, over the one list both walk
#   4. three plants: every value wrong in both port sources, one value wrong in the first, and one in
#      the second - each must turn the comparison red, and each one-wrong plant must name exactly one
#      row. Two of them rather than one, because there are two port-side sources now and a mutation
#      that only reaches the first would leave the second one unwatched
#   5. the comparator's own control: a HOST file with no rows must be red, so a run that compared
#      nothing cannot look green
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
port=${PORT:-$here/../../../../packages/a/apple-backports/SensorKit}
build=${SENSORKIT_NAMES_BUILD:-$(runs_fresh charon-sensorkit-names)}
mkdir -p "$build"

# The two port-side sources, compiled from a directory and linked into one differential.
# $1 the directory holding them, $2 the prefix for the two objects it writes.
port_objects() {
    xcrun clang -fobjc-arc -w -c "$1/SensorKitNames14.m" -o "$2-names14.o"
    xcrun clang -fobjc-arc -w -c "$1/names-extra.m" -o "$2-extra.o"
}

# A copy of the port's own two sources and of the header names-extra.m imports, into $1, so a plant
# can rewrite one of them and the rewritten file is what the next compile reads. A quoted #import
# resolves against the directory of the file including it first, which is what makes the copy win
# over the port's original - and why the plants must not be given -I"$port".
port_sources_into() {
    mkdir -p "$1"
    cp "$port/SensorKitNames14.m" "$1/SensorKitNames14.m"
    cp "$port/CharonSensorKitNames.h" "$1/CharonSensorKitNames.h"
    cp "$here/names-extra.m" "$1/names-extra.m"
}

# The one-wrong plant: $1 the directory, $2 the file inside it to rewrite.
# The identifier is read off the line before the initialiser rather than off a fixed spelling of the
# declaration, because the two port-side sources do not spell it the same way: SensorKitNames14.m
# writes CFStringRef const and CharonSensorKitNames.h writes NSString * const, the latter because the
# build's own SDK declares four of those names and a definition must match THAT declaration's type.
one_wrong() {
    line=$(grep -m 1 -n 'CFSTR("' "$1/$2" | cut -d: -f1)
    name=$(sed -n "${line}p" "$1/$2" | sed 's/^.* \([A-Za-z_][A-Za-z0-9_]*\) = .*CFSTR(.*/\1/')
    if [ -z "$name" ]; then
        echo "FAIL no constant name could be read off the first CFSTR line of $2"
        exit 1
    fi
    sed "${line}s/CFSTR(\"[^\"]*\")/CFSTR(\"WRONG\")/" "$1/$2" > "$1/$2.tmp"
    mv "$1/$2.tmp" "$1/$2"
    port_objects "$1" "$build/onewrong"
    xcrun clang -fobjc-arc -w "$build/differential.o" "$build/onewrong-names14.o" "$build/onewrong-extra.o" \
        -framework Foundation -o "$build/differential-onewrong"
    "$build/differential-onewrong" > "$build/port-onewrong.out"
    if xmake l "$here/compare.lua" "$build/port-onewrong.out" "$build/host.out" "$here/names.txt"; then
        echo "FAIL the one-wrong mutation of $2 was not noticed"
        exit 1
    fi
    named=$(xmake l "$here/compare.lua" "$build/port-onewrong.out" "$build/host.out" "$here/names.txt" \
            | grep -c "DIFFERS $name:")
    if [ "$named" -ne 1 ]; then
        echo "FAIL the one-wrong mutation of $2 named $named rows, and it must name exactly 1"
        exit 1
    fi
    echo "the one-wrong plant of $2 is red and names exactly $named row: $name"
}

# --- the clean build, from the port's own tree, with its header on the include path
xcrun clang -fobjc-arc -w -I"$here" -I"$port" -c "$port/SensorKitNames14.m" -o "$build/names14.o"
xcrun clang -fobjc-arc -w -I"$here" -I"$port" -c "$here/names-extra.m" -o "$build/extra.o"
xcrun clang -fobjc-arc -w -I"$here" -c "$here/differential.m" -o "$build/differential.o"
xcrun clang -fobjc-arc -w "$build/differential.o" "$build/names14.o" "$build/extra.o" \
    -framework Foundation -o "$build/differential"
xcrun clang -fobjc-arc -w -I"$here" "$here/read-host.m" -framework Foundation -o "$build/read-host"

"$build/differential" > "$build/port.out"
"$build/read-host" > "$build/host.out"
grep '^CONTROL' "$build/host.out" || { echo "FAIL the reader printed no control line"; exit 1; }

echo "--- the clean run"
xmake l "$here/compare.lua" "$build/port.out" "$build/host.out" "$here/names.txt"

echo "--- the all-wrong plant: every value replaced in both port sources"
port_sources_into "$build/allwrong"
sed 's/CFSTR("[^"]*")/CFSTR("WRONG")/g' "$build/allwrong/SensorKitNames14.m" > "$build/allwrong/SensorKitNames14.m.tmp"
mv "$build/allwrong/SensorKitNames14.m.tmp" "$build/allwrong/SensorKitNames14.m"
sed 's/CFSTR("[^"]*")/CFSTR("WRONG")/g' "$build/allwrong/CharonSensorKitNames.h" > "$build/allwrong/CharonSensorKitNames.h.tmp"
mv "$build/allwrong/CharonSensorKitNames.h.tmp" "$build/allwrong/CharonSensorKitNames.h"
port_objects "$build/allwrong" "$build/allwrong"
xcrun clang -fobjc-arc -w "$build/differential.o" "$build/allwrong-names14.o" "$build/allwrong-extra.o" \
    -framework Foundation -o "$build/differential-allwrong"
"$build/differential-allwrong" > "$build/port-allwrong.out"
if xmake l "$here/compare.lua" "$build/port-allwrong.out" "$build/host.out" "$here/names.txt"; then
    echo "FAIL the all-wrong mutation was not noticed"
    exit 1
fi
echo "the all-wrong plant is red, as it must be"

echo "--- the one-wrong plants: exactly one value replaced, in each of the two port sources"
port_sources_into "$build/onewrong14"
one_wrong "$build/onewrong14" "SensorKitNames14.m"
port_sources_into "$build/onewrongextra"
one_wrong "$build/onewrongextra" "CharonSensorKitNames.h"

echo "--- the comparator's own control: a HOST file with no rows must be red"
: > "$build/host-empty.out"
if xmake l "$here/compare.lua" "$build/port.out" "$build/host-empty.out" "$here/names.txt"; then
    echo "FAIL comparing against nothing was green"
    exit 1
fi
echo "an empty host file is red, so this comparison is not one that can pass by looking at nothing"

echo "sensorkit-names: OK - 57 names, 2 processes, 3 mutations noticed, the empty control red"