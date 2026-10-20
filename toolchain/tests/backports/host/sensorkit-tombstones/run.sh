#!/bin/sh
# run.sh - the port's -[NSString sr_sensorForDeletionRecordsFromSensor] against the host's own, in two
# processes, with the mutation layer that makes the comparison falsifiable.
#
#   1. the port's own category is COMPILED and LINKED into the differential, which prints what it answers
#   2. the reader is COMPILED and LINKED separately, opens the host's SensorKit and prints what it answers
#      for the same fifty inputs
#   3. compare.lua puts the two side by side, input by input
#   4. three plants: every answer the wrong shape, the nil half removed, and the suffix appended twice -
#      each must turn the comparison red, and each must name the rows it broke
#   5. the comparator's own control: a HOST file with no rows must be red, so a run that compared nothing
#      cannot look green
#
# Two processes, and not one, because both sides are a category on NSString. In one process whichever
# loaded last would win and the port would be compared with itself - which is exactly what the fifty
# inputs are there to prevent being mistaken for agreement.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
appledir=${APPLEDIR:-$here/../../../../packages/frameworks/apple-backports}
port=$appledir/SensorKit/NSString+SensorKit14.m
build=${BUILD:-$(runs_fresh revenant-sensorkit-tombstones)}
mkdir -p "$build"

xcrun clang -fobjc-arc -w -c "$port" -o "$build/port.o"
xcrun clang -fobjc-arc -w -c "$here/differential.m" -o "$build/differential.o"
xcrun clang -fobjc-arc -w "$build/differential.o" "$build/port.o" -framework Foundation \
    -o "$build/differential"
xcrun clang -fobjc-arc -w "$here/read-host.m" -framework Foundation -o "$build/read-host"

"$build/differential" > "$build/port.out"
"$build/read-host" > "$build/host.out"
grep '^CONTROL' "$build/host.out" || { echo "FAIL the reader printed no control line"; exit 1; }

echo "--- the clean run"
xmake l "$here/compare.lua" "$build/port.out" "$build/host.out"

# A plant is a copy of the port's category with one change, and every one must make the comparison red.
# Each is written into its own directory so a harness that copied only the one file would fail to build
# rather than quietly measure nothing.
survived=0
plant() {
    label=$1; from=$2; to=$3
    rm -rf "$build/mutant"; mkdir -p "$build/mutant"
    if ! xmake l "$here/../../common/replace.lua" "$port" "$build/mutant/NSString+SensorKit14.m" "$from" "$to"; then
        echo "MUTATION DID NOT APPLY: $label"
        survived=$((survived + 1))
        return
    fi
    if xcrun clang -fobjc-arc -w -c "$build/mutant/NSString+SensorKit14.m" -o "$build/mutant.o" 2>/dev/null \
        && xcrun clang -fobjc-arc -w "$build/differential.o" "$build/mutant.o" -framework Foundation \
               -o "$build/differential-mutant" \
        && "$build/differential-mutant" > "$build/port-mutant.out"; then
        :
    else
        echo "MUTANT DID NOT BUILD, which is not the same as being noticed: $label"
        survived=$((survived + 1))
        return
    fi
    if xmake l "$here/compare.lua" "$build/port-mutant.out" "$build/host.out" > "$build/mutant-cmp.out" 2>&1; then
        echo "MUTANT SURVIVED: $label"
        survived=$((survived + 1))
    else
        echo "  caught: $(grep -c '^DIFFERS' "$build/mutant-cmp.out") of 58 inputs differ"
        echo "  caught: $(grep -m 1 '^sensorkit-tombstones:' "$build/mutant-cmp.out")"
    fi
}

echo "--- the plants"

plant "the nil half removed: a record's own name is suffixed again" \
    "    if ([self hasSuffix:RevenantSensorKitTombstoneSuffix])
        return nil;
" \
    ""

plant "the suffix appended twice: no input is ever nil" \
    "return [self stringByAppendingString:RevenantSensorKitTombstoneSuffix];" \
    "return [[self stringByAppendingString:RevenantSensorKitTombstoneSuffix]
            stringByAppendingString:RevenantSensorKitTombstoneSuffix];"

plant "the receiver ignored: every answer is the same string" \
    "return [self stringByAppendingString:RevenantSensorKitTombstoneSuffix];" \
    "return [NSString stringWithFormat:@\"%@%@\", RevenantSensorKitTombstoneSuffix, self];"

echo "--- the comparator's own control: a HOST file with no rows must be red"
: > "$build/host-empty.out"
xmake l "$here/compare.lua" "$build/port.out" "$build/host-empty.out" > "$build/empty-cmp.out" 2>&1 && {
    echo "FAIL comparing against nothing was green"
    exit 1
}
echo "  caught: $(grep -m 1 '^sensorkit-tombstones:' "$build/empty-cmp.out")"
echo "an empty host file is red, so this comparison is not one that can pass by looking at nothing"

if [ "$survived" -ne 0 ]; then echo "$survived plants survived; this check proves nothing"; exit 1; fi
echo "sensorkit-tombstones: OK - 58 inputs, 2 processes, 3 mutations noticed, the empty control red"