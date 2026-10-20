#!/bin/sh
# run.sh — holds the port's HealthKit arithmetic against the host's own, in one process.
#
# The port's classes are compiled under names of their own (RevenantHostHKUnit and so on) so that the
# system's HealthKit and the port's run side by side and the two can be asked the same question. What
# is compared is the arithmetic a host answers without asking anybody for anything: a unit converts, a
# unit multiplies and divides and is raised to a power, a quantity compares, a quantity type says
# which unit it is counted in and which aggregation it uses. The store, the authorization and the
# queries are not in here — a host keeps its data in a healthd behind an entitlement, and this port's
# is a SQLite database of its own, so neither side is an oracle for the other's.
#
# The port's constants are compiled in under names of their own (RevenantHK120_HKErrorDomain and so on):
# the host's HealthKit exports the same symbols, so the port's definitions and the host's cannot both be
# linked under one name. That is also the better arrangement for this test - each of the twenty-one
# constants of 12.0 is read out of the port's own object and out of the host's and the two values are
# compared, where a literal in the differential would only compare the host against a string written
# beside it. The identifier both sides are asked about for the arithmetic is the host's own, and the
# port's table is what is held to it.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
. "$here/../../common/generated.sh"
ensure_generated "$here" HealthKit
healthkit=${HEALTHKIT:-$here/../../../../packages/frameworks/apple-backports/HealthKit}
BUILD=${BUILD:-$(runs_fresh revenant-healthkit)}
sdk=$(xcrun --show-sdk-path)
# REVENANT_HOST_BUILD: this is a host differential - the port's process links no framework of the name it
# measures, so there is no release class for a revenant_alias.h proxy to stand in for, nothing for the
# library's loader to re-parent and no name to export. The header's own comment gives the two
# measurements: the macOS linker refuses the metaclass alias ("ld: null objc class data for
# '_OBJC_METACLASS_$_Revenant<Name>'", from the smallest file that carries nothing but REVENANT_ALIAS), and
# a name built by ## cannot be renamed the way this harness renames classes. What the alias is FOR is a
# device band; here the class of the release's name is the class and every member of it is measured.
quiet="-w -DREVENANT_HOST_BUILD"
# The whole build directory goes and not only its two object subdirectories. A run that fails to link
# then leaves no differential at all, where before it left the one the previous run built, and the line
# after this one ran that: a stale binary answering for a fixed source. The mutant step below, which
# compiles into the same tree, is cleared the same way for the same reason.
rm -rf "$BUILD"
mkdir -p "$BUILD/plain" "$BUILD/renamed"

