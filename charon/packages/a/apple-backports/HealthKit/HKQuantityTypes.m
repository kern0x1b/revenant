// HKQuantityTypes.m: what each quantity type is counted in, and how its values are aggregated.
//
// The table is Apple's own, written in the SDK: every HKQuantityTypeIdentifier line of
// HKTypeIdentifiers.h carries a trailing comment naming the unit and the aggregation, as
// `// kg, Discrete (Arithmetic)` and `// kcal, Cumulative`. This file is that comment read for every
// identifier of the header of iPhoneOS26.2.sdk, the SDK the corpus of this series is measured against,
// and nothing is in it that the header does not say - with one exception, below, that the host's own
// HealthKit overrules.
//
// The exception: the comment of HKQuantityTypeIdentifierUVExposure names no unit at all - it is the
// only line of the header whose unit field is empty - and the host answers `count` and `%` for that
// type, which is a count and a fraction. So its row carries `count`, and the file below says so where it
// is read. Nothing else is corrected: every other unit and every aggregation here is the header's.
//
// The unit strings are the ones +[HKUnit unitFromString:] answers, and every one of them is held to the
// host's own answers by tests/backports/host/healthkit, which asks the system and this library the same
// questions in one process. The aggregations are the cases of HKQuantityAggregationStyle of the SDK the
// port compiles against, which has two of them: a cumulative type aggregates by summing and a discrete
// one arithmetically. The three the header's comment names beyond those two - Statistical, Most Recent,
// Equivalent Continuous Level, Temporally Weighted - are recorded in this table as themselves and
// collapsed to the one discrete style the contract has, which is the same answer for all of them and
// the only one a caller compiled against that SDK can be told. The host has the later enum and answers
// each of them with its own case; that is the one difference the host differential declares, and
// facts/HealthKit/HealthKit.md names the ten types it is.
//
// A type whose documented unit is one +[HKUnit unitFromString:] cannot make would keep the string and
// refuse a unit rather than guess one, once, in the log. After the correction above there is none: every
// unit the header names is one the host makes and this library makes.

#import <Foundation/Foundation.h>

#import "CharonHKTypes.h"
#import <HealthKit/HealthKit.h>

Class CharonHKClassForTypeKind(NSInteger kind)
{
    switch (kind) {
    case CharonHKTypeKindQuantity:
        return NSClassFromString(@"HKQuantityType");
    case CharonHKTypeKindCategory:
        return NSClassFromString(@"HKCategoryType");
    case CharonHKTypeKindCorrelation:
        return NSClassFromString(@"HKCorrelationType");
    case CharonHKTypeKindCharacteristic:
        return NSClassFromString(@"HKCharacteristicType");
    case CharonHKTypeKindWorkout:
        return NSClassFromString(@"HKWorkoutType");
    default:
        return Nil;
    }
}

// The lookup the kind table uses, and the one that replaces it. A nil resolver is the runtime's own.
static CharonHKClassResolver charon_hk_class_resolver = ^Class(NSString *name) {
    return NSClassFromString(name);
};

void CharonHKSetClassResolver(CharonHKClassResolver resolver)
{
    charon_hk_class_resolver = resolver ?: ^Class(NSString *name) { return NSClassFromString(name); };
}

Class CharonHKClassForObjectKind(NSInteger kind)
{
    CharonHKClassResolver resolve = charon_hk_class_resolver;
    switch (kind) {
    case 0:
        return resolve(@"HKCategorySample");
    case 1:
        return resolve(@"HKQuantitySample");
    case 2:
        return resolve(@"HKCorrelation");
    case 3:
        return resolve(@"HKWorkout");
    // The clinical record of 12.0, whose kind the store writes and which the table could not name, so a
    // record could be saved and never read back.
    case 4:
        return resolve(@"HKClinicalRecord");
    // The cumulative quantity sample of 13.0, which is a quantity sample and not one, so it has a kind
    // of its own rather than its superclass's.
    case 5:
        return resolve(@"HKCumulativeQuantitySample");
    // The cumulative sample of a series, of 12.0, beside its 13.0 superclass.
    case 6:
        return resolve(@"HKCumulativeQuantitySeriesSample");
    default:
        return Nil;
    }
}

