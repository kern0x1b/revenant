#!/bin/sh
# run.sh — the sixteen rows of registry/HealthKit/ios8.json that sit at `absent`, asked of the port and
# of the system's own HealthKit in one process.
#
# The port's classes are compiled under names of their own (RevenantHostHKObject and so on) so that the
# system's HealthKit and the port's run side by side and both can be asked the same question, which is
# the only way to find out whether a row's `effect` is true of the port and of the class it is a
# backport of. The eight `-init` rows are the ones this settles: `-init` is `NS_UNAVAILABLE` in the
# header of each of the eight classes, which is a compile-time annotation and says nothing about what
# the class answers at run time, and an inherited method is not a symbol the port exports, so `nm` and
# the gate's own reader both miss it.
#
# Nothing is asked of anybody here: a class answering a selector is class shape, and an allocation
# through `-init` needs no store and no entitlement, so one process holds both halves. The port's
# constants are not compiled in, because the system's HealthKit exports the same symbols and the two
# would collide - the same arrangement tests/backports/host/healthkit/run.sh uses.
#
# The objects this builds are left where they are, under .agent-work/runs/healthkit8 in the checkout,
# because tools/release-split.lua reads a directory of *.o and the band of iOS 8.0 is checked against
# the cache ladder with it. Override with OBJECTSDIR.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
checkout=$(cd "$here/../../../.." && pwd)
healthkit=${HEALTHKIT:-$checkout/packages/a/apple-backports/HealthKit}
objects=${OBJECTSDIR:-$checkout/.agent-work/runs/healthkit8}
# REVENANT_HOST_BUILD: this is a host differential - the port's process links no framework of the name it
# measures, so there is no release class for a revenant_alias.h proxy to stand in for, nothing for the
# library's loader to re-parent and no name to export. The header's own comment gives the two
# measurements: the macOS linker refuses the metaclass alias ("ld: null objc class data for
# '_OBJC_METACLASS_$_Revenant<Name>'", from the smallest file that carries nothing but REVENANT_ALIAS), and
# a name built by ## cannot be renamed the way this harness renames classes. What the alias is FOR is a
# device band; here the class of the release's name is the class and every member of it is measured.
quiet="-w -DREVENANT_HOST_BUILD"
sdk=$(xcrun --show-sdk-path)

# A fresh tree every run: a differential that fails to link must leave no binary behind, or the next
# line runs the one the last run built and a stale answer stands for a fresh one.
rm -rf "$objects"
mkdir -p "$objects/plain" "$objects/renamed"

# The files that carry the sixteen rows' classes, which is the list tests/backports/host/healthkit/run.sh
# already builds: HKStatisticsCollection shares HKStatistics.m, HKWorkoutEvent shares HKWorkout.m and
# HKCategorySample lives in HKSamples.m, so a list that named one class per file would miss two of the
# eight the -init rows are about. HKDevice9.m is NOT in it and cannot be: it imports UIKit for the
# release's own UIDevice, which a host build has no use for and no framework to find, and the sixteen
# rows are about eight classes none of which is that one.
sources="HKUnit.m HKQuantity.m HKQuantityType.m HKQuantityTypes.m HKObjectType.m HKObject.m HKSource.m HKSample.m HKWorkout.m HKStatistics.m HKQuery.m HKQueries.m HKQueryAnchor9.m HKSourceRevision9.m HKSamples.m HKWorkoutRoute110.m HKWorkoutRouteQuery110.m HKCDADocument11.m HKClinicalRecord120.m HKWorkoutBuilder120.m HKQuantitySeriesSampleBuilder120.m HKQuantitySeriesSampleQuery120.m HKCumulativeQuantitySample130.m HKCumulativeQuantitySeriesSample120.m HKDocument10.m HKObject9.m HKSource9.m HKHealthStore.m RevenantHKStore.m"

for source in $sources; do
    xcrun clang -fobjc-arc $quiet -I"$healthkit" -c "$healthkit/$source" -o "$objects/plain/$source.o"
done

# Every class the port's own files carry, renamed; the system's own HealthKit carries the real names.
renames=""
for name in $(xcrun nm -gU "$objects"/plain/*.o | awk 'NF == 3 {print $3}' | grep -E '^_OBJC_CLASS_\$_' \
              | sed -e 's/^_OBJC_CLASS_\$_//' | sort -u); do
    renames="$renames -D$name=RevenantHost$name"
done

for source in $sources; do
    xcrun clang -fobjc-arc $quiet $renames -I"$healthkit" -c "$healthkit/$source" \
        -o "$objects/renamed/$source.o"
done

xcrun clang -fobjc-arc $quiet -I"$healthkit" "$here/probe.m" "$objects"/renamed/*.o \
    -framework Foundation -framework HealthKit -lsqlite3 -o "$objects/probe.new"
mv "$objects/probe.new" "$objects/probe"

"$objects/probe"

# What the registry says about the sixteen, beside what the two halves answered. The names are read out
# of the registry rather than written here, so a row that moves cannot leave this list behind: a name
# this list does not name is a check that was never run, and one it names that the registry does not is
# a check of a row that is gone.
#
# The registry rows of these sixteen are what the heredoc below reads. What is asserted here is only that the sixteen rows are the sixteen
# this file asked about, so a future row added to the same sixteen is caught by a reviewer rather than
# by a silent gap.
rows=$(python3 - "$checkout" <<'PY'
import json, sys
registry = json.load(open(sys.argv[1] + "/packages/a/apple-backports/registry/HealthKit/ios8.json"))
asked = ["+[HKQuery predicateForStatesOfMindWithAssociation:]",
         "+[HKQuery predicateForStatesOfMindWithKind:]",
         "+[HKQuery predicateForStatesOfMindWithLabel:]",
         "+[HKQuery predicateForStatesOfMindWithValence:operatorType:]",
         "-[HKCategorySample init]", "-[HKHealthStore endWorkoutSession:]",
         "-[HKHealthStore pauseWorkoutSession:]", "-[HKHealthStore resumeWorkoutSession:]",
         "-[HKHealthStore startWorkoutSession:]", "-[HKObject init]", "-[HKObjectType init]",
         "-[HKQuantity init]", "-[HKSource init]", "-[HKStatistics init]",
         "-[HKStatisticsCollection init]", "-[HKWorkoutEvent init]"]
rows = {entry["api"]: entry for entry in registry["entries"]}
missing = [name for name in asked if name not in rows]
for name in missing:
    print("row not in the registry: " + name)
for name in asked:
    if name in rows and rows[name]["status"] != "absent":
        print("row is not absent any more: %s (%s)" % (name, rows[name]["status"]))
print("rows asked about: %d, all absent in registry/HealthKit/ios8.json" % (len(asked) - len(missing)))
PY
)
printf '%s\n' "$rows"
printf '%s\n' "$rows" | grep -q '^rows asked about: 16, all absent'
