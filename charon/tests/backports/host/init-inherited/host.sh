#!/bin/sh
# host.sh - what -init and +new answer on the HealthKit classes the port defines, against the host's own.
#
# The port's classes are compiled with CHARON_HOST_BUILD and their names renamed (CharonHost<Name>), so the
# system's HealthKit and the port's run in one process and each is asked the same question. probe.m holds
# the questions. The sources are the arithmetic set of tests/backports/host/healthkit/run.sh, without its
# constants files: the probe reads no constant, and a constant the sources name still resolves to the host's.
# Run it on a macOS host with the command line tools; it is not part of the light guard.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
healthkit=${HEALTHKIT:-$here/../../../../packages/a/apple-backports/HealthKit}
BUILD=${BUILD:-$(runs_fresh charon-init-inherited)}
quiet="-w -DCHARON_HOST_BUILD"
rm -rf "$BUILD"
mkdir -p "$BUILD/plain" "$BUILD/renamed"

sources="HKUnit.m HKQuantity.m HKQuantityType.m HKQuantityTypes.m HKObjectType.m HKObject.m HKSource.m HKSample.m HKWorkout.m HKStatistics.m HKQuery.m HKQueries.m HKQueryAnchor9.m HKSourceRevision9.m HKSamples.m HKWorkoutRoute110.m HKWorkoutRouteQuery110.m HKCDADocument11.m HKClinicalRecord120.m HKWorkoutBuilder120.m HKQuantitySeriesSampleBuilder120.m HKQuantitySeriesSampleQuery120.m HKCumulativeQuantitySample130.m HKCumulativeQuantitySeriesSample120.m HKDocument10.m HKObject9.m HKSource9.m HKHealthStore.m CharonHKStore.m"

# The first pass names every class the port's own files carry, so the second pass can rename them all.
for source in $sources; do
    xcrun clang -fobjc-arc $quiet -I"$healthkit" -c "$healthkit/$source" -o "$BUILD/plain/$source.o"
done
renames=""
for name in $(xcrun nm -gU "$BUILD"/plain/*.o | awk 'NF == 3 {print $3}' | grep -E '^_OBJC_CLASS_\$_' \
              | sed -e 's/^_OBJC_CLASS_\$_//' | sort -u); do
    renames="$renames -D$name=CharonHost$name"
done
for source in $sources; do
    xcrun clang -fobjc-arc $quiet $renames -I"$healthkit" -c "$healthkit/$source" -o "$BUILD/renamed/$source.o"
done

# Built under a second name and moved into place once it exists, so only the binary this run built can run.
xcrun clang -fobjc-arc -w -I"$healthkit" "$here/probe.m" "$BUILD"/renamed/*.o \
    -framework Foundation -framework HealthKit -lsqlite3 -o "$BUILD/probe.new"
mv "$BUILD/probe.new" "$BUILD/probe"

"$BUILD/probe"