static const CharonHKTypeEntry charon_hk_quantity_types[] = {
    {@"HKQuantityTypeIdentifierActiveEnergyBurned", @"kcal", CharonHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierAppleExerciseTime", @"min", CharonHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierAppleMoveTime", @"min", CharonHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierAppleSleepingBreathingDisturbances", @"count", CharonHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierAppleSleepingWristTemperature", @"degC", CharonHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierAppleStandTime", @"min", CharonHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierAppleWalkingSteadiness", @"%", CharonHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierAtrialFibrillationBurden", @"%", CharonHKAggregationDiscreteTemporallyWeighted},
    {@"HKQuantityTypeIdentifierBasalBodyTemperature", @"degC", CharonHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierBasalEnergyBurned", @"kcal", CharonHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierBloodAlcoholContent", @"%", CharonHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierBloodGlucose", @"mg/dL", CharonHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierBloodPressureDiastolic", @"mmHg", CharonHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierBloodPressureSystolic", @"mmHg", CharonHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierBodyFatPercentage", @"%", CharonHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierBodyMass", @"kg", CharonHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierBodyMassIndex", @"count", CharonHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierBodyTemperature", @"degC", CharonHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierCrossCountrySkiingSpeed", @"m/s", CharonHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierCyclingCadence", @"count/min", CharonHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierCyclingFunctionalThresholdPower", @"W", CharonHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierCyclingPower", @"W", CharonHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierCyclingSpeed", @"m/s", CharonHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierDietaryBiotin", @"g", CharonHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDietaryCaffeine", @"g", CharonHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDietaryCalcium", @"g", CharonHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDietaryCarbohydrates", @"g", CharonHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDietaryChloride", @"g", CharonHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDietaryCholesterol", @"g", CharonHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDietaryChromium", @"g", CharonHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDietaryCopper", @"g", CharonHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDietaryEnergyConsumed", @"kcal", CharonHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDietaryFatMonounsaturated", @"g", CharonHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDietaryFatPolyunsaturated", @"g", CharonHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDietaryFatSaturated", @"g", CharonHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDietaryFatTotal", @"g", CharonHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDietaryFiber", @"g", CharonHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDietaryFolate", @"g", CharonHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDietaryIodine", @"g", CharonHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDietaryIron", @"g", CharonHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDietaryMagnesium", @"g", CharonHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDietaryManganese", @"g", CharonHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDietaryMolybdenum", @"g", CharonHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDietaryNiacin", @"g", CharonHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDietaryPantothenicAcid", @"g", CharonHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDietaryPhosphorus", @"g", CharonHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDietaryPotassium", @"g", CharonHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDietaryProtein", @"g", CharonHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDietaryRiboflavin", @"g", CharonHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDietarySelenium", @"g", CharonHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDietarySodium", @"g", CharonHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDietarySugar", @"g", CharonHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDietaryThiamin", @"g", CharonHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDietaryVitaminA", @"g", CharonHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDietaryVitaminB12", @"g", CharonHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDietaryVitaminB6", @"g", CharonHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDietaryVitaminC", @"g", CharonHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDietaryVitaminD", @"g", CharonHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDietaryVitaminE", @"g", CharonHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDietaryVitaminK", @"g", CharonHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDietaryWater", @"mL", CharonHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDietaryZinc", @"g", CharonHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDistanceCrossCountrySkiing", @"m", CharonHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDistanceCycling", @"m", CharonHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDistanceDownhillSnowSports", @"m", CharonHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDistancePaddleSports", @"m", CharonHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDistanceRowing", @"m", CharonHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDistanceSkatingSports", @"m", CharonHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDistanceSwimming", @"m", CharonHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDistanceWalkingRunning", @"m", CharonHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDistanceWheelchair", @"m", CharonHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierElectrodermalActivity", @"S", CharonHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierEnvironmentalAudioExposure", @"dBASPL", CharonHKAggregationDiscreteEquivalentContinuousLevel},
    {@"HKQuantityTypeIdentifierEnvironmentalSoundReduction", @"dBASPL", CharonHKAggregationDiscreteEquivalentContinuousLevel},
    {@"HKQuantityTypeIdentifierEstimatedWorkoutEffortScore", @"appleEffortScore", CharonHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierFlightsClimbed", @"count", CharonHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierForcedExpiratoryVolume1", @"L", CharonHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierForcedVitalCapacity", @"L", CharonHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierHeadphoneAudioExposure", @"dBASPL", CharonHKAggregationDiscreteEquivalentContinuousLevel},
    {@"HKQuantityTypeIdentifierHeartRate", @"count/s", CharonHKAggregationDiscreteTemporallyWeighted},
    {@"HKQuantityTypeIdentifierHeartRateRecoveryOneMinute", @"count/min", CharonHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierHeartRateVariabilitySDNN", @"ms", CharonHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierHeight", @"m", CharonHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierInhalerUsage", @"count", CharonHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierInsulinDelivery", @"IU", CharonHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierLeanBodyMass", @"kg", CharonHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierNikeFuel", @"count", CharonHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierNumberOfAlcoholicBeverages", @"count", CharonHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierNumberOfTimesFallen", @"count", CharonHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierOxygenSaturation", @"%", CharonHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierPaddleSportsSpeed", @"m/s", CharonHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierPeakExpiratoryFlowRate", @"L/min", CharonHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierPeripheralPerfusionIndex", @"%", CharonHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierPhysicalEffort", @"kcal/(kg*hr)", CharonHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierPushCount", @"count", CharonHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierRespiratoryRate", @"count/s", CharonHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierRestingHeartRate", @"count/min", CharonHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierRowingSpeed", @"m/s", CharonHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierRunningGroundContactTime", @"ms", CharonHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierRunningPower", @"W", CharonHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierRunningSpeed", @"m/s", CharonHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierRunningStrideLength", @"m", CharonHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierRunningVerticalOscillation", @"cm", CharonHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierSixMinuteWalkTestDistance", @"m", CharonHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierStairAscentSpeed", @"m/s", CharonHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierStairDescentSpeed", @"m/s", CharonHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierStepCount", @"count", CharonHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierSwimmingStrokeCount", @"count", CharonHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierTimeInDaylight", @"min", CharonHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierUVExposure", @"count", CharonHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierUnderwaterDepth", @"m", CharonHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierVO2Max", @"ml/(kg*min)", CharonHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierWaistCircumference", @"m", CharonHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierWalkingAsymmetryPercentage", @"%", CharonHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierWalkingDoubleSupportPercentage", @"%", CharonHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierWalkingHeartRateAverage", @"count/min", CharonHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierWalkingSpeed", @"m/s", CharonHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierWalkingStepLength", @"m", CharonHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierWaterTemperature", @"degC", CharonHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierWorkoutEffortScore", @"appleEffortScore", CharonHKAggregationDiscreteArithmetic},
};
static const NSUInteger charon_hk_quantity_type_count = sizeof(charon_hk_quantity_types) / sizeof(charon_hk_quantity_types[0]);

NSUInteger CharonHKQuantityTypeCount(void)
{
    return charon_hk_quantity_type_count;
}

const CharonHKTypeEntry *CharonHKQuantityTypeEntryAt(NSUInteger index)
{
    return index < charon_hk_quantity_type_count ? &charon_hk_quantity_types[index] : NULL;
}

const CharonHKTypeEntry *CharonHKQuantityTypeEntry(NSString *identifier)
{
    if (![identifier isKindOfClass:[NSString class]])
        return NULL;
    for (NSUInteger index = 0; index < charon_hk_quantity_type_count; index++)
        if ([charon_hk_quantity_types[index].identifier isEqualToString:identifier])
            return &charon_hk_quantity_types[index];
    return NULL;
}

BOOL CharonHKHasTypeIdentifier(NSString *identifier, CharonHKTypeKind kind)
{
    if (![identifier isKindOfClass:[NSString class]] || !identifier.length)
        return NO;
    switch (kind) {
    case CharonHKTypeKindQuantity:
        return CharonHKQuantityTypeEntry(identifier) != NULL;
    case CharonHKTypeKindCategory:
        return [identifier hasPrefix:@"HKCategoryTypeIdentifier"];
    case CharonHKTypeKindCharacteristic:
        return [identifier hasPrefix:@"HKCharacteristicTypeIdentifier"];
    case CharonHKTypeKindCorrelation:
        return [identifier hasPrefix:@"HKCorrelationTypeIdentifier"];
    case CharonHKTypeKindWorkout:
    default:
        return [identifier hasPrefix:@"HKWorkoutTypeIdentifier"];
    }
}
