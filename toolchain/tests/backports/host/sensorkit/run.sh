#!/bin/sh
# run.sh — a host differential for SensorKit's four time functions.
#
# The host has a real SensorKit and the four functions work there; the port's are over the two clocks
# this release has. Their NUMBERS cannot be compared - the two anchors are different by construction -
# so what is compared is the three relations the header states: the round trip is exact, the pair names
# the same instant as CFAbsoluteTimeGetCurrent, and two readings increase. The port's half is the port's
# own file with its four functions renamed, so one binary carries both.
#
# There is no differential for SRSensorReader and this file is the reason: under Mac Catalyst the class
# is declared and implements nothing - respondsToSelector: is 0 for +authorizationStatus and +sharedReader
# and sending either raises - so the reader's answers stand on the header alone (facts/SensorKit).
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
appledir=${APPLEDIR:-$here/../../../../packages/a/apple-backports}
build=${BUILD:-$(runs_fresh revenant-sensorkit)}
mkdir -p "$build"
sdk=$(xcrun --show-sdk-path --sdk macosx)
common="-target arm64-apple-ios15.0-macabi -isysroot $sdk -F $sdk/System/Library/Frameworks -iframework $sdk/System/iOSSupport/System/Library/Frameworks -fobjc-arc -w"
libs="-framework Foundation -framework CoreFoundation -framework SensorKit"

xcrun clang $common -I"$here" "$here/record.m" "$here/cases.m" $libs -o "$build/system"
SENSORKIT_RECORDS="$build/system.json" "$build/system"
echo "records: $(xmake l "$here/records.lua" count "$build/system.json")"

xmake l "$here/rename.lua" "$appledir/registry/SensorKit/ios14.json" "$build/rename.h"
port() {
    dir=$1
    xcrun clang $common -DREVENANT_SENSORKIT_PORT=1 -include "$build/rename.h" -I"$here" -I"$appledir/SensorKit" \
        "$here/record.m" "$here/cases.m" "$dir/SRAbsoluteTime.m" "$dir/NSDate+SensorKit14.m" $libs -o "$dir/run"
}
rm -rf "$build/port"; mkdir -p "$build/port"
cp "$appledir/SensorKit/SRAbsoluteTime.m" "$build/port/"
cp "$appledir/SensorKit/NSDate+SensorKit14.m" "$build/port/"
port "$build/port"
SENSORKIT_RECORDS="$build/port.json" "$build/port/run"
xmake l "$here/compare.lua" "$build/system.json" "$build/port.json"

survived=0
mutant() {
    # the file to mutate is the fourth argument and defaults to the time functions, because a plant that
    # points at the category's own file and is applied to the time functions is not a mutation at all -
    # which is what the first version of the category's plant did, and mutate.lua said so by refusing.
    label=$1; from=$2; to=$3; which=${4:-SRAbsoluteTime.m}
    rm -rf "$build/mutant"; mkdir -p "$build/mutant"
    cp "$appledir/SensorKit/SRAbsoluteTime.m" "$build/mutant/"
    cp "$appledir/SensorKit/NSDate+SensorKit14.m" "$build/mutant/"
    if ! xmake l "$here/mutate.lua" "$build/mutant/$which" "$from" "$to" >/dev/null; then
        echo "MUTATION DID NOT APPLY: $label"; survived=$((survived + 1)); return
    fi
    port "$build/mutant"
    rm -f "$build/mutant.json"
    SENSORKIT_RECORDS="$build/mutant.json" timeout 90 "$build/mutant/run" >/dev/null 2>&1 || true
    if cmp -s "$build/port.json" "$build/mutant.json"; then echo "MUTANT SURVIVED: $label"; survived=$((survived + 1)); else
        for key in $(xmake l "$here/records.lua" differing "$build/port.json" "$build/mutant.json"); do
            echo "  caught by $key: $(xmake l "$here/records.lua" value "$build/port.json" "$key") -> $(xmake l "$here/records.lua" value "$build/mutant.json" "$key")"
        done
    fi
}
mutant "the round trip loses a second" "    return (SRAbsoluteTime)(anchor->absolute + (cf - anchor->absolute));" "    return (SRAbsoluteTime)(anchor->absolute + (cf - anchor->absolute) + 1.0);"
mutant "the category's round trip gains a millisecond" \
    "    return SRAbsoluteTimeFromCFAbsoluteTime((CFAbsoluteTime)self.timeIntervalSinceReferenceDate);" \
    "    return SRAbsoluteTimeFromCFAbsoluteTime((CFAbsoluteTime)self.timeIntervalSinceReferenceDate) + 0.001;" \
    "NSDate+SensorKit14.m"
mutant "the reading does not advance" "    NSTimeInterval elapsed = RevenantSensorKitSecondsFromTicks(mach_absolute_time() - anchor->continuous);" "    NSTimeInterval elapsed = 0.0;"
if [ "$survived" -ne 0 ]; then echo "$survived mutations survived; the differential is not holding"; exit 1; fi
echo "mutations: all caught"