# The measured constant objects are written by gen into .gen/HealthKit (tools/gen/measured.lua), not committed, so the folder the sources
# are compiled from is the committed one with those objects laid beside it. set -e stops the run when gen has not written them.
staged="$BUILD/layout"
mkdir -p "$staged/HealthKit"
# the package root's headers come along too: a source of the folder includes one of them by "../" (HKCDADocument11.m, "../revenant_alias.h")
cp "$healthkit"/../*.h "$staged/"
cp "$healthkit"/*.m "$healthkit"/*.h "$staged/HealthKit/"
cp "$healthkit/../.gen/HealthKit"/HKConstants*.m "$staged/HealthKit/"
healthkit=$staged/HealthKit

# The files that carry the arithmetic, plus the store, which is where two of the port's own functions
# live (the error it answers with and the line it says once in the log) and which is the only file that
# defines them. Nothing in this test opens a database: the store is compiled so that what the unit and
# quantity code calls exists, not so that the store is measured.
sources="HKUnit.m HKQuantity.m HKQuantityType.m HKQuantityTypes.m HKObjectType.m HKObject.m HKSource.m HKSample.m HKWorkout.m HKStatistics.m HKQuery.m HKQueries.m HKQueryAnchor9.m HKSourceRevision9.m HKSamples.m HKWorkoutRoute110.m HKWorkoutRouteQuery110.m HKCDADocument11.m HKClinicalRecord120.m HKWorkoutBuilder120.m HKQuantitySeriesSampleBuilder120.m HKQuantitySeriesSampleQuery120.m HKCumulativeQuantitySample130.m HKCumulativeQuantitySeriesSample120.m HKDocument10.m HKObject9.m HKSource9.m HKHealthStore.m RevenantHKStore.m HKConstants120.m HKConstants134.m HKConstants160.m HKConstants180.m HKConstants182.m HKConstants260.m HKConstants262.m"

for source in $sources; do
    xcrun clang -fobjc-arc $quiet -I"$healthkit" -c "$healthkit/$source" -o "$BUILD/plain/$source.o"
done

# Every class the port's own files carry, renamed; the system's own HealthKit carries the real names.
renames=""
for name in $(xcrun nm -gU "$BUILD"/plain/*.o | awk 'NF == 3 {print $3}' | grep -E '^_OBJC_CLASS_\$_' \
              | sed -e 's/^_OBJC_CLASS_\$_//' | sort -u); do
    renames="$renames -D$name=RevenantHost$name"
done
echo "renamed:$renames"

# The twenty-one constants of 12.0, renamed for the same reason the classes are: the host's HealthKit
# exports those symbols too, so the port's definitions and the host's cannot both be linked under one
# name. The list is written out rather than taken from the plain objects' symbol list, because that
# list holds the port's C functions as well and renaming one would answer to a name nothing declares -
# this file declares RevenantHKClassForObjectKind and RevenantHKSetClassResolver itself, and it is
# compiled without these flags.
constants=""
for name in HKFHIRResourceTypeAllergyIntolerance HKFHIRResourceTypeCondition HKFHIRResourceTypeImmunization \
            HKFHIRResourceTypeMedicationDispense HKFHIRResourceTypeMedicationOrder HKFHIRResourceTypeMedicationStatement \
            HKFHIRResourceTypeObservation HKFHIRResourceTypeProcedure \
            HKClinicalTypeIdentifierAllergyRecord HKClinicalTypeIdentifierConditionRecord \
            HKClinicalTypeIdentifierImmunizationRecord HKClinicalTypeIdentifierLabResultRecord \
            HKClinicalTypeIdentifierMedicationRecord HKClinicalTypeIdentifierProcedureRecord \
            HKClinicalTypeIdentifierVitalSignRecord \
            HKMetadataKeyCrossTrainerDistance HKMetadataKeyFitnessMachineDuration HKMetadataKeyIndoorBikeDistance \
            HKPredicateKeyPathClinicalRecordFHIRResourceIdentifier HKPredicateKeyPathClinicalRecordFHIRResourceType \
            HKPredicateKeyPathSum; do
    constants="$constants -D$name=RevenantHK120_$name"
done
# The six of 11.2 that join HKConstants120.m take the prefix its twenty-one already take.
for name in HKMetadataKeyAlpineSlopeGrade HKMetadataKeyAverageSpeed HKMetadataKeyElevationAscended \
            HKMetadataKeyElevationDescended HKMetadataKeyMaximumSpeed \
            HKQuantityTypeIdentifierDistanceDownhillSnowSports; do
    constants="$constants -D$name=RevenantHK120_$name"
done
# The other 187 of the measured group, renamed for the same reason the twenty-one above are: the
# host's HealthKit exports those symbols too, so the port's definitions and the host's cannot both
# be linked under one name. The list is taken from the plain objects' own symbol list, so a constant
# added to an object is renamed by the next run without this list being edited; a name the two loops
# above already gave a prefix is skipped, because two -D of one name is a redefinition and only the
# last would take effect.
measured=""
for name in $(xcrun nm -gU "$BUILD"/plain/*.o | awk 'NF == 3 {print $3}' | grep -E '^_HK' \
              | sed -e 's/^_//' | sort -u); do
    case " $constants " in *" -D$name="*) continue ;; esac
    measured="$measured -D$name=RevenantHKMeasured_$name"
done
constants="$constants$measured"

for source in $sources; do
    xcrun clang -fobjc-arc $quiet $renames $constants -I"$healthkit" -c "$healthkit/$source" -o "$BUILD/renamed/$source.o"
done

# Built under a second name and moved into place only once it exists, so the line after this one can
# only ever run the binary this run built.
xcrun clang -fobjc-arc $quiet -I"$healthkit" "$here/differential.m" "$BUILD"/renamed/*.o \
    -framework Foundation -framework HealthKit -lsqlite3 -o "$BUILD/differential.new"
mv "$BUILD/differential.new" "$BUILD/differential"

"$BUILD/differential"

# A difference the two are bound to have, and why. HKQuantityAggregationStyle has two cases in the
# header this library is compiled against - cumulative and discrete arithmetic - and the header whose
# comment the type table is read from names five. The host answers the three later ones with a case of
# its own, so for these ten types the host's aggregationStyle is a number this library's caller has no
# case for, and this library answers the one discrete style it has. The type, its unit and its factor
# are the same on both sides, and the cumulative-or-discrete property - the one the contract has - is
# compared for every type.
#
#   HKQuantityTypeIdentifierAtrialFibrillationBurden          host 2, port 1
#   HKQuantityTypeIdentifierCyclingCadence                   host 2, port 1
#   HKQuantityTypeIdentifierCyclingPower                     host 2, port 1
#   HKQuantityTypeIdentifierCyclingSpeed                     host 2, port 1
#   HKQuantityTypeIdentifierEnvironmentalAudioExposure        host 3, port 1
#   HKQuantityTypeIdentifierEnvironmentalSoundReduction      host 3, port 1
#   HKQuantityTypeIdentifierHeadphoneAudioExposure           host 3, port 1
#   HKQuantityTypeIdentifierHeartRate                        host 2, port 1
#   HKQuantityTypeIdentifierRestingHeartRate                 host 2, port 1
#   HKQuantityTypeIdentifierWalkingHeartRateAverage          host 2, port 1
#
# A second one, and the only other: the order of the factors of a product. The host writes a product in
# an order of its own - it answers J/m·s·kg for J/(m*kg*s), for J/(s*kg*m) and for J/(m*s*kg) alike -
# and the public API does not say what that order is. This library writes the factors in the order they
# were given, which is a different order for some products and the same for the rest. The test compares
# the factors as a set, and everything else about a product: which units it accepts, and the number it
# converts to and from.
#
# A mutant that survives would mean the test cannot see a change it is supposed to see, so three are
# run: a factor wrong in its last place, a unit string wrong by one letter, and the micro prefix spelled
# the way it is commonly spelled and the host refuses.
survived=0
mutant() {
    file=$1; from=$2; to=$3
    # The mutant's tree keeps the library's own layout, so that a source which reaches out of its
    # folder for the shared header still finds it and only the one change is in it.
    rm -rf "$BUILD/mutant"; mkdir -p "$BUILD/mutant/HealthKit"
    # nothing of a previous run's may be here: the binary is only run if this step builds it
    rm -f "$BUILD/mutant/differential"
    cp "$healthkit"/*.m "$healthkit"/*.h "$BUILD/mutant/HealthKit/"
    cp "$here/../../../../packages/frameworks/apple-backports/RevenantSayOnce.h" "$BUILD/mutant/"
    runs_xmake l "$here/../../common/substitute.lua" all "$BUILD/mutant/HealthKit/$file" "$from" "$to"
    for source in $sources; do
        xcrun clang -fobjc-arc $quiet $renames $constants -I"$BUILD/mutant/HealthKit" -c "$BUILD/mutant/HealthKit/$source" \
            -o "$BUILD/mutant/$source.o" 2>/dev/null || true
    done
    xcrun clang -fobjc-arc $quiet -I"$BUILD/mutant/HealthKit" "$here/differential.m" "$BUILD"/mutant/*.o \
        -framework Foundation -framework HealthKit -lsqlite3 -o "$BUILD/mutant/differential" 2>/dev/null || true
    if [ -x "$BUILD/mutant/differential" ] && "$BUILD/mutant/differential" > /dev/null 2>&1; then
        echo "MUTANT SURVIVED: $file $from -> $to"; survived=$((survived + 1))
    fi
}
mutant HKUnit.m '{@"mmHg", RevenantHKDimensionPressure, 133.32236842105263, 0.0},' '{@"mmHg", RevenantHKDimensionPressure, 133.322387415, 0.0},'
mutant HKUnit.m 'return @"mc";' 'return @"u";'
mutant HKUnit.m '@"appleEffortScore", RevenantHKDimensionEffortScore, 1.0, 0.0},' '@"appleEffortScore2", RevenantHKDimensionEffortScore, 1.0, 0.0},'
# A mutant of the 12.0 builder: the elapsed time a begun period answers, which the differential
# compares twice, and the refusal a second begin answers, which it compares once.
mutant HKWorkoutBuilder120.m 'return [date timeIntervalSinceDate:_startDate];' 'return [date timeIntervalSinceDate:_startDate] + 1.0;'
# A second begin of a period the host refuses, which this port refuses with a completion of its own and
# the test compares against the second begin of the host's own builder.
mutant HKWorkoutBuilder120.m 'if (_collecting) {' 'if (NO) {'
echo "mutants surviving: $survived"
[ "$survived" -eq 0 ]
# A mutant of the 12.0 series builder: the date refusal, which the differential compares against the
# host's own answer for a date before the builder's start.
mutant HKQuantitySeriesSampleBuilder120.m 'if ([date compare:_startDate] == NSOrderedAscending) {' 'if (NO) {'
# A mutant of the store's gate: one class's adoption of RevenantHKStorable removed, which must turn the
# round trip red - the store refuses that class again, and a save that is not checked would pass.
mutant HKSamples.m '@interface HKQuantitySample (RevenantHKStorable) <RevenantHKStorable>' '@interface HKQuantitySample (RevenantHKStorableNotAdopted)'
# A mutant of the 12.0 series query: the date a delivered quantity is reported at. The differential
# saves a sample over a real period and compares the date the query delivers against the start date it
# built the sample with, so a query answering the end date instead, or none at all, is a difference.
mutant HKQuantitySeriesSampleQuery120.m 'revenant_deliverQuantity:quantitySample.quantity date:quantitySample.startDate done:NO error:nil' 'revenant_deliverQuantity:quantitySample.quantity date:quantitySample.endDate done:NO error:nil'
# A mutant of the four most-recent members: the comparison that decides which sample is the most recent.
# The differential asks for the most recent over samples whose dates are chosen so that the strict
# comparison and a non-strict one answer differently, so a mutant that compares the wrong way is caught.
mutant HKStatistics.m '== NSOrderedDescending) {
            statistics->_mostRecentQuantity = quantity;' '== NSOrderedAscending) {
            statistics->_mostRecentQuantity = quantity;'
# A mutant of the cumulative sample of 13.0: the sum it carries, which is the one fact this class adds to
# its superclass. A sample that comes back from the store without it is a quantity sample that has lost
# everything that made it cumulative.
mutant HKCumulativeQuantitySample130.m 'return _sumQuantity;' 'return nil;'
# A mutant of the series sample of 12.0: its own sum, which is the one fact this class adds to its 13.0
# superclass. The kind is not used here - since the archive's root is decoded by the unarchiver, the kind
# does not decide what comes back - so a mutant on it would test nothing.
mutant HKCumulativeQuantitySeriesSample120.m 'return _sum;' 'return nil;'
# Two mutants of the twenty-one constants of 12.0. The clinical type identifiers hold their own names,
# which is the shape that is easiest to write from the name alone without ever reading the release, so
# one of them is a name that is one letter short - the value the port would have if the name had been
# copied rather than read, and the differential compares the port's own string against the host's own
# symbol of the same name, so it cannot pass.
mutant HKConstants120.m '= @"HKClinicalTypeIdentifierAllergyRecord";' '= @"HKClinicalTypeIdentifierAllergy";'
# And one of a constant whose value is not its name at all: HKMetadataKeyCrossTrainerDistance is
# `HKCrossTrainerDistance` in that release's image, and a value spelled as the constant's own name is
# what a reader who never opened the image would write.
mutant HKConstants120.m '= @"HKCrossTrainerDistance";' '= @"HKMetadataKeyCrossTrainerDistance";'
# Two of the measured group, one of each shape. HKMetadataKeyAverageSpeed holds `HKAverageSpeed`, so
# a value spelled from the constant's own name is what a reader who never read the binary would
# write; and HKCategoryTypeIdentifierAbdominalCramps holds its own name, so a value one letter
# short is what a transcription of the identifier would give. The differential compares the port's
# own string against the host's own symbol of the same name, so neither can pass.
mutant HKConstants120.m '= @"HKAverageSpeed";' '= @"HKMetadataKeyAverageSpeed";'
mutant HKConstants160.m '= @"HKCategoryTypeIdentifierAbdominalCramps";' '= @"HKCategoryTypeIdentifierAbdominalCramp";'
