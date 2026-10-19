#!/bin/sh
# run.sh — a host differential for the shared value machinery (packages/a/apple-backports/RevenantValueStore.h)
# and for the MetricKit value classes built on it.
#
# What the host can answer: the system's own MetricKit writing a value nothing measured, which is an
# empty object — measured, an MXCPUMetric and an MXMetricPayload this process never filled in give
# -dictionaryRepresentation with no keys and -JSONRepresentation that parses as {}. The port must
# answer that the same way.
#
# What the host cannot answer is a populated value: nothing on the host populates one either, so the
# filled-in half is checked against the port's own contract — exactly the properties the SDK header
# declares, the JSON agreeing with the dictionary, and the archive round trip. The key spelling is a
# choice, and the case file says why.
#
# The three mutations are of the shared machinery itself, which is the point of having it in one
# header: a change to the conversion table or the property walk has to change a record here, or the
# header is not holding anything.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
metrickit=${METRICKIT:-$here/../../../../packages/a/apple-backports/MetricKit}
foundation=${FOUNDATION:-$here/../../../../packages/a/apple-backports/Foundation}
appledir=${APPLEDIR:-$here/../../../../packages/a/apple-backports}
store=${STORE:-$here/../../../../packages/a/apple-backports/RevenantValueStore.h}
registry=${REGISTRY:-$here/../../../../packages/a/apple-backports/registry/MetricKit/ios13.json}
build=${BUILD:-$(runs_fresh revenant-metricvalue)}
mkdir -p "$build"
sdk=$(xcrun --show-sdk-path --sdk macosx)
common="-target arm64-apple-ios15.0-macabi -isysroot $sdk -F $sdk/System/Library/Frameworks -iframework $sdk/System/iOSSupport/System/Library/Frameworks -fobjc-arc -w"
libs="-framework Foundation -framework MetricKit"

xcrun clang $common "$here/record.m" "$here/cases.m" $libs -o "$build/system"
METRICVALUE_RECORDS="$build/system.json" "$build/system"
echo "records: $(xmake l "$here/records.lua" count "$build/system.json")"

xmake l "$here/rename.lua" "$registry" "$build/rename.h"
port() {
    dir=$1
    # The shared header goes one level ABOVE the folder of .m files, exactly where the real tree has it,
    # because the port's own RevenantMetricValue.h reaches it as "../RevenantValueStore.h". With -I"$metrickit"
    # in the path every mutant was a copy of the unmutated header, which is why the first run of these
    # four reported all four surviving.
    xcrun clang $common -DREVENANT_METRICVALUE_PORT=1 -DREVENANT_HOST_DIFFERENTIAL=1 -include "$build/rename.h" -I"$here" -I"$dir" \
        "$here/record.m" "$here/cases.m" "$dir"/*.m $libs -o "$dir/run"
}
rm -rf "$build/port"; mkdir -p "$build/port"
cp "$metrickit"/*.m "$metrickit"/*.h "$build/port/"
cp "$store" "$build/RevenantValueStore.h"
cp "$appledir/RevenantSayOnce.h" "$build/RevenantSayOnce.h" 2>/dev/null || true
mkdir -p "$build/Foundation"
cp "$foundation"/RevenantOSLog.h "$foundation"/RevenantOSSignpost.h "$build/Foundation/"
port "$build/port"
METRICVALUE_RECORDS="$build/port.json" "$build/port/run"
xmake l "$here/compare.lua" "$build/system.json" "$build/port.json"

survived=0
# A mutation of the shared machinery, or of a port source, that must change a record.
mutant() {
    label=$1; file=$2; from=$3; to=$4
    rm -rf "$build/mutant"; mkdir -p "$build/mutant"
    cp "$metrickit"/*.m "$metrickit"/*.h "$build/mutant/"
    cp "$store" "$build/RevenantValueStore.h"
    target="$build/mutant/$file"
    [ "$file" = "RevenantValueStore.h" ] && target="$build/RevenantValueStore.h"
    if ! xmake l "$here/mutate.lua" "$target" "$from" "$to" >/dev/null; then
        echo "MUTATION DID NOT APPLY: $label (in $file)"; survived=$((survived + 1)); return
    fi
    port "$build/mutant"
    rm -f "$build/mutant.json"
    METRICVALUE_RECORDS="$build/mutant.json" timeout 90 "$build/mutant/run" >/dev/null 2>&1 || true
    # a mutant that cannot even build counts as caught: the record is gone
    if [ ! -f "$build/mutant.json" ]; then echo "caught (would not build): $label"; return; fi
    if cmp -s "$build/port.json" "$build/mutant.json"; then
        echo "MUTANT SURVIVED: $label"; survived=$((survived + 1))
    else
        # say WHICH record changed: a mutation that is caught for a reason nobody can see is not
        # holding anything
        for key in $(xmake l "$here/records.lua" differing "$build/port.json" "$build/mutant.json"); do
            echo "  caught by $key: $(xmake l "$here/records.lua" value "$build/port.json" "$key") -> $(xmake l "$here/records.lua" value "$build/mutant.json" "$key")"
        done
    fi
}
mutant "the date becomes a wall-clock reading" RevenantValueStore.h "        return @([(NSDate *)value timeIntervalSinceReferenceDate]);" "        return @([(NSDate *)value timeIntervalSince1970]);"
mutant "a measurement becomes a string" RevenantValueStore.h "        return @([(NSMeasurement *)value doubleValue]);" "        return [value description];"
mutant "nothing is ever stored" RevenantValueStore.h "        RevenantValueStore(owner)[key] = value;" "        RevenantValueStore(owner)[key] = nil;"
mutant "one gap property loses its accessor" MXValues140.m "@implementation MXAnimationMetric (RevenantMetricKit)
#ifndef REVENANT_HOST_DIFFERENTIAL
@dynamic hitchTimeRatio;
#endif

REVENANT_VALUE_PROPERTY(NSMeasurement *, hitchTimeRatio)

@end" "@implementation MXAnimationMetric (RevenantMetricKit)
#ifndef REVENANT_HOST_DIFFERENTIAL
@dynamic hitchTimeRatio;
#endif

@end"
mutant "an ordinary property loses its accessor" MXValues130.m "@dynamic cumulativeCPUTime, cumulativeCPUInstructions;

REVENANT_VALUE_PROPERTY(NSMeasurement *, cumulativeCPUTime)
REVENANT_VALUE_PROPERTY(NSMeasurement *, cumulativeCPUInstructions)" "@dynamic cumulativeCPUTime, cumulativeCPUInstructions;

REVENANT_VALUE_PROPERTY(NSMeasurement *, cumulativeCPUInstructions)"
if [ "$survived" -ne 0 ]; then echo "$survived mutations of the shared value machinery survived; the differential is not holding"; exit 1; fi
echo "mutations: all caught"
