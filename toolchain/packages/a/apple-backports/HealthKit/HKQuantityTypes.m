#import <Foundation/Foundation.h>

#import "RevenantHKTypes.h"
#import <HealthKit/HealthKit.h>

Class RevenantHKClassForTypeKind(NSInteger kind)
{
    switch (kind) {
    case RevenantHKTypeKindQuantity:
        return NSClassFromString(@"HKQuantityType");
    case RevenantHKTypeKindCategory:
        return NSClassFromString(@"HKCategoryType");
    case RevenantHKTypeKindCorrelation:
        return NSClassFromString(@"HKCorrelationType");
    case RevenantHKTypeKindCharacteristic:
        return NSClassFromString(@"HKCharacteristicType");
    case RevenantHKTypeKindWorkout:
        return NSClassFromString(@"HKWorkoutType");
    default:
        return Nil;
    }
}

static RevenantHKClassResolver revenant_hk_class_resolver = ^Class(NSString *name) {
    return NSClassFromString(name);
};

void RevenantHKSetClassResolver(RevenantHKClassResolver resolver)
{
    revenant_hk_class_resolver = resolver ?: ^Class(NSString *name) { return NSClassFromString(name); };
}

Class RevenantHKClassForObjectKind(NSInteger kind)
{
    RevenantHKClassResolver resolve = revenant_hk_class_resolver;
    switch (kind) {
    case 0:
        return resolve(@"HKCategorySample");
    case 1:
        return resolve(@"HKQuantitySample");
    case 2:
        return resolve(@"HKCorrelation");
    case 3:
        return resolve(@"HKWorkout");
    case 4:
        return resolve(@"HKClinicalRecord");
    case 5:
        return resolve(@"HKCumulativeQuantitySample");
    case 6:
        return resolve(@"HKCumulativeQuantitySeriesSample");
    default:
        return Nil;
    }
}

static const RevenantHKTypeEntry revenant_hk_quantity_types[] = {
    {@"HKQuantityTypeIdentifierActiveEnergyBurned", @"kcal", RevenantHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierAppleExerciseTime", @"min", RevenantHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierAppleMoveTime", @"min", RevenantHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierAppleSleepingBreathingDisturbances", @"count", RevenantHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierAppleSleepingWristTemperature", @"degC", RevenantHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierAppleStandTime", @"min", RevenantHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierAppleWalkingSteadiness", @"%", RevenantHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierAtrialFibrillationBurden", @"%", RevenantHKAggregationDiscreteTemporallyWeighted},
    {@"HKQuantityTypeIdentifierBasalBodyTemperature", @"degC", RevenantHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierBasalEnergyBurned", @"kcal", RevenantHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierBloodAlcoholContent", @"%", RevenantHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierBloodGlucose", @"mg/dL", RevenantHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierBloodPressureDiastolic", @"mmHg", RevenantHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierBloodPressureSystolic", @"mmHg", RevenantHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierBodyFatPercentage", @"%", RevenantHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierBodyMass", @"kg", RevenantHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierBodyMassIndex", @"count", RevenantHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierBodyTemperature", @"degC", RevenantHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierCrossCountrySkiingSpeed", @"m/s", RevenantHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierCyclingCadence", @"count/min", RevenantHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierCyclingFunctionalThresholdPower", @"W", RevenantHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierCyclingPower", @"W", RevenantHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierCyclingSpeed", @"m/s", RevenantHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierDietaryBiotin", @"g", RevenantHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDietaryCaffeine", @"g", RevenantHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDietaryCalcium", @"g", RevenantHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDietaryCarbohydrates", @"g", RevenantHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDietaryChloride", @"g", RevenantHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDietaryCholesterol", @"g", RevenantHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDietaryChromium", @"g", RevenantHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDietaryCopper", @"g", RevenantHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDietaryEnergyConsumed", @"kcal", RevenantHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDietaryFatMonounsaturated", @"g", RevenantHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDietaryFatPolyunsaturated", @"g", RevenantHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDietaryFatSaturated", @"g", RevenantHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDietaryFatTotal", @"g", RevenantHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDietaryFiber", @"g", RevenantHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDietaryFolate", @"g", RevenantHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDietaryIodine", @"g", RevenantHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDietaryIron", @"g", RevenantHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDietaryMagnesium", @"g", RevenantHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDietaryManganese", @"g", RevenantHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDietaryMolybdenum", @"g", RevenantHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDietaryNiacin", @"g", RevenantHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDietaryPantothenicAcid", @"g", RevenantHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDietaryPhosphorus", @"g", RevenantHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDietaryPotassium", @"g", RevenantHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDietaryProtein", @"g", RevenantHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDietaryRiboflavin", @"g", RevenantHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDietarySelenium", @"g", RevenantHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDietarySodium", @"g", RevenantHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDietarySugar", @"g", RevenantHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDietaryThiamin", @"g", RevenantHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDietaryVitaminA", @"g", RevenantHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDietaryVitaminB12", @"g", RevenantHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDietaryVitaminB6", @"g", RevenantHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDietaryVitaminC", @"g", RevenantHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDietaryVitaminD", @"g", RevenantHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDietaryVitaminE", @"g", RevenantHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDietaryVitaminK", @"g", RevenantHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDietaryWater", @"mL", RevenantHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDietaryZinc", @"g", RevenantHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDistanceCrossCountrySkiing", @"m", RevenantHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDistanceCycling", @"m", RevenantHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDistanceDownhillSnowSports", @"m", RevenantHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDistancePaddleSports", @"m", RevenantHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDistanceRowing", @"m", RevenantHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDistanceSkatingSports", @"m", RevenantHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDistanceSwimming", @"m", RevenantHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDistanceWalkingRunning", @"m", RevenantHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierDistanceWheelchair", @"m", RevenantHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierElectrodermalActivity", @"S", RevenantHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierEnvironmentalAudioExposure", @"dBASPL", RevenantHKAggregationDiscreteEquivalentContinuousLevel},
    {@"HKQuantityTypeIdentifierEnvironmentalSoundReduction", @"dBASPL", RevenantHKAggregationDiscreteEquivalentContinuousLevel},
    {@"HKQuantityTypeIdentifierEstimatedWorkoutEffortScore", @"appleEffortScore", RevenantHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierFlightsClimbed", @"count", RevenantHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierForcedExpiratoryVolume1", @"L", RevenantHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierForcedVitalCapacity", @"L", RevenantHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierHeadphoneAudioExposure", @"dBASPL", RevenantHKAggregationDiscreteEquivalentContinuousLevel},
    {@"HKQuantityTypeIdentifierHeartRate", @"count/s", RevenantHKAggregationDiscreteTemporallyWeighted},
    {@"HKQuantityTypeIdentifierHeartRateRecoveryOneMinute", @"count/min", RevenantHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierHeartRateVariabilitySDNN", @"ms", RevenantHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierHeight", @"m", RevenantHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierInhalerUsage", @"count", RevenantHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierInsulinDelivery", @"IU", RevenantHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierLeanBodyMass", @"kg", RevenantHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierNikeFuel", @"count", RevenantHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierNumberOfAlcoholicBeverages", @"count", RevenantHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierNumberOfTimesFallen", @"count", RevenantHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierOxygenSaturation", @"%", RevenantHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierPaddleSportsSpeed", @"m/s", RevenantHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierPeakExpiratoryFlowRate", @"L/min", RevenantHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierPeripheralPerfusionIndex", @"%", RevenantHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierPhysicalEffort", @"kcal/(kg*hr)", RevenantHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierPushCount", @"count", RevenantHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierRespiratoryRate", @"count/s", RevenantHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierRestingHeartRate", @"count/min", RevenantHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierRowingSpeed", @"m/s", RevenantHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierRunningGroundContactTime", @"ms", RevenantHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierRunningPower", @"W", RevenantHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierRunningSpeed", @"m/s", RevenantHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierRunningStrideLength", @"m", RevenantHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierRunningVerticalOscillation", @"cm", RevenantHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierSixMinuteWalkTestDistance", @"m", RevenantHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierStairAscentSpeed", @"m/s", RevenantHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierStairDescentSpeed", @"m/s", RevenantHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierStepCount", @"count", RevenantHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierSwimmingStrokeCount", @"count", RevenantHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierTimeInDaylight", @"min", RevenantHKAggregationCumulativeSum},
    {@"HKQuantityTypeIdentifierUVExposure", @"count", RevenantHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierUnderwaterDepth", @"m", RevenantHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierVO2Max", @"ml/(kg*min)", RevenantHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierWaistCircumference", @"m", RevenantHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierWalkingAsymmetryPercentage", @"%", RevenantHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierWalkingDoubleSupportPercentage", @"%", RevenantHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierWalkingHeartRateAverage", @"count/min", RevenantHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierWalkingSpeed", @"m/s", RevenantHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierWalkingStepLength", @"m", RevenantHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierWaterTemperature", @"degC", RevenantHKAggregationDiscreteArithmetic},
    {@"HKQuantityTypeIdentifierWorkoutEffortScore", @"appleEffortScore", RevenantHKAggregationDiscreteArithmetic},
};
static const NSUInteger revenant_hk_quantity_type_count = sizeof(revenant_hk_quantity_types) / sizeof(revenant_hk_quantity_types[0]);

NSUInteger RevenantHKQuantityTypeCount(void)
{
    return revenant_hk_quantity_type_count;
}

const RevenantHKTypeEntry *RevenantHKQuantityTypeEntryAt(NSUInteger index)
{
    return index < revenant_hk_quantity_type_count ? &revenant_hk_quantity_types[index] : NULL;
}

const RevenantHKTypeEntry *RevenantHKQuantityTypeEntry(NSString *identifier)
{
    if (![identifier isKindOfClass:[NSString class]])
        return NULL;
    for (NSUInteger index = 0; index < revenant_hk_quantity_type_count; index++)
        if ([revenant_hk_quantity_types[index].identifier isEqualToString:identifier])
            return &revenant_hk_quantity_types[index];
    return NULL;
}

BOOL RevenantHKHasTypeIdentifier(NSString *identifier, RevenantHKTypeKind kind)
{
    if (![identifier isKindOfClass:[NSString class]] || !identifier.length)
        return NO;
    switch (kind) {
    case RevenantHKTypeKindQuantity:
        return RevenantHKQuantityTypeEntry(identifier) != NULL;
    case RevenantHKTypeKindCategory:
        return [identifier hasPrefix:@"HKCategoryTypeIdentifier"];
    case RevenantHKTypeKindCharacteristic:
        return [identifier hasPrefix:@"HKCharacteristicTypeIdentifier"];
    case RevenantHKTypeKindCorrelation:
        return [identifier hasPrefix:@"HKCorrelationTypeIdentifier"];
    case RevenantHKTypeKindWorkout:
    default:
        return [identifier hasPrefix:@"HKWorkoutTypeIdentifier"];
    }
}
