#import <Foundation/Foundation.h>
#import <HealthKit/HealthKit.h>

extern Class _Nullable RevenantHKClassForObjectKind(NSInteger kind);
extern void RevenantHKSetClassResolver(Class _Nullable (^resolver)(NSString *name));

#import <objc/runtime.h>

#import "RevenantHKTypes.h"

@interface HKQuery (HKRevenant93)
@property (readonly, strong, nullable) HKObjectType *objectType;
@property (readonly, strong, nullable) NSPredicate *predicate;
@end

@interface HKSampleQuery (HKRevenant93)
@property (readonly) NSUInteger limit;
@property (readonly, copy, nullable) NSArray<NSSortDescriptor *> *sortDescriptors;
@property (readonly) BOOL hasBeenExecuted;
@property (readonly, copy) NSUUID *activationUUID;
@end

@interface HKStatisticsCollectionQuery (HKRevenant93)
@property (readonly, strong) NSDate *anchorDate;
@property (readonly) HKStatisticsOptions options;
@property (readonly, copy) NSDateComponents *intervalComponents;
@end

@interface RevenantHostHKQuery : NSObject
+ (NSPredicate *)predicateForClinicalRecordsWithFHIRResourceType:(NSString *)resourceType;
+ (nullable NSPredicate *)predicateForClinicalRecordsFromSource:(nullable HKSource *)source
                                                FHIRResourceType:(nullable NSString *)resourceType
                                                     identifier:(nullable NSString *)identifier;
+ (NSString *)revenant_predicateOperatorSpellingFor:(long)type;
@end

@interface RevenantHostHKStatisticsCollectionQuery : NSObject
- (instancetype)initWithQuantityType:(HKQuantityType *)quantityType
                quantitySamplePredicate:(nullable NSPredicate *)quantitySamplePredicate
                             options:(HKStatisticsOptions)options
                          anchorDate:(NSDate *)anchorDate
                  intervalComponents:(NSDateComponents *)intervalComponents;
@property (readonly) NSDate *anchorDate;
@property (readonly) HKStatisticsOptions options;
@property (readonly, copy) NSDateComponents *intervalComponents;
@property (readonly) HKObjectType *objectType;
@property (readonly) NSPredicate *predicate;
@end

@interface RevenantHostHKSampleType : NSObject
@end

@class RevenantHostHKQuantityType;

@interface RevenantHostHKSampleQuery : NSObject
- (instancetype)initWithSampleType:(HKSampleType *)sampleType
                         predicate:(nullable NSPredicate *)predicate
                             limit:(NSUInteger)limit
                  sortDescriptors:(nullable NSArray<NSSortDescriptor *> *)sortDescriptors
                   resultsHandler:(void (^)(RevenantHostHKSampleQuery *query, NSArray *results, NSError *error))resultsHandler;
@property (readonly) HKSampleType *sampleType;
@property (readonly) HKObjectType *objectType;
@property (readonly) NSUInteger limit;
@property (readonly, copy) NSArray<NSSortDescriptor *> *sortDescriptors;
@property (readonly) NSPredicate *predicate;
@end

@interface RevenantHostHKStatisticsQuery : NSObject
- (instancetype)initWithQuantityType:(HKQuantityType *)quantityType
                quantitySamplePredicate:(nullable NSPredicate *)quantitySamplePredicate
                             options:(HKStatisticsOptions)options
                    completionHandler:(void (^)(id result, NSError *error))completionHandler;
@property (readonly) HKQuantityType *objectType;
@property (readonly) NSPredicate *predicate;
@property (readonly) BOOL hasBeenExecuted;
@end

@interface RevenantHostHKSourceQuery : NSObject
- (instancetype)initWithSampleType:(nullable HKSampleType *)sampleType
                    samplePredicate:(nullable NSPredicate *)predicate
                  completionHandler:(void (^)(NSArray<HKSource *> *sources, NSError *error))completionHandler;
@property (readonly) HKObjectType *objectType;
@property (readonly) NSPredicate *predicate;
@end

@interface RevenantHostHKSeriesType : NSObject
+ (instancetype)workoutRouteType;
@property (readonly, copy) NSString *identifier;
@end

@class RevenantHostHKSeriesType;
@class RevenantHostHKClinicalType;

@interface RevenantHostHKObjectType : NSObject
+ (nullable HKQuantityType *)quantityTypeForIdentifier:(NSString *)identifier;
+ (nullable HKWorkoutType *)workoutType;
+ (nullable RevenantHostHKSeriesType *)seriesTypeForIdentifier:(NSString *)identifier;
+ (nullable RevenantHostHKClinicalType *)clinicalTypeForIdentifier:(NSString *)identifier;
@end

@interface RevenantHostHKClinicalType : NSObject
@property (readonly, copy) NSString *identifier;
@end

@interface RevenantHostHKFHIRResource : NSObject
+ (instancetype)revenant_resourceWithType:(NSString *)resourceType
                             identifier:(NSString *)identifier
                                   data:(NSData *)data
                              sourceURL:(nullable NSURL *)sourceURL;
@property (readonly, copy) NSString *resourceType;
@property (readonly, copy) NSString *identifier;
@property (readonly, copy) NSData *data;
@property (readonly, copy, nullable) NSURL *sourceURL;
- (id)copy;
@end

@interface RevenantHostHKSource : NSObject
+ (instancetype)defaultSource;
@property (readonly, copy) NSString *bundleIdentifier;
@end

@interface RevenantHostHKSourceRevision : NSObject
- (instancetype)initWithSource:(HKSource *)source
                       version:(nullable NSString *)version
                   productType:(nullable NSString *)productType
          operatingSystemVersion:(NSOperatingSystemVersion)operatingSystemVersion;
@property (readonly, copy) HKSource *source;
@property (readonly, copy) NSString *version;
@property (readonly, copy) NSString *productType;
@property (readonly) NSOperatingSystemVersion operatingSystemVersion;
@end

@interface RevenantHostHKWorkoutEvent : NSObject
+ (instancetype)workoutEventWithType:(long)type
                                 date:(NSDate *)date;
+ (instancetype)workoutEventWithType:(long)type
                       dateInterval:(nullable NSDateInterval *)dateInterval
                            metadata:(nullable NSDictionary *)metadata;
@property (readonly) long type;
@property (readonly, copy) NSDate *date;
@property (readonly, copy) NSDateInterval *dateInterval;
@property (readonly, copy) NSDictionary *metadata;
@end

@interface RevenantHostHKWorkoutType : NSObject
@property (readonly, copy) NSString *identifier;
@end

@interface RevenantHostHKWorkout : NSObject
@property (readonly, copy) NSUUID *UUID;
+ (instancetype)workoutWithActivityType:(long)activityType
                              startDate:(NSDate *)startDate
                                endDate:(NSDate *)endDate
                         workoutEvents:(NSArray *)workoutEvents
                    totalEnergyBurned:(nullable HKQuantity *)totalEnergyBurned
                      totalDistance:(nullable HKQuantity *)totalDistance
                 totalFlightsClimbed:(nullable HKQuantity *)totalFlightsClimbed
                                device:(nullable id)device
                              metadata:(nullable NSDictionary *)metadata;
@property (readonly) long workoutActivityType;
@property (readonly, copy) NSDate *startDate;
@property (readonly, copy) NSDate *endDate;
@property (readonly) NSTimeInterval duration;
@property (readonly, copy) NSArray *workoutEvents;
@property (readonly, copy, nullable) HKQuantity *totalEnergyBurned;
@property (readonly, copy, nullable) HKQuantity *totalDistance;
@property (readonly, copy, nullable) HKQuantity *totalFlightsClimbed;
@end

@interface RevenantHostHKUnit : NSObject
+ (instancetype)unitFromString:(NSString *)string;
+ (instancetype)internationalUnit;
+ (instancetype)smallCalorieUnit;
+ (instancetype)largeCalorieUnit;
+ (instancetype)countUnit;
+ (instancetype)jouleUnit;
+ (instancetype)kilocalorieUnit;
+ (instancetype)meterUnit;
@property (readonly, copy) NSString *unitString;
- (BOOL)isNull;
- (HKUnit *)unitMultipliedByUnit:(HKUnit *)unit;
- (HKUnit *)unitDividedByUnit:(HKUnit *)unit;
- (HKUnit *)unitRaisedToPower:(NSInteger)power;
- (HKUnit *)reciprocalUnit;
+ (instancetype)gramUnit;
+ (instancetype)gramUnitWithMetricPrefix:(HKMetricPrefix)prefix;
+ (instancetype)meterUnit;
+ (instancetype)meterUnitWithMetricPrefix:(HKMetricPrefix)prefix;
+ (instancetype)literUnit;
+ (instancetype)literUnitWithMetricPrefix:(HKMetricPrefix)prefix;
+ (instancetype)pascalUnit;
+ (instancetype)pascalUnitWithMetricPrefix:(HKMetricPrefix)prefix;
+ (instancetype)secondUnit;
+ (instancetype)secondUnitWithMetricPrefix:(HKMetricPrefix)prefix;
+ (instancetype)jouleUnit;
+ (instancetype)jouleUnitWithMetricPrefix:(HKMetricPrefix)prefix;
+ (instancetype)siemenUnit;
+ (instancetype)siemenUnitWithMetricPrefix:(HKMetricPrefix)prefix;
+ (instancetype)hertzUnit;
+ (instancetype)hertzUnitWithMetricPrefix:(HKMetricPrefix)prefix;
+ (instancetype)voltUnit;
+ (instancetype)voltUnitWithMetricPrefix:(HKMetricPrefix)prefix;
+ (instancetype)wattUnit;
+ (instancetype)wattUnitWithMetricPrefix:(HKMetricPrefix)prefix;
+ (instancetype)degreeCelsiusUnit;
- (BOOL)revenant_isCompatibleWithUnit:(RevenantHostHKUnit *)unit;
@end

@interface RevenantHostHKQuantity : NSObject
+ (instancetype)quantityWithUnit:(RevenantHostHKUnit *)unit doubleValue:(double)value;
@property (readonly, copy) RevenantHostHKUnit *unit;
- (BOOL)isCompatibleWithUnit:(RevenantHostHKUnit *)unit;
- (double)doubleValueForUnit:(RevenantHostHKUnit *)unit;
- (NSComparisonResult)compare:(RevenantHostHKQuantity *)quantity;
@end

@interface RevenantHostHKQuantityType : RevenantHostHKObjectType
@property (readonly, copy) NSString *identifier;
@property (readonly) NSInteger aggregationStyle;
- (BOOL)isCompatibleWithUnit:(RevenantHostHKUnit *)unit;
@end

static const char *RevenantHKDescribe(id object)
{
    NSString *text = [object description];
    return text ? (const char *)[text UTF8String] : "(null)";
}

static NSUInteger RevenantHKDifferences;
static NSUInteger RevenantHKComparisons;

static void RevenantHKCompare(NSString *what, id mine, id theirs)
{
    RevenantHKComparisons++;
    BOOL same = mine == nil ? theirs == nil : [mine isEqual:theirs];
    if (!same) {
        RevenantHKDifferences++;
        printf("DIFFERS  %-56s port %-26s host %s\n", what.UTF8String,
               [[mine description] UTF8String], [[theirs description] UTF8String]);
    }
}

static void RevenantHKCompareBool(NSString *what, BOOL mine, BOOL theirs)
{
    RevenantHKCompare(what, @(mine), @(theirs));
}

static void RevenantHKCompareInt(NSString *what, NSInteger mine, NSInteger theirs)
{
    RevenantHKCompare(what, @(mine), @(theirs));
}

static void RevenantHKCompareFactors(NSString *what, id mineUnit, id theirsUnit)
{
    RevenantHKComparisons++;
    NSString *mine = [mineUnit unitString], *theirs = [theirsUnit unitString];
    NSCharacterSet *separators = [NSCharacterSet characterSetWithCharactersInString:@"/*·^0123456789"];
    NSMutableSet *mineSet = [NSMutableSet set], *theirsSet = [NSMutableSet set];
    for (NSString *part in [mine componentsSeparatedByCharactersInSet:separators]) {
        NSString *bare = [part stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (bare.length)
            [mineSet addObject:bare];
    }
    for (NSString *part in [theirs componentsSeparatedByCharactersInSet:separators]) {
        NSString *bare = [part stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (bare.length)
            [theirsSet addObject:bare];
    }
    if (![mineSet isEqualToSet:theirsSet]) {
        RevenantHKDifferences++;
        printf("DIFFERS  %-56s port %-26s host %s\n", what.UTF8String, mine.UTF8String, theirs.UTF8String);
    }
}

static void RevenantHKCompareDouble(NSString *what, double mine, double theirs)
{
    RevenantHKComparisons++;
    double scale = MAX(1.0, MAX(fabs(mine), fabs(theirs)));
    if (fabs(mine - theirs) > 1e-9 * scale) {
        RevenantHKDifferences++;
        printf("DIFFERS  %-56s port %.12g  host %.12g\n", what.UTF8String, mine, theirs);
    }
}

static const double RevenantHKProbe = 1.0 + 1.0 / 3.0;
static const double RevenantHKSecondProbe = 21.5;

extern NSString *const RevenantHK120_HKFHIRResourceTypeAllergyIntolerance;
extern NSString *const RevenantHK120_HKFHIRResourceTypeCondition;
extern NSString *const RevenantHK120_HKFHIRResourceTypeImmunization;
extern NSString *const RevenantHK120_HKFHIRResourceTypeMedicationDispense;
extern NSString *const RevenantHK120_HKFHIRResourceTypeMedicationOrder;
extern NSString *const RevenantHK120_HKFHIRResourceTypeMedicationStatement;
extern NSString *const RevenantHK120_HKFHIRResourceTypeObservation;
extern NSString *const RevenantHK120_HKFHIRResourceTypeProcedure;
extern NSString *const RevenantHK120_HKClinicalTypeIdentifierAllergyRecord;
extern NSString *const RevenantHK120_HKClinicalTypeIdentifierConditionRecord;
extern NSString *const RevenantHK120_HKClinicalTypeIdentifierImmunizationRecord;
extern NSString *const RevenantHK120_HKClinicalTypeIdentifierLabResultRecord;
extern NSString *const RevenantHK120_HKClinicalTypeIdentifierMedicationRecord;
extern NSString *const RevenantHK120_HKClinicalTypeIdentifierProcedureRecord;
extern NSString *const RevenantHK120_HKClinicalTypeIdentifierVitalSignRecord;
extern NSString *const RevenantHK120_HKMetadataKeyCrossTrainerDistance;
extern NSString *const RevenantHK120_HKMetadataKeyFitnessMachineDuration;
extern NSString *const RevenantHK120_HKMetadataKeyIndoorBikeDistance;
extern NSString *const RevenantHK120_HKPredicateKeyPathClinicalRecordFHIRResourceIdentifier;
extern NSString *const RevenantHK120_HKPredicateKeyPathClinicalRecordFHIRResourceType;
extern NSString *const RevenantHK120_HKPredicateKeyPathSum;

#import <dlfcn.h>

extern NSString *const RevenantHK120_HKMetadataKeyAlpineSlopeGrade;
extern NSString *const RevenantHK120_HKMetadataKeyAverageSpeed;
extern NSString *const RevenantHK120_HKMetadataKeyElevationAscended;
extern NSString *const RevenantHK120_HKMetadataKeyElevationDescended;
extern NSString *const RevenantHK120_HKMetadataKeyMaximumSpeed;
extern NSString *const RevenantHK120_HKQuantityTypeIdentifierDistanceDownhillSnowSports;
extern NSString *const RevenantHKMeasured_HKCategoryTypeIdentifierAbdominalCramps;
extern NSString *const RevenantHKMeasured_HKCategoryTypeIdentifierAcne;
extern NSString *const RevenantHKMeasured_HKCategoryTypeIdentifierAppetiteChanges;
extern NSString *const RevenantHKMeasured_HKCategoryTypeIdentifierAppleWalkingSteadinessEvent;
extern NSString *const RevenantHKMeasured_HKCategoryTypeIdentifierAudioExposureEvent;
extern NSString *const RevenantHKMeasured_HKCategoryTypeIdentifierBladderIncontinence;
extern NSString *const RevenantHKMeasured_HKCategoryTypeIdentifierBloating;
extern NSString *const RevenantHKMeasured_HKCategoryTypeIdentifierBreastPain;
extern NSString *const RevenantHKMeasured_HKCategoryTypeIdentifierChestTightnessOrPain;
extern NSString *const RevenantHKMeasured_HKCategoryTypeIdentifierChills;
extern NSString *const RevenantHKMeasured_HKCategoryTypeIdentifierConstipation;
extern NSString *const RevenantHKMeasured_HKCategoryTypeIdentifierContraceptive;
extern NSString *const RevenantHKMeasured_HKCategoryTypeIdentifierCoughing;
extern NSString *const RevenantHKMeasured_HKCategoryTypeIdentifierDiarrhea;
extern NSString *const RevenantHKMeasured_HKCategoryTypeIdentifierDizziness;
extern NSString *const RevenantHKMeasured_HKCategoryTypeIdentifierDrySkin;
extern NSString *const RevenantHKMeasured_HKCategoryTypeIdentifierEnvironmentalAudioExposureEvent;
extern NSString *const RevenantHKMeasured_HKCategoryTypeIdentifierFainting;
extern NSString *const RevenantHKMeasured_HKCategoryTypeIdentifierFatigue;
extern NSString *const RevenantHKMeasured_HKCategoryTypeIdentifierFever;
extern NSString *const RevenantHKMeasured_HKCategoryTypeIdentifierGeneralizedBodyAche;
extern NSString *const RevenantHKMeasured_HKCategoryTypeIdentifierHairLoss;
extern NSString *const RevenantHKMeasured_HKCategoryTypeIdentifierHandwashingEvent;
extern NSString *const RevenantHKMeasured_HKCategoryTypeIdentifierHeadache;
extern NSString *const RevenantHKMeasured_HKCategoryTypeIdentifierHeadphoneAudioExposureEvent;
extern NSString *const RevenantHKMeasured_HKCategoryTypeIdentifierHeartburn;
extern NSString *const RevenantHKMeasured_HKCategoryTypeIdentifierHighHeartRateEvent;
extern NSString *const RevenantHKMeasured_HKCategoryTypeIdentifierHotFlashes;
extern NSString *const RevenantHKMeasured_HKCategoryTypeIdentifierInfrequentMenstrualCycles;
extern NSString *const RevenantHKMeasured_HKCategoryTypeIdentifierIrregularHeartRhythmEvent;
extern NSString *const RevenantHKMeasured_HKCategoryTypeIdentifierIrregularMenstrualCycles;
extern NSString *const RevenantHKMeasured_HKCategoryTypeIdentifierLactation;
extern NSString *const RevenantHKMeasured_HKCategoryTypeIdentifierLossOfSmell;
extern NSString *const RevenantHKMeasured_HKCategoryTypeIdentifierLossOfTaste;
extern NSString *const RevenantHKMeasured_HKCategoryTypeIdentifierLowCardioFitnessEvent;
extern NSString *const RevenantHKMeasured_HKCategoryTypeIdentifierLowHeartRateEvent;
extern NSString *const RevenantHKMeasured_HKCategoryTypeIdentifierLowerBackPain;
extern NSString *const RevenantHKMeasured_HKCategoryTypeIdentifierMemoryLapse;
extern NSString *const RevenantHKMeasured_HKCategoryTypeIdentifierMoodChanges;
extern NSString *const RevenantHKMeasured_HKCategoryTypeIdentifierNausea;
extern NSString *const RevenantHKMeasured_HKCategoryTypeIdentifierNightSweats;
extern NSString *const RevenantHKMeasured_HKCategoryTypeIdentifierPelvicPain;
extern NSString *const RevenantHKMeasured_HKCategoryTypeIdentifierPersistentIntermenstrualBleeding;
extern NSString *const RevenantHKMeasured_HKCategoryTypeIdentifierPregnancy;
extern NSString *const RevenantHKMeasured_HKCategoryTypeIdentifierPregnancyTestResult;
extern NSString *const RevenantHKMeasured_HKCategoryTypeIdentifierProgesteroneTestResult;
extern NSString *const RevenantHKMeasured_HKCategoryTypeIdentifierProlongedMenstrualPeriods;
extern NSString *const RevenantHKMeasured_HKCategoryTypeIdentifierRapidPoundingOrFlutteringHeartbeat;
extern NSString *const RevenantHKMeasured_HKCategoryTypeIdentifierRunnyNose;
extern NSString *const RevenantHKMeasured_HKCategoryTypeIdentifierShortnessOfBreath;
extern NSString *const RevenantHKMeasured_HKCategoryTypeIdentifierSinusCongestion;
extern NSString *const RevenantHKMeasured_HKCategoryTypeIdentifierSkippedHeartbeat;
extern NSString *const RevenantHKMeasured_HKCategoryTypeIdentifierSleepChanges;
extern NSString *const RevenantHKMeasured_HKCategoryTypeIdentifierSoreThroat;
extern NSString *const RevenantHKMeasured_HKCategoryTypeIdentifierToothbrushingEvent;
extern NSString *const RevenantHKMeasured_HKCategoryTypeIdentifierVaginalDryness;
extern NSString *const RevenantHKMeasured_HKCategoryTypeIdentifierVomiting;
extern NSString *const RevenantHKMeasured_HKCategoryTypeIdentifierWheezing;
extern NSString *const RevenantHKMeasured_HKCharacteristicTypeIdentifierActivityMoveMode;
extern NSString *const RevenantHKMeasured_HKClinicalTypeIdentifierCoverageRecord;
extern NSString *const RevenantHKMeasured_HKDataTypeIdentifierHeartbeatSeries;
extern NSString *const RevenantHKMeasured_HKFHIRReleaseDSTU2;
extern NSString *const RevenantHKMeasured_HKFHIRReleaseR4;
extern NSString *const RevenantHKMeasured_HKFHIRReleaseUnknown;
extern NSString *const RevenantHKMeasured_HKFHIRResourceTypeCoverage;
extern NSString *const RevenantHKMeasured_HKFHIRResourceTypeMedicationRequest;
extern NSString *const RevenantHKMeasured_HKMedicationDoseEventTypeIdentifierMedicationDoseEvent;
extern NSString *const RevenantHKMeasured_HKMetadataKeyAlgorithmVersion;
extern NSString *const RevenantHKMeasured_HKMetadataKeyAppleDeviceCalibrated;
extern NSString *const RevenantHKMeasured_HKMetadataKeyAppleECGAlgorithmVersion;
extern NSString *const RevenantHKMeasured_HKMetadataKeyAudioExposureDuration;
extern NSString *const RevenantHKMeasured_HKMetadataKeyAudioExposureLevel;
extern NSString *const RevenantHKMeasured_HKMetadataKeyAverageMETs;
extern NSString *const RevenantHKMeasured_HKMetadataKeyBarometricPressure;
extern NSString *const RevenantHKMeasured_HKMetadataKeyDateOfEarliestDataUsedForEstimate;
extern NSString *const RevenantHKMeasured_HKMetadataKeyDevicePlacementSide;
extern NSString *const RevenantHKMeasured_HKMetadataKeyGlassesPrescriptionDescription;
extern NSString *const RevenantHKMeasured_HKMetadataKeyHeartRateEventThreshold;
extern NSString *const RevenantHKMeasured_HKMetadataKeyHeartRateRecoveryActivityDuration;
extern NSString *const RevenantHKMeasured_HKMetadataKeyHeartRateRecoveryActivityType;
extern NSString *const RevenantHKMeasured_HKMetadataKeyHeartRateRecoveryMaxObservedRecoveryHeartRate;
extern NSString *const RevenantHKMeasured_HKMetadataKeyHeartRateRecoveryTestType;
extern NSString *const RevenantHKMeasured_HKMetadataKeyLowCardioFitnessEventThreshold;
extern NSString *const RevenantHKMeasured_HKMetadataKeyQuantityClampedToLowerBound;
extern NSString *const RevenantHKMeasured_HKMetadataKeyQuantityClampedToUpperBound;
extern NSString *const RevenantHKMeasured_HKMetadataKeySWOLFScore;
extern NSString *const RevenantHKMeasured_HKMetadataKeySessionEstimate;
extern NSString *const RevenantHKMeasured_HKMetadataKeyUserMotionContext;
extern NSString *const RevenantHKMeasured_HKMetadataKeyVO2MaxValue;
extern NSString *const RevenantHKMeasured_HKPredicateKeyPathAverage;
extern NSString *const RevenantHKMeasured_HKPredicateKeyPathAverageHeartRate;
extern NSString *const RevenantHKMeasured_HKPredicateKeyPathCount;
extern NSString *const RevenantHKMeasured_HKPredicateKeyPathECGClassification;
extern NSString *const RevenantHKMeasured_HKPredicateKeyPathECGSymptomsStatus;
extern NSString *const RevenantHKMeasured_HKPredicateKeyPathMax;
extern NSString *const RevenantHKMeasured_HKPredicateKeyPathMin;
extern NSString *const RevenantHKMeasured_HKPredicateKeyPathMostRecent;
extern NSString *const RevenantHKMeasured_HKPredicateKeyPathMostRecentDuration;
extern NSString *const RevenantHKMeasured_HKPredicateKeyPathMostRecentEndDate;
extern NSString *const RevenantHKMeasured_HKPredicateKeyPathMostRecentStartDate;
extern NSString *const RevenantHKMeasured_HKPredicateKeyPathStatus;
extern NSString *const RevenantHKMeasured_HKPredicateKeyPathWorkoutActivity;
extern NSString *const RevenantHKMeasured_HKPredicateKeyPathWorkoutActivityAverageQuantity;
extern NSString *const RevenantHKMeasured_HKPredicateKeyPathWorkoutActivityDuration;
extern NSString *const RevenantHKMeasured_HKPredicateKeyPathWorkoutActivityEndDate;
extern NSString *const RevenantHKMeasured_HKPredicateKeyPathWorkoutActivityMaximumQuantity;
extern NSString *const RevenantHKMeasured_HKPredicateKeyPathWorkoutActivityMinimumQuantity;
extern NSString *const RevenantHKMeasured_HKPredicateKeyPathWorkoutActivityStartDate;
extern NSString *const RevenantHKMeasured_HKPredicateKeyPathWorkoutActivitySumQuantity;
extern NSString *const RevenantHKMeasured_HKPredicateKeyPathWorkoutActivityType;
extern NSString *const RevenantHKMeasured_HKPredicateKeyPathWorkoutAverageQuantity;
extern NSString *const RevenantHKMeasured_HKPredicateKeyPathWorkoutMaximumQuantity;
extern NSString *const RevenantHKMeasured_HKPredicateKeyPathWorkoutMinimumQuantity;
extern NSString *const RevenantHKMeasured_HKPredicateKeyPathWorkoutSumQuantity;
extern NSString *const RevenantHKMeasured_HKQuantityTypeIdentifierAppleMoveTime;
extern NSString *const RevenantHKMeasured_HKQuantityTypeIdentifierAppleSleepingWristTemperature;
extern NSString *const RevenantHKMeasured_HKQuantityTypeIdentifierAppleStandTime;
extern NSString *const RevenantHKMeasured_HKQuantityTypeIdentifierAppleWalkingSteadiness;
extern NSString *const RevenantHKMeasured_HKQuantityTypeIdentifierAtrialFibrillationBurden;
extern NSString *const RevenantHKMeasured_HKQuantityTypeIdentifierEnvironmentalAudioExposure;
extern NSString *const RevenantHKMeasured_HKQuantityTypeIdentifierEnvironmentalSoundReduction;
extern NSString *const RevenantHKMeasured_HKQuantityTypeIdentifierHeadphoneAudioExposure;
extern NSString *const RevenantHKMeasured_HKQuantityTypeIdentifierHeartRateRecoveryOneMinute;
extern NSString *const RevenantHKMeasured_HKQuantityTypeIdentifierNumberOfAlcoholicBeverages;
extern NSString *const RevenantHKMeasured_HKQuantityTypeIdentifierRunningGroundContactTime;
extern NSString *const RevenantHKMeasured_HKQuantityTypeIdentifierRunningPower;
extern NSString *const RevenantHKMeasured_HKQuantityTypeIdentifierRunningSpeed;
extern NSString *const RevenantHKMeasured_HKQuantityTypeIdentifierRunningStrideLength;
extern NSString *const RevenantHKMeasured_HKQuantityTypeIdentifierRunningVerticalOscillation;
extern NSString *const RevenantHKMeasured_HKQuantityTypeIdentifierSixMinuteWalkTestDistance;
extern NSString *const RevenantHKMeasured_HKQuantityTypeIdentifierStairAscentSpeed;
extern NSString *const RevenantHKMeasured_HKQuantityTypeIdentifierStairDescentSpeed;
extern NSString *const RevenantHKMeasured_HKQuantityTypeIdentifierUnderwaterDepth;
extern NSString *const RevenantHKMeasured_HKQuantityTypeIdentifierWalkingAsymmetryPercentage;
extern NSString *const RevenantHKMeasured_HKQuantityTypeIdentifierWalkingDoubleSupportPercentage;
extern NSString *const RevenantHKMeasured_HKQuantityTypeIdentifierWalkingSpeed;
extern NSString *const RevenantHKMeasured_HKQuantityTypeIdentifierWalkingStepLength;
extern NSString *const RevenantHKMeasured_HKQuantityTypeIdentifierWaterTemperature;
extern NSString *const RevenantHKMeasured_HKVerifiableClinicalRecordCredentialTypeCOVID19;
extern NSString *const RevenantHKMeasured_HKVerifiableClinicalRecordCredentialTypeImmunization;
extern NSString *const RevenantHKMeasured_HKVerifiableClinicalRecordCredentialTypeLaboratory;
extern NSString *const RevenantHKMeasured_HKVerifiableClinicalRecordCredentialTypeRecovery;
extern NSString *const RevenantHKMeasured_HKVerifiableClinicalRecordSourceTypeEUDigitalCOVIDCertificate;
extern NSString *const RevenantHKMeasured_HKVerifiableClinicalRecordSourceTypeSMARTHealthCard;
extern NSString *const RevenantHKMeasured_HKVisionPrescriptionTypeIdentifier;
extern NSString *const RevenantHKMeasured_HKCategoryTypeIdentifierBleedingAfterPregnancy;
extern NSString *const RevenantHKMeasured_HKCategoryTypeIdentifierBleedingDuringPregnancy;
extern NSString *const RevenantHKMeasured_HKCategoryTypeIdentifierSleepApneaEvent;
extern NSString *const RevenantHKMeasured_HKClinicalTypeIdentifierClinicalNoteRecord;
extern NSString *const RevenantHKMeasured_HKDataTypeIdentifierStateOfMind;
extern NSString *const RevenantHKMeasured_HKFHIRResourceTypeDiagnosticReport;
extern NSString *const RevenantHKMeasured_HKFHIRResourceTypeDocumentReference;
extern NSString *const RevenantHKMeasured_HKMetadataKeyActivityType;
extern NSString *const RevenantHKMeasured_HKMetadataKeyAppleFitnessPlusSession;
extern NSString *const RevenantHKMeasured_HKMetadataKeyCyclingFunctionalThresholdPowerTestType;
extern NSString *const RevenantHKMeasured_HKMetadataKeyHeadphoneGain;
extern NSString *const RevenantHKMeasured_HKMetadataKeyMaximumLightIntensity;
extern NSString *const RevenantHKMeasured_HKMetadataKeyPhysicalEffortEstimationType;
extern NSString *const RevenantHKMeasured_HKMetadataKeyWaterSalinity;
extern NSString *const RevenantHKMeasured_HKPredicateKeyPathWorkoutEffortRelationship;
extern NSString *const RevenantHKMeasured_HKQuantityTypeIdentifierAppleSleepingBreathingDisturbances;
extern NSString *const RevenantHKMeasured_HKQuantityTypeIdentifierCrossCountrySkiingSpeed;
extern NSString *const RevenantHKMeasured_HKQuantityTypeIdentifierCyclingCadence;
extern NSString *const RevenantHKMeasured_HKQuantityTypeIdentifierCyclingFunctionalThresholdPower;
extern NSString *const RevenantHKMeasured_HKQuantityTypeIdentifierCyclingPower;
extern NSString *const RevenantHKMeasured_HKQuantityTypeIdentifierCyclingSpeed;
extern NSString *const RevenantHKMeasured_HKQuantityTypeIdentifierDistanceCrossCountrySkiing;
extern NSString *const RevenantHKMeasured_HKQuantityTypeIdentifierDistancePaddleSports;
extern NSString *const RevenantHKMeasured_HKQuantityTypeIdentifierDistanceRowing;
extern NSString *const RevenantHKMeasured_HKQuantityTypeIdentifierDistanceSkatingSports;
extern NSString *const RevenantHKMeasured_HKQuantityTypeIdentifierEstimatedWorkoutEffortScore;
extern NSString *const RevenantHKMeasured_HKQuantityTypeIdentifierPaddleSportsSpeed;
extern NSString *const RevenantHKMeasured_HKQuantityTypeIdentifierPhysicalEffort;
extern NSString *const RevenantHKMeasured_HKQuantityTypeIdentifierRowingSpeed;
extern NSString *const RevenantHKMeasured_HKQuantityTypeIdentifierTimeInDaylight;
extern NSString *const RevenantHKMeasured_HKQuantityTypeIdentifierWorkoutEffortScore;
extern NSString *const RevenantHKMeasured_HKScoredAssessmentTypeIdentifierGAD7;
extern NSString *const RevenantHKMeasured_HKScoredAssessmentTypeIdentifierPHQ9;
extern NSString *const RevenantHKMeasured_HKMetadataKeyAppleFitnessPlusCatalogIdentifier;
extern NSString *const RevenantHKMeasured_HKDataTypeIdentifierUserAnnotatedMedicationConcept;
extern NSString *const RevenantHKMeasured_HKHealthConceptDomainMedication;
extern NSString *const RevenantHKMeasured_HKPredicateKeyPathLogOrigin;
extern NSString *const RevenantHKMeasured_HKPredicateKeyPathMedicationConceptIdentifier;
extern NSString *const RevenantHKMeasured_HKPredicateKeyPathScheduledDate;
extern NSString *const RevenantHKMeasured_HKUserAnnotatedMedicationPredicateKeyPathHasSchedule;
extern NSString *const RevenantHKMeasured_HKUserAnnotatedMedicationPredicateKeyPathIsArchived;
extern NSString *const RevenantHKMeasured_HKCategoryTypeIdentifierHypertensionEvent;

static void RevenantHKMeasuredConstants(void)
{
    struct { NSString *name; NSString *port; } rows[] = {
    {@"HKMetadataKeyAlpineSlopeGrade", RevenantHK120_HKMetadataKeyAlpineSlopeGrade},
    {@"HKMetadataKeyAverageSpeed", RevenantHK120_HKMetadataKeyAverageSpeed},
    {@"HKMetadataKeyElevationAscended", RevenantHK120_HKMetadataKeyElevationAscended},
    {@"HKMetadataKeyElevationDescended", RevenantHK120_HKMetadataKeyElevationDescended},
    {@"HKMetadataKeyMaximumSpeed", RevenantHK120_HKMetadataKeyMaximumSpeed},
    {@"HKQuantityTypeIdentifierDistanceDownhillSnowSports", RevenantHK120_HKQuantityTypeIdentifierDistanceDownhillSnowSports},
    {@"HKCategoryTypeIdentifierAbdominalCramps", RevenantHKMeasured_HKCategoryTypeIdentifierAbdominalCramps},
    {@"HKCategoryTypeIdentifierAcne", RevenantHKMeasured_HKCategoryTypeIdentifierAcne},
    {@"HKCategoryTypeIdentifierAppetiteChanges", RevenantHKMeasured_HKCategoryTypeIdentifierAppetiteChanges},
    {@"HKCategoryTypeIdentifierAppleWalkingSteadinessEvent", RevenantHKMeasured_HKCategoryTypeIdentifierAppleWalkingSteadinessEvent},
    {@"HKCategoryTypeIdentifierAudioExposureEvent", RevenantHKMeasured_HKCategoryTypeIdentifierAudioExposureEvent},
    {@"HKCategoryTypeIdentifierBladderIncontinence", RevenantHKMeasured_HKCategoryTypeIdentifierBladderIncontinence},
    {@"HKCategoryTypeIdentifierBloating", RevenantHKMeasured_HKCategoryTypeIdentifierBloating},
    {@"HKCategoryTypeIdentifierBreastPain", RevenantHKMeasured_HKCategoryTypeIdentifierBreastPain},
    {@"HKCategoryTypeIdentifierChestTightnessOrPain", RevenantHKMeasured_HKCategoryTypeIdentifierChestTightnessOrPain},
    {@"HKCategoryTypeIdentifierChills", RevenantHKMeasured_HKCategoryTypeIdentifierChills},
    {@"HKCategoryTypeIdentifierConstipation", RevenantHKMeasured_HKCategoryTypeIdentifierConstipation},
    {@"HKCategoryTypeIdentifierContraceptive", RevenantHKMeasured_HKCategoryTypeIdentifierContraceptive},
    {@"HKCategoryTypeIdentifierCoughing", RevenantHKMeasured_HKCategoryTypeIdentifierCoughing},
    {@"HKCategoryTypeIdentifierDiarrhea", RevenantHKMeasured_HKCategoryTypeIdentifierDiarrhea},
    {@"HKCategoryTypeIdentifierDizziness", RevenantHKMeasured_HKCategoryTypeIdentifierDizziness},
    {@"HKCategoryTypeIdentifierDrySkin", RevenantHKMeasured_HKCategoryTypeIdentifierDrySkin},
    {@"HKCategoryTypeIdentifierEnvironmentalAudioExposureEvent", RevenantHKMeasured_HKCategoryTypeIdentifierEnvironmentalAudioExposureEvent},
    {@"HKCategoryTypeIdentifierFainting", RevenantHKMeasured_HKCategoryTypeIdentifierFainting},
    {@"HKCategoryTypeIdentifierFatigue", RevenantHKMeasured_HKCategoryTypeIdentifierFatigue},
    {@"HKCategoryTypeIdentifierFever", RevenantHKMeasured_HKCategoryTypeIdentifierFever},
    {@"HKCategoryTypeIdentifierGeneralizedBodyAche", RevenantHKMeasured_HKCategoryTypeIdentifierGeneralizedBodyAche},
    {@"HKCategoryTypeIdentifierHairLoss", RevenantHKMeasured_HKCategoryTypeIdentifierHairLoss},
    {@"HKCategoryTypeIdentifierHandwashingEvent", RevenantHKMeasured_HKCategoryTypeIdentifierHandwashingEvent},
    {@"HKCategoryTypeIdentifierHeadache", RevenantHKMeasured_HKCategoryTypeIdentifierHeadache},
    {@"HKCategoryTypeIdentifierHeadphoneAudioExposureEvent", RevenantHKMeasured_HKCategoryTypeIdentifierHeadphoneAudioExposureEvent},
    {@"HKCategoryTypeIdentifierHeartburn", RevenantHKMeasured_HKCategoryTypeIdentifierHeartburn},
    {@"HKCategoryTypeIdentifierHighHeartRateEvent", RevenantHKMeasured_HKCategoryTypeIdentifierHighHeartRateEvent},
    {@"HKCategoryTypeIdentifierHotFlashes", RevenantHKMeasured_HKCategoryTypeIdentifierHotFlashes},
    {@"HKCategoryTypeIdentifierInfrequentMenstrualCycles", RevenantHKMeasured_HKCategoryTypeIdentifierInfrequentMenstrualCycles},
    {@"HKCategoryTypeIdentifierIrregularHeartRhythmEvent", RevenantHKMeasured_HKCategoryTypeIdentifierIrregularHeartRhythmEvent},
    {@"HKCategoryTypeIdentifierIrregularMenstrualCycles", RevenantHKMeasured_HKCategoryTypeIdentifierIrregularMenstrualCycles},
    {@"HKCategoryTypeIdentifierLactation", RevenantHKMeasured_HKCategoryTypeIdentifierLactation},
    {@"HKCategoryTypeIdentifierLossOfSmell", RevenantHKMeasured_HKCategoryTypeIdentifierLossOfSmell},
    {@"HKCategoryTypeIdentifierLossOfTaste", RevenantHKMeasured_HKCategoryTypeIdentifierLossOfTaste},
    {@"HKCategoryTypeIdentifierLowCardioFitnessEvent", RevenantHKMeasured_HKCategoryTypeIdentifierLowCardioFitnessEvent},
    {@"HKCategoryTypeIdentifierLowHeartRateEvent", RevenantHKMeasured_HKCategoryTypeIdentifierLowHeartRateEvent},
    {@"HKCategoryTypeIdentifierLowerBackPain", RevenantHKMeasured_HKCategoryTypeIdentifierLowerBackPain},
    {@"HKCategoryTypeIdentifierMemoryLapse", RevenantHKMeasured_HKCategoryTypeIdentifierMemoryLapse},
    {@"HKCategoryTypeIdentifierMoodChanges", RevenantHKMeasured_HKCategoryTypeIdentifierMoodChanges},
    {@"HKCategoryTypeIdentifierNausea", RevenantHKMeasured_HKCategoryTypeIdentifierNausea},
    {@"HKCategoryTypeIdentifierNightSweats", RevenantHKMeasured_HKCategoryTypeIdentifierNightSweats},
    {@"HKCategoryTypeIdentifierPelvicPain", RevenantHKMeasured_HKCategoryTypeIdentifierPelvicPain},
    {@"HKCategoryTypeIdentifierPersistentIntermenstrualBleeding", RevenantHKMeasured_HKCategoryTypeIdentifierPersistentIntermenstrualBleeding},
    {@"HKCategoryTypeIdentifierPregnancy", RevenantHKMeasured_HKCategoryTypeIdentifierPregnancy},
    {@"HKCategoryTypeIdentifierPregnancyTestResult", RevenantHKMeasured_HKCategoryTypeIdentifierPregnancyTestResult},
    {@"HKCategoryTypeIdentifierProgesteroneTestResult", RevenantHKMeasured_HKCategoryTypeIdentifierProgesteroneTestResult},
    {@"HKCategoryTypeIdentifierProlongedMenstrualPeriods", RevenantHKMeasured_HKCategoryTypeIdentifierProlongedMenstrualPeriods},
    {@"HKCategoryTypeIdentifierRapidPoundingOrFlutteringHeartbeat", RevenantHKMeasured_HKCategoryTypeIdentifierRapidPoundingOrFlutteringHeartbeat},
    {@"HKCategoryTypeIdentifierRunnyNose", RevenantHKMeasured_HKCategoryTypeIdentifierRunnyNose},
    {@"HKCategoryTypeIdentifierShortnessOfBreath", RevenantHKMeasured_HKCategoryTypeIdentifierShortnessOfBreath},
    {@"HKCategoryTypeIdentifierSinusCongestion", RevenantHKMeasured_HKCategoryTypeIdentifierSinusCongestion},
    {@"HKCategoryTypeIdentifierSkippedHeartbeat", RevenantHKMeasured_HKCategoryTypeIdentifierSkippedHeartbeat},
    {@"HKCategoryTypeIdentifierSleepChanges", RevenantHKMeasured_HKCategoryTypeIdentifierSleepChanges},
    {@"HKCategoryTypeIdentifierSoreThroat", RevenantHKMeasured_HKCategoryTypeIdentifierSoreThroat},
    {@"HKCategoryTypeIdentifierToothbrushingEvent", RevenantHKMeasured_HKCategoryTypeIdentifierToothbrushingEvent},
    {@"HKCategoryTypeIdentifierVaginalDryness", RevenantHKMeasured_HKCategoryTypeIdentifierVaginalDryness},
    {@"HKCategoryTypeIdentifierVomiting", RevenantHKMeasured_HKCategoryTypeIdentifierVomiting},
    {@"HKCategoryTypeIdentifierWheezing", RevenantHKMeasured_HKCategoryTypeIdentifierWheezing},
    {@"HKCharacteristicTypeIdentifierActivityMoveMode", RevenantHKMeasured_HKCharacteristicTypeIdentifierActivityMoveMode},
    {@"HKClinicalTypeIdentifierCoverageRecord", RevenantHKMeasured_HKClinicalTypeIdentifierCoverageRecord},
    {@"HKDataTypeIdentifierHeartbeatSeries", RevenantHKMeasured_HKDataTypeIdentifierHeartbeatSeries},
    {@"HKFHIRReleaseDSTU2", RevenantHKMeasured_HKFHIRReleaseDSTU2},
    {@"HKFHIRReleaseR4", RevenantHKMeasured_HKFHIRReleaseR4},
    {@"HKFHIRReleaseUnknown", RevenantHKMeasured_HKFHIRReleaseUnknown},
    {@"HKFHIRResourceTypeCoverage", RevenantHKMeasured_HKFHIRResourceTypeCoverage},
    {@"HKFHIRResourceTypeMedicationRequest", RevenantHKMeasured_HKFHIRResourceTypeMedicationRequest},
    {@"HKMedicationDoseEventTypeIdentifierMedicationDoseEvent", RevenantHKMeasured_HKMedicationDoseEventTypeIdentifierMedicationDoseEvent},
    {@"HKMetadataKeyAlgorithmVersion", RevenantHKMeasured_HKMetadataKeyAlgorithmVersion},
    {@"HKMetadataKeyAppleDeviceCalibrated", RevenantHKMeasured_HKMetadataKeyAppleDeviceCalibrated},
    {@"HKMetadataKeyAppleECGAlgorithmVersion", RevenantHKMeasured_HKMetadataKeyAppleECGAlgorithmVersion},
    {@"HKMetadataKeyAudioExposureDuration", RevenantHKMeasured_HKMetadataKeyAudioExposureDuration},
    {@"HKMetadataKeyAudioExposureLevel", RevenantHKMeasured_HKMetadataKeyAudioExposureLevel},
    {@"HKMetadataKeyAverageMETs", RevenantHKMeasured_HKMetadataKeyAverageMETs},
    {@"HKMetadataKeyBarometricPressure", RevenantHKMeasured_HKMetadataKeyBarometricPressure},
    {@"HKMetadataKeyDateOfEarliestDataUsedForEstimate", RevenantHKMeasured_HKMetadataKeyDateOfEarliestDataUsedForEstimate},
    {@"HKMetadataKeyDevicePlacementSide", RevenantHKMeasured_HKMetadataKeyDevicePlacementSide},
    {@"HKMetadataKeyGlassesPrescriptionDescription", RevenantHKMeasured_HKMetadataKeyGlassesPrescriptionDescription},
    {@"HKMetadataKeyHeartRateEventThreshold", RevenantHKMeasured_HKMetadataKeyHeartRateEventThreshold},
    {@"HKMetadataKeyHeartRateRecoveryActivityDuration", RevenantHKMeasured_HKMetadataKeyHeartRateRecoveryActivityDuration},
    {@"HKMetadataKeyHeartRateRecoveryActivityType", RevenantHKMeasured_HKMetadataKeyHeartRateRecoveryActivityType},
    {@"HKMetadataKeyHeartRateRecoveryMaxObservedRecoveryHeartRate", RevenantHKMeasured_HKMetadataKeyHeartRateRecoveryMaxObservedRecoveryHeartRate},
    {@"HKMetadataKeyHeartRateRecoveryTestType", RevenantHKMeasured_HKMetadataKeyHeartRateRecoveryTestType},
    {@"HKMetadataKeyLowCardioFitnessEventThreshold", RevenantHKMeasured_HKMetadataKeyLowCardioFitnessEventThreshold},
    {@"HKMetadataKeyQuantityClampedToLowerBound", RevenantHKMeasured_HKMetadataKeyQuantityClampedToLowerBound},
    {@"HKMetadataKeyQuantityClampedToUpperBound", RevenantHKMeasured_HKMetadataKeyQuantityClampedToUpperBound},
    {@"HKMetadataKeySWOLFScore", RevenantHKMeasured_HKMetadataKeySWOLFScore},
    {@"HKMetadataKeySessionEstimate", RevenantHKMeasured_HKMetadataKeySessionEstimate},
    {@"HKMetadataKeyUserMotionContext", RevenantHKMeasured_HKMetadataKeyUserMotionContext},
    {@"HKMetadataKeyVO2MaxValue", RevenantHKMeasured_HKMetadataKeyVO2MaxValue},
    {@"HKPredicateKeyPathAverage", RevenantHKMeasured_HKPredicateKeyPathAverage},
    {@"HKPredicateKeyPathAverageHeartRate", RevenantHKMeasured_HKPredicateKeyPathAverageHeartRate},
    {@"HKPredicateKeyPathCount", RevenantHKMeasured_HKPredicateKeyPathCount},
    {@"HKPredicateKeyPathECGClassification", RevenantHKMeasured_HKPredicateKeyPathECGClassification},
    {@"HKPredicateKeyPathECGSymptomsStatus", RevenantHKMeasured_HKPredicateKeyPathECGSymptomsStatus},
    {@"HKPredicateKeyPathMax", RevenantHKMeasured_HKPredicateKeyPathMax},
    {@"HKPredicateKeyPathMin", RevenantHKMeasured_HKPredicateKeyPathMin},
    {@"HKPredicateKeyPathMostRecent", RevenantHKMeasured_HKPredicateKeyPathMostRecent},
    {@"HKPredicateKeyPathMostRecentDuration", RevenantHKMeasured_HKPredicateKeyPathMostRecentDuration},
    {@"HKPredicateKeyPathMostRecentEndDate", RevenantHKMeasured_HKPredicateKeyPathMostRecentEndDate},
    {@"HKPredicateKeyPathMostRecentStartDate", RevenantHKMeasured_HKPredicateKeyPathMostRecentStartDate},
    {@"HKPredicateKeyPathStatus", RevenantHKMeasured_HKPredicateKeyPathStatus},
    {@"HKPredicateKeyPathWorkoutActivity", RevenantHKMeasured_HKPredicateKeyPathWorkoutActivity},
    {@"HKPredicateKeyPathWorkoutActivityAverageQuantity", RevenantHKMeasured_HKPredicateKeyPathWorkoutActivityAverageQuantity},
    {@"HKPredicateKeyPathWorkoutActivityDuration", RevenantHKMeasured_HKPredicateKeyPathWorkoutActivityDuration},
    {@"HKPredicateKeyPathWorkoutActivityEndDate", RevenantHKMeasured_HKPredicateKeyPathWorkoutActivityEndDate},
    {@"HKPredicateKeyPathWorkoutActivityMaximumQuantity", RevenantHKMeasured_HKPredicateKeyPathWorkoutActivityMaximumQuantity},
    {@"HKPredicateKeyPathWorkoutActivityMinimumQuantity", RevenantHKMeasured_HKPredicateKeyPathWorkoutActivityMinimumQuantity},
    {@"HKPredicateKeyPathWorkoutActivityStartDate", RevenantHKMeasured_HKPredicateKeyPathWorkoutActivityStartDate},
    {@"HKPredicateKeyPathWorkoutActivitySumQuantity", RevenantHKMeasured_HKPredicateKeyPathWorkoutActivitySumQuantity},
    {@"HKPredicateKeyPathWorkoutActivityType", RevenantHKMeasured_HKPredicateKeyPathWorkoutActivityType},
    {@"HKPredicateKeyPathWorkoutAverageQuantity", RevenantHKMeasured_HKPredicateKeyPathWorkoutAverageQuantity},
    {@"HKPredicateKeyPathWorkoutMaximumQuantity", RevenantHKMeasured_HKPredicateKeyPathWorkoutMaximumQuantity},
    {@"HKPredicateKeyPathWorkoutMinimumQuantity", RevenantHKMeasured_HKPredicateKeyPathWorkoutMinimumQuantity},
    {@"HKPredicateKeyPathWorkoutSumQuantity", RevenantHKMeasured_HKPredicateKeyPathWorkoutSumQuantity},
    {@"HKQuantityTypeIdentifierAppleMoveTime", RevenantHKMeasured_HKQuantityTypeIdentifierAppleMoveTime},
    {@"HKQuantityTypeIdentifierAppleSleepingWristTemperature", RevenantHKMeasured_HKQuantityTypeIdentifierAppleSleepingWristTemperature},
    {@"HKQuantityTypeIdentifierAppleStandTime", RevenantHKMeasured_HKQuantityTypeIdentifierAppleStandTime},
    {@"HKQuantityTypeIdentifierAppleWalkingSteadiness", RevenantHKMeasured_HKQuantityTypeIdentifierAppleWalkingSteadiness},
    {@"HKQuantityTypeIdentifierAtrialFibrillationBurden", RevenantHKMeasured_HKQuantityTypeIdentifierAtrialFibrillationBurden},
    {@"HKQuantityTypeIdentifierEnvironmentalAudioExposure", RevenantHKMeasured_HKQuantityTypeIdentifierEnvironmentalAudioExposure},
    {@"HKQuantityTypeIdentifierEnvironmentalSoundReduction", RevenantHKMeasured_HKQuantityTypeIdentifierEnvironmentalSoundReduction},
    {@"HKQuantityTypeIdentifierHeadphoneAudioExposure", RevenantHKMeasured_HKQuantityTypeIdentifierHeadphoneAudioExposure},
    {@"HKQuantityTypeIdentifierHeartRateRecoveryOneMinute", RevenantHKMeasured_HKQuantityTypeIdentifierHeartRateRecoveryOneMinute},
    {@"HKQuantityTypeIdentifierNumberOfAlcoholicBeverages", RevenantHKMeasured_HKQuantityTypeIdentifierNumberOfAlcoholicBeverages},
    {@"HKQuantityTypeIdentifierRunningGroundContactTime", RevenantHKMeasured_HKQuantityTypeIdentifierRunningGroundContactTime},
    {@"HKQuantityTypeIdentifierRunningPower", RevenantHKMeasured_HKQuantityTypeIdentifierRunningPower},
    {@"HKQuantityTypeIdentifierRunningSpeed", RevenantHKMeasured_HKQuantityTypeIdentifierRunningSpeed},
    {@"HKQuantityTypeIdentifierRunningStrideLength", RevenantHKMeasured_HKQuantityTypeIdentifierRunningStrideLength},
    {@"HKQuantityTypeIdentifierRunningVerticalOscillation", RevenantHKMeasured_HKQuantityTypeIdentifierRunningVerticalOscillation},
    {@"HKQuantityTypeIdentifierSixMinuteWalkTestDistance", RevenantHKMeasured_HKQuantityTypeIdentifierSixMinuteWalkTestDistance},
    {@"HKQuantityTypeIdentifierStairAscentSpeed", RevenantHKMeasured_HKQuantityTypeIdentifierStairAscentSpeed},
    {@"HKQuantityTypeIdentifierStairDescentSpeed", RevenantHKMeasured_HKQuantityTypeIdentifierStairDescentSpeed},
    {@"HKQuantityTypeIdentifierUnderwaterDepth", RevenantHKMeasured_HKQuantityTypeIdentifierUnderwaterDepth},
    {@"HKQuantityTypeIdentifierWalkingAsymmetryPercentage", RevenantHKMeasured_HKQuantityTypeIdentifierWalkingAsymmetryPercentage},
    {@"HKQuantityTypeIdentifierWalkingDoubleSupportPercentage", RevenantHKMeasured_HKQuantityTypeIdentifierWalkingDoubleSupportPercentage},
    {@"HKQuantityTypeIdentifierWalkingSpeed", RevenantHKMeasured_HKQuantityTypeIdentifierWalkingSpeed},
    {@"HKQuantityTypeIdentifierWalkingStepLength", RevenantHKMeasured_HKQuantityTypeIdentifierWalkingStepLength},
    {@"HKQuantityTypeIdentifierWaterTemperature", RevenantHKMeasured_HKQuantityTypeIdentifierWaterTemperature},
    {@"HKVerifiableClinicalRecordCredentialTypeCOVID19", RevenantHKMeasured_HKVerifiableClinicalRecordCredentialTypeCOVID19},
    {@"HKVerifiableClinicalRecordCredentialTypeImmunization", RevenantHKMeasured_HKVerifiableClinicalRecordCredentialTypeImmunization},
    {@"HKVerifiableClinicalRecordCredentialTypeLaboratory", RevenantHKMeasured_HKVerifiableClinicalRecordCredentialTypeLaboratory},
    {@"HKVerifiableClinicalRecordCredentialTypeRecovery", RevenantHKMeasured_HKVerifiableClinicalRecordCredentialTypeRecovery},
    {@"HKVerifiableClinicalRecordSourceTypeEUDigitalCOVIDCertificate", RevenantHKMeasured_HKVerifiableClinicalRecordSourceTypeEUDigitalCOVIDCertificate},
    {@"HKVerifiableClinicalRecordSourceTypeSMARTHealthCard", RevenantHKMeasured_HKVerifiableClinicalRecordSourceTypeSMARTHealthCard},
    {@"HKVisionPrescriptionTypeIdentifier", RevenantHKMeasured_HKVisionPrescriptionTypeIdentifier},
    {@"HKCategoryTypeIdentifierBleedingAfterPregnancy", RevenantHKMeasured_HKCategoryTypeIdentifierBleedingAfterPregnancy},
    {@"HKCategoryTypeIdentifierBleedingDuringPregnancy", RevenantHKMeasured_HKCategoryTypeIdentifierBleedingDuringPregnancy},
    {@"HKCategoryTypeIdentifierSleepApneaEvent", RevenantHKMeasured_HKCategoryTypeIdentifierSleepApneaEvent},
    {@"HKClinicalTypeIdentifierClinicalNoteRecord", RevenantHKMeasured_HKClinicalTypeIdentifierClinicalNoteRecord},
    {@"HKDataTypeIdentifierStateOfMind", RevenantHKMeasured_HKDataTypeIdentifierStateOfMind},
    {@"HKFHIRResourceTypeDiagnosticReport", RevenantHKMeasured_HKFHIRResourceTypeDiagnosticReport},
    {@"HKFHIRResourceTypeDocumentReference", RevenantHKMeasured_HKFHIRResourceTypeDocumentReference},
    {@"HKMetadataKeyActivityType", RevenantHKMeasured_HKMetadataKeyActivityType},
    {@"HKMetadataKeyAppleFitnessPlusSession", RevenantHKMeasured_HKMetadataKeyAppleFitnessPlusSession},
    {@"HKMetadataKeyCyclingFunctionalThresholdPowerTestType", RevenantHKMeasured_HKMetadataKeyCyclingFunctionalThresholdPowerTestType},
    {@"HKMetadataKeyHeadphoneGain", RevenantHKMeasured_HKMetadataKeyHeadphoneGain},
    {@"HKMetadataKeyMaximumLightIntensity", RevenantHKMeasured_HKMetadataKeyMaximumLightIntensity},
    {@"HKMetadataKeyPhysicalEffortEstimationType", RevenantHKMeasured_HKMetadataKeyPhysicalEffortEstimationType},
    {@"HKMetadataKeyWaterSalinity", RevenantHKMeasured_HKMetadataKeyWaterSalinity},
    {@"HKPredicateKeyPathWorkoutEffortRelationship", RevenantHKMeasured_HKPredicateKeyPathWorkoutEffortRelationship},
    {@"HKQuantityTypeIdentifierAppleSleepingBreathingDisturbances", RevenantHKMeasured_HKQuantityTypeIdentifierAppleSleepingBreathingDisturbances},
    {@"HKQuantityTypeIdentifierCrossCountrySkiingSpeed", RevenantHKMeasured_HKQuantityTypeIdentifierCrossCountrySkiingSpeed},
    {@"HKQuantityTypeIdentifierCyclingCadence", RevenantHKMeasured_HKQuantityTypeIdentifierCyclingCadence},
    {@"HKQuantityTypeIdentifierCyclingFunctionalThresholdPower", RevenantHKMeasured_HKQuantityTypeIdentifierCyclingFunctionalThresholdPower},
    {@"HKQuantityTypeIdentifierCyclingPower", RevenantHKMeasured_HKQuantityTypeIdentifierCyclingPower},
    {@"HKQuantityTypeIdentifierCyclingSpeed", RevenantHKMeasured_HKQuantityTypeIdentifierCyclingSpeed},
    {@"HKQuantityTypeIdentifierDistanceCrossCountrySkiing", RevenantHKMeasured_HKQuantityTypeIdentifierDistanceCrossCountrySkiing},
    {@"HKQuantityTypeIdentifierDistancePaddleSports", RevenantHKMeasured_HKQuantityTypeIdentifierDistancePaddleSports},
    {@"HKQuantityTypeIdentifierDistanceRowing", RevenantHKMeasured_HKQuantityTypeIdentifierDistanceRowing},
    {@"HKQuantityTypeIdentifierDistanceSkatingSports", RevenantHKMeasured_HKQuantityTypeIdentifierDistanceSkatingSports},
    {@"HKQuantityTypeIdentifierEstimatedWorkoutEffortScore", RevenantHKMeasured_HKQuantityTypeIdentifierEstimatedWorkoutEffortScore},
    {@"HKQuantityTypeIdentifierPaddleSportsSpeed", RevenantHKMeasured_HKQuantityTypeIdentifierPaddleSportsSpeed},
    {@"HKQuantityTypeIdentifierPhysicalEffort", RevenantHKMeasured_HKQuantityTypeIdentifierPhysicalEffort},
    {@"HKQuantityTypeIdentifierRowingSpeed", RevenantHKMeasured_HKQuantityTypeIdentifierRowingSpeed},
    {@"HKQuantityTypeIdentifierTimeInDaylight", RevenantHKMeasured_HKQuantityTypeIdentifierTimeInDaylight},
    {@"HKQuantityTypeIdentifierWorkoutEffortScore", RevenantHKMeasured_HKQuantityTypeIdentifierWorkoutEffortScore},
    {@"HKScoredAssessmentTypeIdentifierGAD7", RevenantHKMeasured_HKScoredAssessmentTypeIdentifierGAD7},
    {@"HKScoredAssessmentTypeIdentifierPHQ9", RevenantHKMeasured_HKScoredAssessmentTypeIdentifierPHQ9},
    {@"HKMetadataKeyAppleFitnessPlusCatalogIdentifier", RevenantHKMeasured_HKMetadataKeyAppleFitnessPlusCatalogIdentifier},
    {@"HKDataTypeIdentifierUserAnnotatedMedicationConcept", RevenantHKMeasured_HKDataTypeIdentifierUserAnnotatedMedicationConcept},
    {@"HKHealthConceptDomainMedication", RevenantHKMeasured_HKHealthConceptDomainMedication},
    {@"HKPredicateKeyPathLogOrigin", RevenantHKMeasured_HKPredicateKeyPathLogOrigin},
    {@"HKPredicateKeyPathMedicationConceptIdentifier", RevenantHKMeasured_HKPredicateKeyPathMedicationConceptIdentifier},
    {@"HKPredicateKeyPathScheduledDate", RevenantHKMeasured_HKPredicateKeyPathScheduledDate},
    {@"HKUserAnnotatedMedicationPredicateKeyPathHasSchedule", RevenantHKMeasured_HKUserAnnotatedMedicationPredicateKeyPathHasSchedule},
    {@"HKUserAnnotatedMedicationPredicateKeyPathIsArchived", RevenantHKMeasured_HKUserAnnotatedMedicationPredicateKeyPathIsArchived},
    {@"HKCategoryTypeIdentifierHypertensionEvent", RevenantHKMeasured_HKCategoryTypeIdentifierHypertensionEvent},
    };
    size_t missing = 0;
    for (size_t index = 0; index < sizeof(rows) / sizeof(rows[0]); index++) {
        void *host = dlsym(RTLD_DEFAULT, rows[index].name.UTF8String);
        if (host == NULL) {
            missing++;
            printf("MISSING  %s  the host's HealthKit does not export it\n", rows[index].name.UTF8String);
            continue;
        }
        NSString *theirs = (__bridge NSString *)(*(void **)host);
        RevenantHKCompare(rows[index].name, rows[index].port, theirs);
    }
    if (missing > 0)
        printf("missing on the host: %lu of %lu\n", (unsigned long)missing,
               (unsigned long)(sizeof(rows) / sizeof(rows[0])));
}

static void RevenantHKConstants12(void)
{
    RevenantHKCompare(@"HKFHIRResourceTypeAllergyIntolerance", RevenantHK120_HKFHIRResourceTypeAllergyIntolerance,
                    HKFHIRResourceTypeAllergyIntolerance);
    RevenantHKCompare(@"HKFHIRResourceTypeCondition", RevenantHK120_HKFHIRResourceTypeCondition, HKFHIRResourceTypeCondition);
    RevenantHKCompare(@"HKFHIRResourceTypeImmunization", RevenantHK120_HKFHIRResourceTypeImmunization,
                    HKFHIRResourceTypeImmunization);
    RevenantHKCompare(@"HKFHIRResourceTypeMedicationDispense", RevenantHK120_HKFHIRResourceTypeMedicationDispense,
                    HKFHIRResourceTypeMedicationDispense);
    RevenantHKCompare(@"HKFHIRResourceTypeMedicationOrder", RevenantHK120_HKFHIRResourceTypeMedicationOrder,
                    HKFHIRResourceTypeMedicationOrder);
    RevenantHKCompare(@"HKFHIRResourceTypeMedicationStatement", RevenantHK120_HKFHIRResourceTypeMedicationStatement,
                    HKFHIRResourceTypeMedicationStatement);
    RevenantHKCompare(@"HKFHIRResourceTypeObservation", RevenantHK120_HKFHIRResourceTypeObservation,
                    HKFHIRResourceTypeObservation);
    RevenantHKCompare(@"HKFHIRResourceTypeProcedure", RevenantHK120_HKFHIRResourceTypeProcedure, HKFHIRResourceTypeProcedure);
    RevenantHKCompare(@"HKMetadataKeyCrossTrainerDistance", RevenantHK120_HKMetadataKeyCrossTrainerDistance,
                    HKMetadataKeyCrossTrainerDistance);
    RevenantHKCompare(@"HKMetadataKeyFitnessMachineDuration", RevenantHK120_HKMetadataKeyFitnessMachineDuration,
                    HKMetadataKeyFitnessMachineDuration);
    RevenantHKCompare(@"HKMetadataKeyIndoorBikeDistance", RevenantHK120_HKMetadataKeyIndoorBikeDistance,
                    HKMetadataKeyIndoorBikeDistance);
    RevenantHKCompare(@"HKPredicateKeyPathClinicalRecordFHIRResourceIdentifier",
                    RevenantHK120_HKPredicateKeyPathClinicalRecordFHIRResourceIdentifier,
                    HKPredicateKeyPathClinicalRecordFHIRResourceIdentifier);
    RevenantHKCompare(@"HKPredicateKeyPathClinicalRecordFHIRResourceType",
                    RevenantHK120_HKPredicateKeyPathClinicalRecordFHIRResourceType,
                    HKPredicateKeyPathClinicalRecordFHIRResourceType);
    RevenantHKCompare(@"HKPredicateKeyPathSum", RevenantHK120_HKPredicateKeyPathSum, HKPredicateKeyPathSum);

    struct { NSString *mine, *theirs, *label; } clinical[] = {
        {RevenantHK120_HKClinicalTypeIdentifierAllergyRecord, HKClinicalTypeIdentifierAllergyRecord, @"allergy record"},
        {RevenantHK120_HKClinicalTypeIdentifierConditionRecord, HKClinicalTypeIdentifierConditionRecord, @"condition record"},
        {RevenantHK120_HKClinicalTypeIdentifierImmunizationRecord, HKClinicalTypeIdentifierImmunizationRecord,
         @"immunization record"},
        {RevenantHK120_HKClinicalTypeIdentifierLabResultRecord, HKClinicalTypeIdentifierLabResultRecord, @"lab result record"},
        {RevenantHK120_HKClinicalTypeIdentifierMedicationRecord, HKClinicalTypeIdentifierMedicationRecord,
         @"medication record"},
        {RevenantHK120_HKClinicalTypeIdentifierProcedureRecord, HKClinicalTypeIdentifierProcedureRecord,
         @"procedure record"},
        {RevenantHK120_HKClinicalTypeIdentifierVitalSignRecord, HKClinicalTypeIdentifierVitalSignRecord, @"vital sign record"},
    };
    for (size_t index = 0; index < sizeof(clinical) / sizeof(clinical[0]); index++) {
        NSString *what = [@"HKClinicalTypeIdentifier" stringByAppendingString:clinical[index].label];
        RevenantHKCompare(what, clinical[index].mine, clinical[index].theirs);
        HKClinicalType *theirsType = [HKObjectType clinicalTypeForIdentifier:clinical[index].theirs];
        RevenantHostHKClinicalType *mineType = [RevenantHostHKObjectType clinicalTypeForIdentifier:clinical[index].mine];
        RevenantHKCompareBool([what stringByAppendingString:@" is a clinical type"], mineType != nil, theirsType != nil);
        if (mineType && theirsType)
            RevenantHKCompare([what stringByAppendingString:@" is the same clinical type"], mineType.identifier,
                            theirsType.identifier);
    }
}

typedef struct {
    __unsafe_unretained NSString *name;
    __unsafe_unretained NSString *dimension;
    BOOL affine;
} HKUnitCase;

static HKUnitCase RevenantHKUnits[] = {
    {@"g", @"g", NO}, {@"kg", @"g", NO}, {@"mg", @"g", NO}, {@"mcg", @"g", NO}, {@"ng", @"g", NO},
    {@"pg", @"g", NO}, {@"fg", @"g", NO}, {@"oz", @"g", NO}, {@"lb", @"g", NO}, {@"st", @"g", NO},
    {@"m", @"m", NO}, {@"km", @"m", NO}, {@"cm", @"m", NO}, {@"mm", @"m", NO}, {@"mcm", @"m", NO},
    {@"nm", @"m", NO}, {@"in", @"m", NO}, {@"ft", @"m", NO}, {@"yd", @"m", NO}, {@"mi", @"m", NO},
    {@"L", @"L", NO}, {@"mL", @"L", NO}, {@"mcL", @"L", NO}, {@"nL", @"L", NO}, {@"pL", @"L", NO},
    {@"fL", @"L", NO}, {@"dL", @"L", NO}, {@"cL", @"L", NO}, {@"daL", @"L", NO}, {@"hL", @"L", NO},
    {@"fl_oz_us", @"L", NO}, {@"pt_us", @"L", NO}, {@"cup_us", @"L", NO},
    {@"fl_oz_imp", @"L", NO}, {@"pt_imp", @"L", NO}, {@"cup_imp", @"L", NO},
    {@"Pa", @"Pa", NO}, {@"kPa", @"Pa", NO}, {@"hPa", @"Pa", NO}, {@"daPa", @"Pa", NO}, {@"MPa", @"Pa", NO},
    {@"mmHg", @"Pa", NO}, {@"cmAq", @"Pa", NO}, {@"atm", @"Pa", NO}, {@"inHg", @"Pa", NO},
    {@"s", @"s", NO}, {@"ms", @"s", NO}, {@"mcs", @"s", NO}, {@"ns", @"s", NO}, {@"min", @"s", NO},
    {@"hr", @"s", NO}, {@"d", @"s", NO},
    {@"J", @"J", NO}, {@"kJ", @"J", NO}, {@"MJ", @"J", NO}, {@"cal", @"J", NO}, {@"kcal", @"J", NO},
    {@"Cal", @"J", NO}, {@"kWh", @"J", NO},
    {@"K", @"K", YES}, {@"degC", @"K", YES}, {@"degF", @"K", YES},
    {@"S", @"S", NO}, {@"mS", @"S", NO}, {@"mcS", @"S", NO}, {@"nS", @"S", NO}, {@"pS", @"S", NO},
    {@"count", @"count", NO}, {@"%", @"%", NO},
    {@"count/s", @"count/s", NO}, {@"count/min", @"count/min", NO}, {@"m/s", @"m/s", NO},
    {@"L/min", @"L/min", NO}, {@"mg/dL", @"mg/dL", NO}, {@"ml/(kg*min)", @"ml/(kg*min)", NO},
    {@"kcal/(kg*hr)", @"kcal/(kg*hr)", NO}, {@"dBASPL", @"dBASPL", NO},
    {@"", @"", NO}, {@"not a unit", @"", NO}, {@"kg/", @"", NO}, {@"1/", @"", NO}, {@"*", @"", NO},
};
static const NSUInteger RevenantHKUnitCaseCount = sizeof(RevenantHKUnits) / sizeof(RevenantHKUnits[0]);

static void RevenantHKUnitCases(void)
{
    for (NSUInteger index = 0; index < RevenantHKUnitCaseCount; index++) {
        NSString *name = RevenantHKUnits[index].name;
        NSString *dimension = RevenantHKUnits[index].dimension;
        NSString *label = [@"unitFromString:" stringByAppendingString:name];
        BOOL theirsRaised = NO, mineRaised = NO, theirsNil = NO, mineNil = NO;
        HKUnit *theirs = nil;
        RevenantHostHKUnit *mine = nil;
        @try {
            theirs = [HKUnit unitFromString:name];
            theirsNil = theirs == nil;
        } @catch (NSException *exception) {
            theirsRaised = YES;
        }
        @try {
            mine = [RevenantHostHKUnit unitFromString:name];
            mineNil = mine == nil;
        } @catch (NSException *exception) {
            mineRaised = YES;
        }
        RevenantHKCompareBool([label stringByAppendingString:@" raises"], mineRaised, theirsRaised);
        RevenantHKCompareBool([label stringByAppendingString:@" nil"], mineNil, theirsNil);
        if (!theirs || !mine)
            continue;
        if (!theirs || !mine)
            continue;
        RevenantHKCompareFactors([label stringByAppendingString:@" unitString"], mine, theirs);
        RevenantHKCompareBool([label stringByAppendingString:@" isNull"], mine.isNull, theirs.isNull);

        HKUnit *theirsReference = [HKUnit unitFromString:dimension];
        RevenantHostHKUnit *mineReference = [RevenantHostHKUnit unitFromString:dimension];
        if (!theirsReference || !mineReference)
            continue;
        RevenantHostHKQuantity *mineQuantity = [RevenantHostHKQuantity quantityWithUnit:mine doubleValue:RevenantHKProbe];
        HKQuantity *theirsQuantity = [HKQuantity quantityWithUnit:theirs doubleValue:RevenantHKProbe];
        RevenantHKCompareBool([label stringByAppendingString:@" isCompatibleWithUnit:itsDimension"],
                            [mineQuantity isCompatibleWithUnit:mineReference],
                            [theirsQuantity isCompatibleWithUnit:theirsReference]);
        if (![mineQuantity isCompatibleWithUnit:mineReference] || ![theirsQuantity isCompatibleWithUnit:theirsReference])
            continue;
        RevenantHKCompareDouble([label stringByAppendingFormat:@" %g in %@", RevenantHKProbe, dimension],
                              [mineQuantity doubleValueForUnit:mineReference],
                              [theirsQuantity doubleValueForUnit:theirsReference]);
        if (RevenantHKUnits[index].affine) {
            RevenantHostHKQuantity *mineSecond = [RevenantHostHKQuantity quantityWithUnit:mine doubleValue:RevenantHKSecondProbe];
            HKQuantity *theirsSecond = [HKQuantity quantityWithUnit:theirs doubleValue:RevenantHKSecondProbe];
            RevenantHKCompareDouble([label stringByAppendingFormat:@" %g in %@", RevenantHKSecondProbe, dimension],
                                  [mineSecond doubleValueForUnit:mineReference],
                                  [theirsSecond doubleValueForUnit:theirsReference]);
        }
        HKUnit *theirsOther = [HKUnit unitFromString:@"count"];
        RevenantHostHKUnit *mineOther = [RevenantHostHKUnit unitFromString:@"count"];
        if (theirsOther && mineOther) {
            RevenantHKCompareBool([label stringByAppendingString:@" isCompatibleWithUnit:count"],
                                [mineQuantity isCompatibleWithUnit:mineOther],
                                [theirsQuantity isCompatibleWithUnit:theirsOther]);
            if (RevenantHKUnits[index].affine) {
                BOOL mineRefused = NO, theirsRefused = NO;
                @try {
                    (void)[mine reciprocalUnit];
                } @catch (NSException *exception) {
                    mineRefused = YES;
                }
                @try {
                    (void)[theirs reciprocalUnit];
                } @catch (NSException *exception) {
                    theirsRefused = YES;
                }
                RevenantHKCompareBool([label stringByAppendingString:@" reciprocal raises"], mineRefused,
                                    theirsRefused);
            } else {
                RevenantHostHKUnit *mineReciprocal = [mine reciprocalUnit];
                HKUnit *theirsReciprocal = [theirs reciprocalUnit];
                RevenantHKCompareFactors([label stringByAppendingString:@" reciprocal"], mineReciprocal,
                                       theirsReciprocal);
            }
        }
    }
}

static void RevenantHKUnitArithmetic(void)
{
    NSArray *pairs = @[@[ @"m", @"s" ], @[ @"m", @"min" ], @[ @"kg", @"m" ], @[ @"mL", @"kg" ],
                        @[ @"kcal", @"hr" ], @[ @"J", @"K" ], @[ @"count", @"min" ], @[ @"L", @"hr" ]];
    static NSInteger powers[] = { -2, -1, 2, 3 };
    for (NSArray *pair in pairs) {
        HKUnit *theirsLeft = [HKUnit unitFromString:pair[0]], *theirsRight = [HKUnit unitFromString:pair[1]];
        RevenantHostHKUnit *mineLeft = [RevenantHostHKUnit unitFromString:pair[0]],
                           *mineRight = [RevenantHostHKUnit unitFromString:pair[1]];
        if (!theirsLeft || !theirsRight || !mineLeft || !mineRight)
            continue;
        NSString *label = [NSString stringWithFormat:@"%@ x %@", pair[0], pair[1]];
        HKUnit *theirsProduct = [theirsLeft unitMultipliedByUnit:theirsRight];
        RevenantHostHKUnit *mineProduct = [mineLeft unitMultipliedByUnit:mineRight];
        RevenantHKCompareFactors([label stringByAppendingString:@" product"], mineProduct, theirsProduct);
        HKUnit *theirsQuotient = [theirsLeft unitDividedByUnit:theirsRight];
        RevenantHostHKUnit *mineQuotient = [mineLeft unitDividedByUnit:mineRight];
        RevenantHKCompareFactors([label stringByAppendingString:@" quotient"], mineQuotient, theirsQuotient);

        RevenantHostHKQuantity *mineValue = [RevenantHostHKQuantity quantityWithUnit:mineLeft doubleValue:RevenantHKProbe];
        HKQuantity *theirsValue = [HKQuantity quantityWithUnit:theirsLeft doubleValue:RevenantHKProbe];
        RevenantHKCompareBool([label stringByAppendingString:@" takes a conversion into the product"],
                            [mineValue isCompatibleWithUnit:mineProduct],
                            [theirsValue isCompatibleWithUnit:theirsProduct]);
        RevenantHostHKQuantity *mineQuotientValue = [RevenantHostHKQuantity quantityWithUnit:mineLeft doubleValue:RevenantHKProbe];
        HKQuantity *theirsQuotientValue = [HKQuantity quantityWithUnit:theirsLeft doubleValue:RevenantHKProbe];
        RevenantHKCompareBool([label stringByAppendingString:@" takes a conversion into the quotient"],
                            [mineQuotientValue isCompatibleWithUnit:mineQuotient],
                            [theirsQuotientValue isCompatibleWithUnit:theirsQuotient]);
        for (NSUInteger step = 0; step < 4; step++) {
            HKUnit *theirsPower = [theirsLeft unitRaisedToPower:powers[step]];
            RevenantHostHKUnit *minePower = [mineLeft unitRaisedToPower:powers[step]];
            RevenantHKCompareFactors([NSString stringWithFormat:@"%@ raised to %ld", pair[0], (long)powers[step]],
                                   minePower, theirsPower);
        }
    }
    HKUnit *theirsCelsius = [HKUnit degreeCelsiusUnit], *theirsMetre = [HKUnit meterUnit];
    RevenantHostHKUnit *mineCelsius = [RevenantHostHKUnit degreeCelsiusUnit],
                       *mineMetre = [RevenantHostHKUnit meterUnit];
    NSArray *selectors = @[ @"unitMultipliedByUnit:", @"unitDividedByUnit:" ];
    for (NSUInteger step = 0; step < selectors.count; step++) {
        SEL chosen = NSSelectorFromString(selectors[step]);
        NSString *label = [NSString stringWithFormat:@"degC %@ m raises", selectors[step]];
        BOOL mineRaised = NO, theirsRaised = NO;
        @try {
            (void)[mineCelsius performSelector:chosen withObject:mineMetre];
        } @catch (NSException *exception) {
            mineRaised = YES;
        }
        @try {
            (void)[theirsCelsius performSelector:chosen withObject:theirsMetre];
        } @catch (NSException *exception) {
            theirsRaised = YES;
        }
        RevenantHKCompareBool(label, mineRaised, theirsRaised);
    }
}

typedef id (^RevenantHKPrefixedFactory)(NSInteger);

static RevenantHKPrefixedFactory RevenantHKPortPrefixed(NSUInteger index)
{
    switch (index) {
    case 0:
        return ^id(NSInteger p) { return [RevenantHostHKUnit gramUnitWithMetricPrefix:(HKMetricPrefix)p]; };
    case 1:
        return ^id(NSInteger p) { return [RevenantHostHKUnit meterUnitWithMetricPrefix:(HKMetricPrefix)p]; };
    case 2:
        return ^id(NSInteger p) { return [RevenantHostHKUnit literUnitWithMetricPrefix:(HKMetricPrefix)p]; };
    case 3:
        return ^id(NSInteger p) { return [RevenantHostHKUnit pascalUnitWithMetricPrefix:(HKMetricPrefix)p]; };
    case 4:
        return ^id(NSInteger p) { return [RevenantHostHKUnit secondUnitWithMetricPrefix:(HKMetricPrefix)p]; };
    case 5:
        return ^id(NSInteger p) { return [RevenantHostHKUnit jouleUnitWithMetricPrefix:(HKMetricPrefix)p]; };
    default:
        return ^id(NSInteger p) { return [RevenantHostHKUnit siemenUnitWithMetricPrefix:(HKMetricPrefix)p]; };
    }
}

static RevenantHKPrefixedFactory RevenantHKSystemPrefixed(NSUInteger index)
{
    switch (index) {
    case 0:
        return ^id(NSInteger p) { return [HKUnit gramUnitWithMetricPrefix:(HKMetricPrefix)p]; };
    case 1:
        return ^id(NSInteger p) { return [HKUnit meterUnitWithMetricPrefix:(HKMetricPrefix)p]; };
    case 2:
        return ^id(NSInteger p) { return [HKUnit literUnitWithMetricPrefix:(HKMetricPrefix)p]; };
    case 3:
        return ^id(NSInteger p) { return [HKUnit pascalUnitWithMetricPrefix:(HKMetricPrefix)p]; };
    case 4:
        return ^id(NSInteger p) { return [HKUnit secondUnitWithMetricPrefix:(HKMetricPrefix)p]; };
    case 5:
        return ^id(NSInteger p) { return [HKUnit jouleUnitWithMetricPrefix:(HKMetricPrefix)p]; };
    default:
        return ^id(NSInteger p) { return [HKUnit siemenUnitWithMetricPrefix:(HKMetricPrefix)p]; };
    }
}

static void RevenantHKPrefixedFactories(void)
{
    NSArray *factories = @[ @"gramUnitWithMetricPrefix:", @"meterUnitWithMetricPrefix:",
                            @"literUnitWithMetricPrefix:", @"pascalUnitWithMetricPrefix:",
                            @"secondUnitWithMetricPrefix:", @"jouleUnitWithMetricPrefix:",
                            @"siemenUnitWithMetricPrefix:" ];
    for (NSInteger prefix = HKMetricPrefixNone; prefix <= HKMetricPrefixTera; prefix++) {
        for (NSUInteger index = 0; index < factories.count; index++) {
            NSString *label = [NSString stringWithFormat:@"%@ prefix %ld", factories[index], (long)prefix];
            HKUnit *theirs = nil;
            RevenantHostHKUnit *mine = nil;
            BOOL theirsRefused = NO, mineRefused = NO;
            @try {
                theirs = (HKUnit *)RevenantHKSystemPrefixed(index)(prefix);
                theirsRefused = theirs == nil;
            } @catch (NSException *exception) {
                theirsRefused = YES;
            }
            @try {
                mine = (RevenantHostHKUnit *)RevenantHKPortPrefixed(index)(prefix);
                mineRefused = mine == nil;
            } @catch (NSException *exception) {
                mineRefused = YES;
            }
            RevenantHKCompareBool([label stringByAppendingString:@" answers"], !mineRefused, !theirsRefused);
            if (!theirs || !mine)
                continue;
            RevenantHKCompare([label stringByAppendingString:@" unitString"], mine.unitString, theirs.unitString);
        }
    }
    NSArray *plain = @[ @"gramUnit", @"ounceUnit", @"poundUnit", @"stoneUnit", @"meterUnit", @"inchUnit",
                        @"footUnit", @"yardUnit", @"mileUnit", @"literUnit", @"fluidOunceUSUnit",
                        @"fluidOunceImperialUnit", @"pintUSUnit", @"pintImperialUnit", @"cupUSUnit",
                        @"cupImperialUnit", @"pascalUnit", @"millimeterOfMercuryUnit",
                        @"centimeterOfWaterUnit", @"atmosphereUnit",
                        @"secondUnit", @"minuteUnit", @"hourUnit", @"dayUnit", @"jouleUnit",
                        @"kilocalorieUnit", @"calorieUnit", @"degreeCelsiusUnit",
                        @"degreeFahrenheitUnit", @"kelvinUnit", @"siemenUnit", @"countUnit",
                        @"percentUnit" ];
    for (NSString *name in plain) {
        SEL chosen = NSSelectorFromString(name);
        BOOL theirsHas = [HKUnit respondsToSelector:chosen];
        BOOL mineHas = [RevenantHostHKUnit respondsToSelector:chosen];
        RevenantHKCompareBool([name stringByAppendingString:@" exists"], mineHas, theirsHas);
        if (!theirsHas || !mineHas)
            continue;
        id theirs = [HKUnit performSelector:chosen];
        id mine = [RevenantHostHKUnit performSelector:chosen];
        if (!theirs || !mine) {
            RevenantHKCompareBool([name stringByAppendingString:@" answers"], mine != nil, theirs != nil);
            continue;
        }
        RevenantHKCompare([name stringByAppendingString:@" unitString"], [mine unitString], [theirs unitString]);
    }
}

static void RevenantHKQuantities(void)
{
    NSArray *units = @[ @"kg", @"g", @"m", @"cm", @"L", @"mL", @"kcal", @"kJ", @"min", @"hr", @"degC",
                        @"degF", @"K", @"mmHg", @"count", @"%", @"m/s", @"mg/dL" ];
    static const double values[] = { 0.0, 1.0, -1.0, 0.5, 2.5, -273.15, 1000.0, 1.0 / 3.0 };
    for (NSUInteger left = 0; left < units.count; left++) {
        for (NSUInteger right = 0; right < units.count; right++) {
            HKUnit *theirsLeft = [HKUnit unitFromString:units[left]], *theirsRight = [HKUnit unitFromString:units[right]];
            RevenantHostHKUnit *mineLeft = [RevenantHostHKUnit unitFromString:units[left]],
                               *mineRight = [RevenantHostHKUnit unitFromString:units[right]];
            if (!theirsLeft || !theirsRight || !mineLeft || !mineRight)
                continue;
            for (NSUInteger step = 0; step < 8; step++) {
                HKQuantity *theirs = [HKQuantity quantityWithUnit:theirsLeft doubleValue:values[step]];
                RevenantHostHKQuantity *mine = [RevenantHostHKQuantity quantityWithUnit:mineLeft doubleValue:values[step]];
                NSString *label = [NSString stringWithFormat:@"%g %@ -> %@", values[step], units[left], units[right]];
                RevenantHKCompareBool([label stringByAppendingString:@" isCompatibleWithUnit:"],
                                    [mine isCompatibleWithUnit:mineRight], [theirs isCompatibleWithUnit:theirsRight]);
                if (![mine isCompatibleWithUnit:mineRight] || ![theirs isCompatibleWithUnit:theirsRight])
                    continue;
                RevenantHKCompareDouble([label stringByAppendingString:@" doubleValueForUnit:"],
                                      [mine doubleValueForUnit:mineRight], [theirs doubleValueForUnit:theirsRight]);
                RevenantHKCompareInt([label stringByAppendingString:@" compare:itself"],
                                   [mine compare:mine], [theirs compare:theirs]);
                if (![mine isCompatibleWithUnit:mineLeft] || ![theirs isCompatibleWithUnit:theirsLeft])
                    continue;
                RevenantHKCompareInt([label stringByAppendingString:@" compare:itsUnit"],
                                   [mine compare:mine], [theirs compare:theirs]);
            }
        }
    }
    HKUnit *theirsKg = [HKUnit gramUnitWithMetricPrefix:HKMetricPrefixKilo];
    HKUnit *theirsG = [HKUnit gramUnit];
    HKUnit *theirsM = [HKUnit meterUnit];
    RevenantHostHKUnit *mineKg = [RevenantHostHKUnit gramUnitWithMetricPrefix:HKMetricPrefixKilo];
    RevenantHostHKUnit *mineG = [RevenantHostHKUnit gramUnit];
    RevenantHostHKUnit *mineM = [RevenantHostHKUnit meterUnit];
    HKQuantity *theirsHeavy = [HKQuantity quantityWithUnit:theirsKg doubleValue:2.0];
    HKQuantity *theirsLight = [HKQuantity quantityWithUnit:theirsG doubleValue:2500.0];
    RevenantHostHKQuantity *mineHeavy = [RevenantHostHKQuantity quantityWithUnit:mineKg doubleValue:2.0];
    RevenantHostHKQuantity *mineLight = [RevenantHostHKQuantity quantityWithUnit:mineG doubleValue:2500.0];
    RevenantHKCompareInt(@"2 kg compare: 2500 g", [mineHeavy compare:mineLight], [theirsHeavy compare:theirsLight]);
    RevenantHKCompareInt(@"2500 g compare: 2 kg", [mineLight compare:mineHeavy], [theirsLight compare:theirsHeavy]);
    HKQuantity *theirsMetre = [HKQuantity quantityWithUnit:theirsM doubleValue:1.0];
    RevenantHostHKQuantity *mineMetre = [RevenantHostHKQuantity quantityWithUnit:mineM doubleValue:1.0];
    BOOL mineRaised = NO, theirsRaised = NO;
    @try {
        (void)[mineHeavy compare:mineMetre];
    } @catch (NSException *exception) {
        mineRaised = YES;
    }
    @try {
        (void)[theirsHeavy compare:theirsMetre];
    } @catch (NSException *exception) {
        theirsRaised = YES;
    }
    RevenantHKCompareBool(@"2 kg compare: 1 m raises", mineRaised, theirsRaised);
}

static void RevenantHKTypeTable(void)
{
    for (NSUInteger index = 0; index < RevenantHKQuantityTypeCount(); index++) {
        const RevenantHKTypeEntry *entry = RevenantHKQuantityTypeEntryAt(index);
        if (!entry)
            continue;
        NSString *identifier = entry->identifier;
        HKQuantityType *theirs = (HKQuantityType *)[HKObjectType quantityTypeForIdentifier:identifier];
        RevenantHostHKQuantityType *mine = (RevenantHostHKQuantityType *)[RevenantHostHKObjectType quantityTypeForIdentifier:identifier];
        RevenantHKCompareBool([identifier stringByAppendingString:@" a quantity type"], mine != nil, theirs != nil);
        if (!theirs || !mine)
            continue;
        RevenantHKCompareInt([identifier stringByAppendingString:@" aggregates cumulatively"],
                           (NSInteger)mine.aggregationStyle, (NSInteger)theirs.aggregationStyle == 0 ? 0 : 1);
        BOOL mineRefused = NO, theirsRefused = NO;
        HKUnit *theirsUnit = nil;
        RevenantHostHKUnit *mineUnit = nil;
        @try {
            theirsUnit = [HKUnit unitFromString:entry->unit];
        } @catch (NSException *exception) {
            theirsRefused = YES;
        }
        @try {
            mineUnit = [RevenantHostHKUnit unitFromString:entry->unit];
        } @catch (NSException *exception) {
            mineRefused = YES;
        }
        RevenantHKCompareBool([identifier stringByAppendingString:@" its unit raises"], mineRefused, theirsRefused);
        if (theirsUnit && mineUnit)
            RevenantHKCompareBool([identifier stringByAppendingString:@" isCompatibleWithUnit:its own unit"],
                                [mine isCompatibleWithUnit:mineUnit], [theirs isCompatibleWithUnit:theirsUnit]);
        for (NSString *probe in @[ @"count", @"%", @"kg", @"m", @"s" ]) {
            HKUnit *theirsProbe = [HKUnit unitFromString:probe];
            RevenantHostHKUnit *mineProbe = [RevenantHostHKUnit unitFromString:probe];
            if (!theirsProbe || !mineProbe)
                continue;
            RevenantHKCompareBool([identifier stringByAppendingFormat:@" isCompatibleWithUnit:%@", probe],
                                [mine isCompatibleWithUnit:mineProbe], [theirs isCompatibleWithUnit:theirsProbe]);
        }
    }
}


static void RevenantHKQueryObjects(void)
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K.%K == %@", HKPredicateKeyPathMetadata,
                              HKMetadataKeySyncIdentifier, @"sync"];
    NSSortDescriptor *byDate = [NSSortDescriptor sortDescriptorWithKey:@"startDate" ascending:YES];
    NSDate *anchor = [NSDate dateWithTimeIntervalSince1970:1600000000];
    NSDateComponents *interval = [[NSDateComponents alloc] init];
    interval.day = 1;
    HKQuantityType *stepCount = [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierStepCount];
    HKQuantityType *heartRate = [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierHeartRate];
    RevenantHostHKQuantityType *mineStepCount = [RevenantHostHKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierStepCount];
    RevenantHostHKQuantityType *mineHeartRate = [RevenantHostHKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierHeartRate];
    if (!stepCount || !heartRate)
        return;


    {
        Class mineClass = objc_getClass("RevenantHostHKSampleQuery");
        Class mineSuper = mineClass ? class_getSuperclass(mineClass) : Nil;
        Class theirsClass = objc_getClass("HKSampleQuery");
        Class theirsSuper = theirsClass ? class_getSuperclass(theirsClass) : Nil;
        printf("LAYOUT mine=%s super=%s | theirs=%s super=%s\n",
               mineClass ? class_getName(mineClass) : "(none)",
               mineSuper ? class_getName(mineSuper) : "(none)",
               theirsClass ? class_getName(theirsClass) : "(none)",
               theirsSuper ? class_getName(theirsSuper) : "(none)");
        printf("LAYOUT mine superclass is the host's HKQuery: %s\n",
               mineSuper == objc_getClass("HKQuery") ? "YES" : "no");
        Ivar inMine = mineSuper ? class_getInstanceVariable(mineSuper, "_objectType") : NULL;
        Ivar inTheirs = theirsSuper ? class_getInstanceVariable(theirsSuper, "_objectType") : NULL;
        printf("LAYOUT _objectType offset: mineSuper=%lld theirsSuper=%lld\n",
               inMine ? (long long)ivar_getOffset(inMine) : -1LL,
               inTheirs ? (long long)ivar_getOffset(inTheirs) : -1LL);
        Ivar inMineQuery = mineClass ? class_getInstanceVariable(mineClass, "_objectType") : NULL;
        printf("LAYOUT _objectType offset on the sample query itself: %lld\n",
               inMineQuery ? (long long)ivar_getOffset(inMineQuery) : -1LL);
        id mineType = [RevenantHostHKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierHeartRate];
        (void)mineType;
        id theirsType = [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierHeartRate];
        printf("LAYOUT mineType=%s portSampleType=%s mineIsKind=%d | theirsType=%s hostSampleType=%s theirsIsKind=%d\n",
               RevenantHKDescribe([mineType class]), RevenantHKDescribe([RevenantHostHKSampleType class]),
               [mineType isKindOfClass:[RevenantHostHKSampleType class]] ? 1 : 0,
               RevenantHKDescribe([theirsType class]), RevenantHKDescribe([HKSampleType class]),
               [theirsType isKindOfClass:[HKSampleType class]] ? 1 : 0);
    }

    NSDictionary *matching = @{ @"metadata": @{ HKMetadataKeySyncIdentifier: @"sync" } };
    NSDictionary *mismatched = @{ @"metadata": @{ HKMetadataKeySyncIdentifier: @"other" } };
    HKSampleQuery *theirsByPredicate = [[HKSampleQuery alloc] initWithSampleType:stepCount
                                                                       predicate:predicate
                                                                           limit:HKObjectQueryNoLimit
                                                                    sortDescriptors:nil
                                                                     resultsHandler:nil];

    RevenantHostHKStatisticsCollectionQuery *mineCollection =
        [[RevenantHostHKStatisticsCollectionQuery alloc] initWithQuantityType:mineStepCount
                                                      quantitySamplePredicate:predicate
                                                                   options:HKStatisticsOptionCumulativeSum
                                                                anchorDate:anchor
                                                        intervalComponents:interval];
    RevenantHKCompare(@"collection query anchorDate", mineCollection.anchorDate, anchor);
    RevenantHKCompareInt(@"collection query options", (NSInteger)mineCollection.options,
                       (NSInteger)HKStatisticsOptionCumulativeSum);
    RevenantHKCompareInt(@"collection query interval day", mineCollection.intervalComponents.day, (NSInteger)1);
    RevenantHKCompareInt(@"collection query interval month", mineCollection.intervalComponents.month, (NSInteger)0);
    RevenantHKCompare(@"collection query objectType identifier", mineCollection.objectType.identifier,
                    stepCount.identifier);
    RevenantHKCompare(@"collection query predicate", mineCollection.predicate, predicate);
    RevenantHKCompareBool(@"collection query predicate evaluates a match",
                        [mineCollection.predicate evaluateWithObject:matching],
                        [theirsByPredicate.predicate evaluateWithObject:matching]);
    RevenantHKCompareBool(@"collection query predicate rejects a mismatch",
                        [mineCollection.predicate evaluateWithObject:mismatched],
                        [theirsByPredicate.predicate evaluateWithObject:mismatched]);
    RevenantHostHKSampleQuery *mineByPredicate = [[RevenantHostHKSampleQuery alloc] initWithSampleType:mineStepCount
                                                                                           predicate:predicate
                                                                                               limit:HKObjectQueryNoLimit
                                                                                        sortDescriptors:nil
                                                                                         resultsHandler:nil];
    RevenantHKCompare(@"a sample query's predicate", mineByPredicate.predicate, theirsByPredicate.predicate);
    RevenantHKCompareBool(@"that predicate evaluates a match",
                        [mineByPredicate.predicate evaluateWithObject:@{@"HKSourceSyncIdentifier": @"sync"}],
                        [theirsByPredicate.predicate evaluateWithObject:@{@"HKSourceSyncIdentifier": @"sync"}]);
    RevenantHKCompareBool(@"that predicate rejects a mismatch",
                        [mineByPredicate.predicate evaluateWithObject:@{@"HKSourceSyncIdentifier": @"other"}],
                        [theirsByPredicate.predicate evaluateWithObject:@{@"HKSourceSyncIdentifier": @"other"}]);

    HKSampleQuery *theirsSample = [[HKSampleQuery alloc] initWithSampleType:heartRate
                                                                 predicate:predicate
                                                                     limit:42
                                                          sortDescriptors:@[ byDate ]
                                                           resultsHandler:nil];
    RevenantHostHKSampleQuery *mineSample = [[RevenantHostHKSampleQuery alloc] initWithSampleType:mineHeartRate
                                                                               predicate:predicate
                                                                                   limit:42
                                                                        sortDescriptors:@[ byDate ]
                                                                         resultsHandler:nil];
    RevenantHKCompare(@"sample query objectType identifier", mineSample.objectType.identifier, theirsSample.objectType.identifier);
    RevenantHKCompare(@"sample query sampleType identifier", mineSample.sampleType.identifier, theirsSample.sampleType.identifier);
    RevenantHKCompareInt(@"sample query limit", (NSInteger)mineSample.limit, (NSInteger)theirsSample.limit);
    RevenantHKCompare(@"sample query sortDescriptors", mineSample.sortDescriptors, theirsSample.sortDescriptors);
    RevenantHKCompare(@"sample query predicate", mineSample.predicate, theirsSample.predicate);

    HKSampleQuery *theirsBare = [[HKSampleQuery alloc] initWithSampleType:stepCount
                                                                predicate:nil
                                                                    limit:HKObjectQueryNoLimit
                                                           sortDescriptors:nil
                                                            resultsHandler:nil];
    RevenantHostHKSampleQuery *mineBare = [[RevenantHostHKSampleQuery alloc] initWithSampleType:mineStepCount
                                                                                  predicate:nil
                                                                                      limit:HKObjectQueryNoLimit
                                                                           sortDescriptors:nil
                                                                            resultsHandler:nil];
    RevenantHKCompareInt(@"a bare sample query's limit", (NSInteger)mineBare.limit, (NSInteger)theirsBare.limit);
    RevenantHKCompare(@"a bare sample query's sortDescriptors", mineBare.sortDescriptors, theirsBare.sortDescriptors);
    RevenantHKCompare(@"a bare sample query's predicate", mineBare.predicate, theirsBare.predicate);
    RevenantHKCompare(@"a bare sample query's objectType identifier", mineBare.objectType.identifier,
                    theirsBare.objectType.identifier);

    HKStatisticsQuery *theirsStats = [[HKStatisticsQuery alloc] initWithQuantityType:heartRate
                                                          quantitySamplePredicate:predicate
                                                                           options:HKStatisticsOptionDiscreteAverage
                                                                    completionHandler:nil];
    RevenantHostHKStatisticsQuery *mineStats = [[RevenantHostHKStatisticsQuery alloc] initWithQuantityType:mineHeartRate
                                                                                        quantitySamplePredicate:predicate
                                                                                                     options:HKStatisticsOptionDiscreteAverage
                                                                                              completionHandler:nil];
    RevenantHKCompare(@"statistics query objectType identifier", mineStats.objectType.identifier,
                    theirsStats.objectType.identifier);
    RevenantHKCompare(@"statistics query predicate", mineStats.predicate, theirsStats.predicate);

    HKSourceQuery *theirsSource = [[HKSourceQuery alloc] initWithSampleType:stepCount
                                                             samplePredicate:predicate
                                                           completionHandler:nil];
    RevenantHostHKSourceQuery *mineSource = [[RevenantHostHKSourceQuery alloc] initWithSampleType:mineStepCount
                                                                                     samplePredicate:predicate
                                                                                   completionHandler:nil];
    RevenantHKCompare(@"source query objectType identifier", mineSource.objectType.identifier,
                    theirsSource.objectType.identifier);
    RevenantHKCompare(@"source query predicate", mineSource.predicate, theirsSource.predicate);
}


@interface RevenantHostHKStatistics : NSObject
@property (readonly, copy) RevenantHostHKQuantity *sumQuantity;
- (nullable RevenantHostHKQuantity *)mostRecentQuantity;
- (nullable RevenantHostHKQuantity *)mostRecentQuantityForSource:(RevenantHostHKSource *)source;
- (nullable NSDateInterval *)mostRecentQuantityDateInterval;
- (nullable NSDateInterval *)mostRecentQuantityDateIntervalForSource:(RevenantHostHKSource *)source;
+ (instancetype)revenant_statisticsForSamples:(NSArray *)samples options:(NSUInteger)options;
@end

@interface RevenantHostHKWorkoutConfiguration : NSObject
- (instancetype)revenant_initWithActivityType:(long)activityType
                                locationType:(long)locationType
                                  lapLength:(nullable HKQuantity *)lapLength
                        swimmingLocationType:(long)swimmingLocationType;
@property (readonly) long activityType;
@end

@interface RevenantHostRevenantHKStore : NSObject
+ (instancetype)sharedStore;
- (nullable NSArray *)objectsWithUUIDs:(NSArray<NSUUID *> *)uuids ofType:(HKObjectType *)type error:(NSError **)error;
@end

@interface RevenantHostHKHealthStore : NSObject
- (void)requestAuthorizationToShareTypes:(nullable NSSet<HKSampleType *> *)typesToShare
                               readTypes:(nullable NSSet<HKObjectType *> *)typesToRead
                              completion:(void (^)(BOOL success, NSError *error))completion;
- (void)saveObject:(HKObject *)object withCompletion:(void (^)(BOOL success, NSError *error))completion;
- (void)executeQuery:(HKQuery *)query;
- (HKAuthorizationStatus)authorizationStatusForType:(HKObjectType *)type;
@end

@interface RevenantHostHKWorkoutBuilder : NSObject
@property (readonly) NSTimeInterval duration;
@property (readonly, copy) RevenantHostHKQuantity *totalEnergyBurned;
- (instancetype)initWithHealthStore:(HKHealthStore *)healthStore
                      configuration:(HKWorkoutConfiguration *)configuration
                             device:(nullable HKDevice *)device;
@property (readonly, copy, nullable) HKDevice *device;
@property (readonly, copy, nullable) NSDate *startDate;
@property (readonly, copy, nullable) NSDate *endDate;
@property (readonly, copy) HKWorkoutConfiguration *workoutConfiguration;
@property (readonly, copy) NSDictionary<NSString *, id> *metadata;
@property (readonly, copy) NSArray<HKWorkoutEvent *> *workoutEvents;
- (void)beginCollectionWithStartDate:(NSDate *)startDate completion:(void (^)(BOOL, NSError *))completion;
- (void)addSamples:(NSArray<HKSample *> *)samples completion:(void (^)(BOOL, NSError *))completion;
- (void)addWorkoutEvents:(NSArray<HKWorkoutEvent *> *)workoutEvents completion:(void (^)(BOOL, NSError *))completion;
- (void)addMetadata:(NSDictionary<NSString *, id> *)metadata completion:(void (^)(BOOL, NSError *))completion;
- (void)endCollectionWithEndDate:(NSDate *)endDate completion:(void (^)(BOOL, NSError *))completion;
- (void)finishWorkoutWithCompletion:(void (^)(RevenantHostHKWorkout *, NSError *))completion;
- (void)discardWorkout;
- (NSTimeInterval)elapsedTimeAtDate:(NSDate *)date;
- (nullable HKStatistics *)statisticsForType:(HKQuantityType *)quantityType;
@end

static void RevenantHK11Group(void)
{
    HKSeriesType *theirsRoute = [HKSeriesType workoutRouteType];
    RevenantHostHKSeriesType *mineRoute = [RevenantHostHKSeriesType workoutRouteType];
    if (theirsRoute && mineRoute) {
        RevenantHKCompare(@"series workoutRouteType identifier", mineRoute.identifier, theirsRoute.identifier);
        RevenantHKCompare(@"series workoutRouteType twice is the same object",
                        @([HKSeriesType workoutRouteType] == [HKSeriesType workoutRouteType]),
                        @([RevenantHostHKSeriesType workoutRouteType] == [RevenantHostHKSeriesType workoutRouteType]));
    } else {
        printf("skipped: the host's HealthKit has no +[HKSeriesType workoutRouteType]\n");
    }

    HKSeriesType *theirsById = [HKObjectType seriesTypeForIdentifier:HKWorkoutRouteTypeIdentifier];
    RevenantHostHKSeriesType *mineById = [RevenantHostHKObjectType seriesTypeForIdentifier:HKWorkoutRouteTypeIdentifier];
    RevenantHKCompare(@"seriesTypeForIdentifier: the route type", mineById.identifier, theirsById.identifier);
    RevenantHKCompare(@"seriesTypeForIdentifier: an identifier that is not a series type",
                    [HKObjectType seriesTypeForIdentifier:@"HKQuantityTypeIdentifierStepCount"],
                    [RevenantHostHKObjectType seriesTypeForIdentifier:@"HKQuantityTypeIdentifierStepCount"]);

    HKClinicalType *theirsClinical = [HKObjectType clinicalTypeForIdentifier:HKClinicalTypeIdentifierConditionRecord];
    RevenantHostHKClinicalType *mineClinical = [RevenantHostHKObjectType clinicalTypeForIdentifier:HKClinicalTypeIdentifierConditionRecord];
    if (theirsClinical || mineClinical) {
        RevenantHKCompare(@"clinicalTypeForIdentifier: condition record", mineClinical.identifier, theirsClinical.identifier);
        RevenantHKCompare(@"clinicalTypeForIdentifier: an identifier that is not a clinical type",
                        [RevenantHostHKObjectType clinicalTypeForIdentifier:@"HKQuantityTypeIdentifierStepCount"],
                        [HKObjectType clinicalTypeForIdentifier:@"HKQuantityTypeIdentifierStepCount"]);
    } else {
        printf("skipped: the host's HealthKit has no clinical type of 11.0\n");
    }

    NSData *resourceData = [@"{\"resourceType\":\"Observation\"}" dataUsingEncoding:NSUTF8StringEncoding];
    NSURL *source = [NSURL URLWithString:@"https://example.org/1"];
    RevenantHostHKFHIRResource *mine =
        [RevenantHostHKFHIRResource revenant_resourceWithType:HKFHIRResourceTypeObservation
                                       identifier:@"obs-1"
                                             data:resourceData
                                        sourceURL:source];
    RevenantHKCompare(@"FHIRResource identifier", mine.identifier, @"obs-1");
    RevenantHKCompare(@"FHIRResource data", mine.data, resourceData);
    RevenantHKCompare(@"FHIRResource sourceURL", mine.sourceURL, source);
    NSData *mineFHIRArchive = [NSKeyedArchiver archivedDataWithRootObject:mine];
    RevenantHostHKFHIRResource *mineReadBack =
        (RevenantHostHKFHIRResource *)[NSKeyedUnarchiver unarchiveObjectWithData:mineFHIRArchive];
    RevenantHKCompare(@"FHIRResource archive round trip: data", mineReadBack.data, resourceData);
    RevenantHKCompare(@"FHIRResource archive round trip: identifier", mineReadBack.identifier, @"obs-1");
    RevenantHostHKFHIRResource *mineResourceCopy = (RevenantHostHKFHIRResource *)[mine copy];
    RevenantHKCompare(@"FHIRResource copy: identifier", mineResourceCopy.identifier, @"obs-1");
    RevenantHKCompare(@"HKFHIRResourceTypeObservation", HKFHIRResourceTypeObservation, @"Observation");
    RevenantHKCompare(@"HKFHIRResourceTypeCondition", HKFHIRResourceTypeCondition, @"Condition");
    RevenantHKCompare(@"HKFHIRResourceTypeImmunization", HKFHIRResourceTypeImmunization, @"Immunization");
    RevenantHKCompare(@"HKFHIRResourceTypeMedicationDispense", HKFHIRResourceTypeMedicationDispense, @"MedicationDispense");
    RevenantHKCompare(@"HKFHIRResourceTypeMedicationOrder", HKFHIRResourceTypeMedicationOrder, @"MedicationOrder");
    RevenantHKCompare(@"HKFHIRResourceTypeMedicationStatement", HKFHIRResourceTypeMedicationStatement, @"MedicationStatement");
    RevenantHKCompare(@"HKFHIRResourceTypeProcedure", HKFHIRResourceTypeProcedure, @"Procedure");
    RevenantHKCompare(@"HKFHIRResourceTypeAllergyIntolerance", HKFHIRResourceTypeAllergyIntolerance, @"AllergyIntolerance");
    RevenantHKCompare(@"HKPredicateKeyPathSum", HKPredicateKeyPathSum, @"quantity");
    RevenantHKCompare(@"HKPredicateKeyPathClinicalRecordFHIRResourceType", HKPredicateKeyPathClinicalRecordFHIRResourceType,
                    @"FHIRResource.resourceType");
    RevenantHKCompare(@"HKPredicateKeyPathClinicalRecordFHIRResourceIdentifier",
                    HKPredicateKeyPathClinicalRecordFHIRResourceIdentifier, @"FHIRResource.identifier");
    RevenantHKCompare(@"HKMetadataKeyCrossTrainerDistance", HKMetadataKeyCrossTrainerDistance, @"HKCrossTrainerDistance");
    RevenantHKCompare(@"HKMetadataKeyFitnessMachineDuration", HKMetadataKeyFitnessMachineDuration,
                    @"HKFitnessMachineDuration");
    RevenantHKCompare(@"HKMetadataKeyIndoorBikeDistance", HKMetadataKeyIndoorBikeDistance, @"HKIndoorBikeDistance");

    NSPredicate *theirsType = [HKQuery predicateForClinicalRecordsWithFHIRResourceType:HKFHIRResourceTypeObservation];
    NSPredicate *mineType = [RevenantHostHKQuery predicateForClinicalRecordsWithFHIRResourceType:HKFHIRResourceTypeObservation];
    RevenantHKCompare(@"predicateForClinicalRecordsWithFHIRResourceType: format", mineType.predicateFormat, theirsType.predicateFormat);
    NSPredicate *theirsBoth = [HKQuery predicateForClinicalRecordsFromSource:nil
                                                             FHIRResourceType:HKFHIRResourceTypeObservation
                                                                  identifier:@"obs-1"];
    NSPredicate *mineBoth = [RevenantHostHKQuery predicateForClinicalRecordsFromSource:nil
                                                           FHIRResourceType:HKFHIRResourceTypeObservation
                                                                identifier:@"obs-1"];
    RevenantHKCompare(@"predicateForClinicalRecordsFromSource: format", mineBoth.predicateFormat, theirsBoth.predicateFormat);
    RevenantHKCompare(@"predicateForClinicalRecordsFromSource: nothing given is nil",
                    [RevenantHostHKQuery predicateForClinicalRecordsFromSource:nil FHIRResourceType:nil identifier:nil],
                    [HKQuery predicateForClinicalRecordsFromSource:nil FHIRResourceType:nil identifier:nil]);

    RevenantHKCompare(@"internationalUnit unitString", [RevenantHostHKUnit internationalUnit].unitString,
                    [HKUnit internationalUnit].unitString);
    RevenantHKCompare(@"smallCalorieUnit unitString", [RevenantHostHKUnit smallCalorieUnit].unitString,
                    [HKUnit smallCalorieUnit].unitString);
    RevenantHKCompare(@"largeCalorieUnit unitString", [RevenantHostHKUnit largeCalorieUnit].unitString,
                    [HKUnit largeCalorieUnit].unitString);
    BOOL mineRefused = NO, theirsRefused = NO;
    double mineValue = 0.0, theirsValue = 0.0;
    @try {
        mineValue = [[RevenantHostHKQuantity quantityWithUnit:[RevenantHostHKUnit internationalUnit] doubleValue:1.0]
                        doubleValueForUnit:[RevenantHostHKUnit countUnit]];
    } @catch (NSException *exception) {
        mineRefused = YES;
    }
    @try {
        theirsValue = [[HKQuantity quantityWithUnit:[HKUnit internationalUnit] doubleValue:1.0]
                          doubleValueForUnit:[HKUnit countUnit]];
    } @catch (NSException *exception) {
        theirsRefused = YES;
    }
    RevenantHKCompareBool(@"internationalUnit into a count is refused on both sides", mineRefused, theirsRefused);
    if (!mineRefused && !theirsRefused)
        RevenantHKCompareDouble(@"internationalUnit in a count", mineValue, theirsValue);
    RevenantHKCompareDouble(@"smallCalorieUnit in a joule",
                          [[RevenantHostHKQuantity quantityWithUnit:[RevenantHostHKUnit smallCalorieUnit] doubleValue:1.0]
                              doubleValueForUnit:[RevenantHostHKUnit jouleUnit]],
                          [[HKQuantity quantityWithUnit:[HKUnit smallCalorieUnit] doubleValue:1.0]
                              doubleValueForUnit:[HKUnit jouleUnit]]);
    RevenantHKCompareDouble(@"largeCalorieUnit in a joule",
                          [[RevenantHostHKQuantity quantityWithUnit:[RevenantHostHKUnit largeCalorieUnit] doubleValue:1.0]
                              doubleValueForUnit:[RevenantHostHKUnit jouleUnit]],
                          [[HKQuantity quantityWithUnit:[HKUnit largeCalorieUnit] doubleValue:1.0]
                              doubleValueForUnit:[HKUnit jouleUnit]]);

    NSOperatingSystemVersion fifteenOneZero = {15, 1, 0};
    RevenantHostHKSourceRevision *mineRevision =
        [[RevenantHostHKSourceRevision alloc] initWithSource:[RevenantHostHKSource defaultSource]
                                                  version:@"1.0"
                                              productType:@"iPhone"
                                     operatingSystemVersion:fifteenOneZero];
    RevenantHKCompare(@"sourceRevision productType", mineRevision.productType, @"iPhone");
    RevenantHKCompareInt(@"sourceRevision operatingSystemVersion major",
                       (NSInteger)mineRevision.operatingSystemVersion.majorVersion, (NSInteger)15);
    RevenantHKCompareInt(@"sourceRevision operatingSystemVersion minor",
                       (NSInteger)mineRevision.operatingSystemVersion.minorVersion, (NSInteger)1);
    RevenantHKCompareInt(@"sourceRevision operatingSystemVersion patch",
                       (NSInteger)mineRevision.operatingSystemVersion.patchVersion, (NSInteger)0);
    NSData *revisionArchive = [NSKeyedArchiver archivedDataWithRootObject:mineRevision];
    RevenantHostHKSourceRevision *mineRevisionReadBack =
        (RevenantHostHKSourceRevision *)[NSKeyedUnarchiver unarchiveObjectWithData:revisionArchive];
    RevenantHKCompare(@"sourceRevision archive round trip: productType", mineRevisionReadBack.productType, mineRevision.productType);
    RevenantHKCompareInt(@"sourceRevision archive round trip: os major",
                       (NSInteger)mineRevisionReadBack.operatingSystemVersion.majorVersion,
                       (NSInteger)mineRevision.operatingSystemVersion.majorVersion);
    RevenantHKCompare(@"sourceRevision source bundle", mineRevisionReadBack.source.bundleIdentifier,
                    mineRevision.source.bundleIdentifier);
    RevenantHKCompare(@"HKSourceRevisionAnyVersion", HKSourceRevisionAnyVersion, @"HKSourceRevisionAnyVersion");
    RevenantHKCompare(@"HKSourceRevisionAnyProductType", HKSourceRevisionAnyProductType, @"HKSourceRevisionAnyProductType");

    NSDate *periodStart = [NSDate dateWithTimeIntervalSince1970:1600000000];
    NSDate *periodEnd = [NSDate dateWithTimeIntervalSince1970:1600003600];
    NSDateInterval *period = [[NSDateInterval alloc] initWithStartDate:periodStart endDate:periodEnd];
    BOOL theirsThrew = NO, mineThrew = NO;
    HKWorkoutEvent *theirsEvent = nil;
    RevenantHostHKWorkoutEvent *mineEvent = nil;
    @try {
        theirsEvent = [HKWorkoutEvent workoutEventWithType:HKWorkoutEventTypePause dateInterval:period metadata:nil];
    } @catch (NSException *exception) {
        theirsThrew = YES;
    }
    @try {
        mineEvent = [RevenantHostHKWorkoutEvent workoutEventWithType:HKWorkoutEventTypePause dateInterval:period metadata:nil];
    } @catch (NSException *exception) {
        mineThrew = YES;
    }
    if (theirsThrew && !mineThrew)
        printf("not compared: the host refuses an hour-long HKWorkoutEventTypePause period and this library does not "
               "implement the per-type duration bounds, which are Apple's and in no SDK header\n");
    if (theirsEvent && mineEvent) {
        RevenantHKCompareInt(@"workout event type", (NSInteger)mineEvent.type, (NSInteger)theirsEvent.type);
        RevenantHKCompare(@"workout event dateInterval start", mineEvent.dateInterval.startDate,
                        theirsEvent.dateInterval.startDate);
        RevenantHKCompare(@"workout event dateInterval end", mineEvent.dateInterval.endDate, theirsEvent.dateInterval.endDate);
        RevenantHKCompare(@"workout event date", mineEvent.date, theirsEvent.date);
        RevenantHKCompareInt(@"workout event metadata is nil", (NSInteger)(mineEvent.metadata != nil),
                           (NSInteger)(theirsEvent.metadata != nil));
    } else {
        printf("skipped: the host's HealthKit has no -workoutEventWithType:dateInterval:metadata:\n");
    }
    BOOL mineEventRefused = NO, theirsEventRefused = NO;
    @try {
        [RevenantHostHKWorkoutEvent workoutEventWithType:HKWorkoutEventTypePause dateInterval:nil metadata:nil];
    } @catch (NSException *exception) {
        mineEventRefused = YES;
    }
    @try {
        [HKWorkoutEvent workoutEventWithType:HKWorkoutEventTypePause dateInterval:nil metadata:nil];
    } @catch (NSException *exception) {
        theirsEventRefused = YES;
    }
    RevenantHKCompareBool(@"a workout event over a period that is not one raises", mineEventRefused, theirsEventRefused);

    NSDate *start = [NSDate dateWithTimeIntervalSince1970:1600000000];
    NSDate *end = [NSDate dateWithTimeIntervalSince1970:1600003600];
    RevenantHostHKQuantity *mineFlights = [RevenantHostHKQuantity quantityWithUnit:[RevenantHostHKUnit countUnit] doubleValue:17.0];
    RevenantHostHKQuantity *mineEnergy = [RevenantHostHKQuantity quantityWithUnit:[RevenantHostHKUnit kilocalorieUnit] doubleValue:400.0];
    RevenantHostHKQuantity *mineDistance = [RevenantHostHKQuantity quantityWithUnit:[RevenantHostHKUnit meterUnit] doubleValue:5000.0];
    HKQuantity *flights = [HKQuantity quantityWithUnit:[HKUnit countUnit] doubleValue:17.0];
    HKQuantity *energy = [HKQuantity quantityWithUnit:[HKUnit kilocalorieUnit] doubleValue:400.0];
    HKQuantity *distance = [HKQuantity quantityWithUnit:[HKUnit meterUnit] doubleValue:5000.0];
    HKWorkout *theirsWorkout = [HKWorkout workoutWithActivityType:HKWorkoutActivityTypeRunning
                                                          startDate:start
                                                            endDate:end
                                                     workoutEvents:theirsEvent ? @[ theirsEvent ] : @[]
                                                totalEnergyBurned:energy
                                                  totalDistance:distance
                                         totalFlightsClimbed:flights
                                                            device:nil
                                                          metadata:nil];
    RevenantHostHKWorkout *mineWorkout = [RevenantHostHKWorkout workoutWithActivityType:HKWorkoutActivityTypeRunning
                                                                           startDate:start
                                                                             endDate:end
                                                                      workoutEvents:mineEvent ? @[ mineEvent ] : @[]
                                                                 totalEnergyBurned:mineEnergy
                                                                   totalDistance:mineDistance
                                                          totalFlightsClimbed:mineFlights
                                                                             device:nil
                                                                           metadata:nil];
    RevenantHKCompareInt(@"workout activity type", (NSInteger)mineWorkout.workoutActivityType, (NSInteger)theirsWorkout.workoutActivityType);
    RevenantHKCompare(@"workout startDate", mineWorkout.startDate, theirsWorkout.startDate);
    RevenantHKCompare(@"workout endDate", mineWorkout.endDate, theirsWorkout.endDate);
    RevenantHKCompare(@"workout duration", @(mineWorkout.duration), @(theirsWorkout.duration));
    if (theirsEvent)
        RevenantHKCompare(@"workout events", @(mineWorkout.workoutEvents.count), @(theirsWorkout.workoutEvents.count));
    else
        printf("not compared: the host's workout carries no event, its HealthKit having no -workoutEventWithType:dateInterval:metadata:, so there is no count of its own to compare with\n");
    RevenantHKCompareDouble(@"workout totalEnergyBurned", [mineWorkout.totalEnergyBurned doubleValueForUnit:[RevenantHostHKUnit kilocalorieUnit]],
                          [theirsWorkout.totalEnergyBurned doubleValueForUnit:[HKUnit kilocalorieUnit]]);
    RevenantHKCompareDouble(@"workout totalDistance", [mineWorkout.totalDistance doubleValueForUnit:[RevenantHostHKUnit meterUnit]],
                          [theirsWorkout.totalDistance doubleValueForUnit:[HKUnit meterUnit]]);
    if (mineWorkout.totalFlightsClimbed && theirsWorkout.totalFlightsClimbed)
        RevenantHKCompareDouble(@"workout totalFlightsClimbed",
                              [mineWorkout.totalFlightsClimbed doubleValueForUnit:[RevenantHostHKUnit countUnit]],
                              [theirsWorkout.totalFlightsClimbed doubleValueForUnit:[HKUnit countUnit]]);
    else
        printf("skipped: the host's workout carries no flights climbed\n");
    RevenantHostHKWorkout *mineWorkoutReadBack =
        (RevenantHostHKWorkout *)[NSKeyedUnarchiver unarchiveObjectWithData:[NSKeyedArchiver archivedDataWithRootObject:mineWorkout]];
    HKWorkout *theirsWorkoutReadBack = [NSKeyedUnarchiver unarchiveObjectWithData:[NSKeyedArchiver archivedDataWithRootObject:theirsWorkout]];
    RevenantHKCompare(@"workout archive round trip: duration", @(mineWorkoutReadBack.duration), @(theirsWorkoutReadBack.duration));
    if (mineWorkoutReadBack.totalFlightsClimbed && theirsWorkoutReadBack.totalFlightsClimbed)
        RevenantHKCompareDouble(@"workout archive round trip: flights climbed",
                              [mineWorkoutReadBack.totalFlightsClimbed doubleValueForUnit:[RevenantHostHKUnit countUnit]],
                              [theirsWorkoutReadBack.totalFlightsClimbed doubleValueForUnit:[HKUnit countUnit]]);
}


static void RevenantHKWaitForAnswer(volatile BOOL *answered)
{
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:1.0];
    while (!*answered && [deadline timeIntervalSinceNow] > 0)
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
}

@interface RevenantHostHKQuantitySample : NSObject
+ (instancetype)quantitySampleWithType:(RevenantHostHKQuantityType *)type
                             quantity:(RevenantHostHKQuantity *)quantity
                            startDate:(NSDate *)startDate
                              endDate:(NSDate *)endDate;
@property (readonly, copy) HKQuantityType *sampleType;
@property (readonly, copy) NSDate *startDate;
@property (readonly, copy) NSDate *endDate;
@property (readonly, copy) RevenantHostHKQuantity *quantity;
@property (readonly, copy) NSUUID *UUID;
@end

@interface RevenantHostHKQuantitySeriesSampleBuilder : NSObject
- (instancetype)initWithHealthStore:(HKHealthStore *)healthStore
                       quantityType:(HKQuantityType *)quantityType
                          startDate:(NSDate *)startDate
                             device:(nullable HKDevice *)device;
@property (readonly, copy) HKQuantityType *quantityType;
@property (readonly, copy) NSDate *startDate;
@property (readonly, copy, nullable) HKDevice *device;
- (BOOL)insertQuantity:(HKQuantity *)quantity date:(NSDate *)date error:(NSError **)error;
- (void)finishSeriesWithMetadata:(nullable NSDictionary<NSString *, id> *)metadata
                      completion:(void (^)(NSArray *samples, NSError *error))completion;
- (void)discard;
@end

@interface RevenantHostHKQuantitySeriesSampleQuery : NSObject
- (instancetype)initWithSample:(RevenantHostHKQuantitySample *)quantitySample
               quantityHandler:(void (^)(RevenantHostHKQuantitySeriesSampleQuery *query,
                                        RevenantHostHKQuantity *_Nullable quantity,
                                        NSDate *_Nullable date, BOOL done, NSError *error))quantityHandler;
@end

static void RevenantHKWaitFor(volatile BOOL *answered)
{
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:2.0];
    while (!*answered && [deadline timeIntervalSinceNow] > 0)
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
}

static void RevenantHKInstallClassResolver(void)
{
    RevenantHKSetClassResolver(^Class(NSString *name) {
        return NSClassFromString([@"RevenantHost" stringByAppendingString:name]);
    });
}

static void RevenantHKWorkoutBuilder12(void)
{
    NSDate *start = [NSDate dateWithTimeIntervalSince1970:1600000000];
    NSDate *end = [NSDate dateWithTimeIntervalSince1970:1600003600];

    HKWorkoutConfiguration *theirsConfiguration = [[HKWorkoutConfiguration alloc] init];
    theirsConfiguration.activityType = HKWorkoutActivityTypeRunning;
    RevenantHostHKWorkoutConfiguration *mineConfiguration =
        [[RevenantHostHKWorkoutConfiguration alloc] revenant_initWithActivityType:HKWorkoutActivityTypeRunning
                                                                  locationType:0
                                                                    lapLength:nil
                                                          swimmingLocationType:0];
    HKHealthStore *theirsStore = [[HKHealthStore alloc] init];
    RevenantHostHKHealthStore *mineStore = [[RevenantHostHKHealthStore alloc] init];

    HKWorkoutBuilder *theirs = [[HKWorkoutBuilder alloc] initWithHealthStore:theirsStore
                                                                configuration:theirsConfiguration
                                                                       device:nil];
    RevenantHostHKWorkoutBuilder *mine = [[RevenantHostHKWorkoutBuilder alloc] initWithHealthStore:mineStore
                                                                              configuration:mineConfiguration
                                                                                     device:nil];
    RevenantHKCompareBool(@"the builder's initialiser answers", !!mine, !!theirs);
    if (!mine || !theirs)
        return;

    RevenantHKCompareBool(@"builder answers a configuration", !!mine.workoutConfiguration, !!theirs.workoutConfiguration);
    RevenantHKCompare(@"builder configuration activityType",
                    @(mine.workoutConfiguration.activityType), @(theirs.workoutConfiguration.activityType));
    RevenantHKCompare(@"builder device is nil", mine.device, theirs.device);
    RevenantHKCompare(@"builder startDate is nil", mine.startDate, theirs.startDate);
    RevenantHKCompare(@"builder endDate is nil", mine.endDate, theirs.endDate);
    RevenantHKCompareInt(@"builder metadata is empty", (NSInteger)mine.metadata.count, (NSInteger)theirs.metadata.count);
    RevenantHKCompareInt(@"builder workoutEvents is empty", (NSInteger)mine.workoutEvents.count, (NSInteger)theirs.workoutEvents.count);

    RevenantHKCompareDouble(@"elapsedTimeAtDate: with no period begun", [mine elapsedTimeAtDate:end],
                          [theirs elapsedTimeAtDate:end]);

    __block BOOL mineEmptyRefused = NO, theirsEmptyRefused = NO;
    __block BOOL mineEmptyAnswered = NO, theirsEmptyAnswered = NO;
    __block NSInteger mineEmptyCode = -1, theirsEmptyCode = -1;
    __block NSString *mineEmptyMessage = nil, *theirsEmptyMessage = nil;
    [mine addSamples:@[] completion:^(BOOL success, NSError *error) {
        mineEmptyRefused = (error != nil);
        mineEmptyCode = (NSInteger)error.code; mineEmptyMessage = error.localizedDescription;
        mineEmptyAnswered = YES;
    }];
    [theirs addSamples:@[] completion:^(BOOL success, NSError *error) {
        theirsEmptyRefused = (error != nil);
        theirsEmptyCode = (NSInteger)error.code; theirsEmptyMessage = error.localizedDescription;
        theirsEmptyAnswered = YES;
    }];
    RevenantHKWaitForAnswer(&theirsEmptyAnswered);
    RevenantHKWaitForAnswer(&mineEmptyAnswered);
    RevenantHKCompareBool(@"addSamples: an empty array is refused on both sides", mineEmptyRefused, theirsEmptyRefused);
    RevenantHKCompare(@"addSamples: the refusal's domain", mineEmptyRefused ? @"com.apple.healthkit" : nil,
                    theirsEmptyRefused ? @"com.apple.healthkit" : nil);
    RevenantHKCompareInt(@"addSamples: the refusal's code", mineEmptyCode, theirsEmptyCode);
    RevenantHKCompare(@"addSamples: the refusal's wording", mineEmptyMessage, theirsEmptyMessage);

    __block BOOL mineBegan = NO, theirsBeganRan = NO;
    [mine beginCollectionWithStartDate:start completion:^(BOOL success, NSError *error) { mineBegan = success; }];
    [theirs beginCollectionWithStartDate:start completion:^(BOOL success, NSError *error) { theirsBeganRan = YES; }];
    RevenantHKCompare(@"builder startDate after begin", mine.startDate, mineBegan ? mine.startDate : nil);
    if (mineBegan)
        RevenantHKCompareDouble(@"elapsedTimeAtDate: over the port's own period", [mine elapsedTimeAtDate:end],
                              [end timeIntervalSinceDate:start]);
    RevenantHKCompareDouble(@"elapsedTimeAtDate: half way through the port's own period",
                          [mine elapsedTimeAtDate:[start dateByAddingTimeInterval:1800]], 1800.0);
    printf("not compared: the period and everything in it - addSamples:, addWorkoutEvents:, addMetadata:, "
           "endCollectionWithEndDate:, finishWorkoutWithCompletion:, discardWorkout, statisticsForType: "
           "and the startDate of a begun period. The host's HealthKit on this machine answers every call "
           "that touches health data with com.apple.healthkit 1, \"Health data is unavailable on this "
           "device\" and its -beginCollectionWithStartDate: completion never runs, so there is no answer "
           "of its own on that side to compare with.\n");
    NSDate *otherStart = [start dateByAddingTimeInterval:7200];
    __block BOOL mineSecondBegin = NO;
    [mine beginCollectionWithStartDate:otherStart completion:^(BOOL success, NSError *error) { mineSecondBegin = success; }];
    RevenantHKCompareBool(@"a second begin is refused", mineSecondBegin, NO);
    RevenantHKCompare(@"a second begin does not move the period", mine.startDate, start);

    if (!theirsBeganRan)
        printf("measured: the host's -beginCollectionWithStartDate: completion did not run, and its startDate is %s\n",
               theirs.startDate ? "set" : "nil");
}

static void RevenantHKSeriesBuilder12(void)
{
    NSDate *start = [NSDate dateWithTimeIntervalSince1970:1600000000];
    HKQuantityType *theirsType = [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierHeartRate];
    RevenantHostHKQuantityType *mineType = [RevenantHostHKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierHeartRate];
    HKHealthStore *theirsStore = [[HKHealthStore alloc] init];
    RevenantHostHKHealthStore *mineStore = [[RevenantHostHKHealthStore alloc] init];

    HKQuantitySeriesSampleBuilder *theirs = [[HKQuantitySeriesSampleBuilder alloc] initWithHealthStore:theirsStore
                                                                                          quantityType:theirsType
                                                                                             startDate:start
                                                                                                device:nil];
    RevenantHostHKQuantitySeriesSampleBuilder *mine = [[RevenantHostHKQuantitySeriesSampleBuilder alloc] initWithHealthStore:mineStore
                                                                                                          quantityType:mineType
                                                                                                             startDate:start
                                                                                                                device:nil];
    RevenantHKCompareBool(@"the series builder's initialiser answers", !!mine, !!theirs);
    if (!mine || !theirs)
        return;

    RevenantHKCompare(@"series builder quantityType", mine.quantityType.identifier, theirs.quantityType.identifier);
    RevenantHKCompare(@"series builder startDate", mine.startDate, theirs.startDate);
    RevenantHKCompare(@"series builder device is nil", mine.device, theirs.device);

    HKQuantity *theirsWrong = [HKQuantity quantityWithUnit:[HKUnit meterUnit] doubleValue:5.0];
    RevenantHostHKQuantity *mineWrong = [RevenantHostHKQuantity quantityWithUnit:[RevenantHostHKUnit meterUnit] doubleValue:5.0];
    NSError *theirsError = nil, *mineError = nil;
    BOOL theirsWrongOK = [theirs insertQuantity:theirsWrong date:start error:&theirsError];
    BOOL mineWrongOK = [mine insertQuantity:mineWrong date:start error:&mineError];
    RevenantHKCompareBool(@"a unit the type does not accept is refused", mineWrongOK, theirsWrongOK);
    RevenantHKCompare(@"the unit refusal's domain", mineError.domain, theirsError.domain);
    RevenantHKCompareInt(@"the unit refusal's code", (NSInteger)mineError.code, (NSInteger)theirsError.code);
    RevenantHKCompare(@"the unit refusal's wording", mineError.localizedDescription, theirsError.localizedDescription);

    HKQuantity *theirsBeat = [HKQuantity quantityWithUnit:[HKUnit unitFromString:@"count/min"] doubleValue:60.0];
    RevenantHostHKQuantity *mineBeat = [RevenantHostHKQuantity quantityWithUnit:[RevenantHostHKUnit unitFromString:@"count/min"] doubleValue:60.0];
    NSDate *earlier = [start dateByAddingTimeInterval:-60];
    theirsError = nil; mineError = nil;
    BOOL theirsEarlyOK = [theirs insertQuantity:theirsBeat date:earlier error:&theirsError];
    BOOL mineEarlyOK = [mine insertQuantity:mineBeat date:earlier error:&mineError];
    RevenantHKCompareBool(@"a date before the start is refused", mineEarlyOK, theirsEarlyOK);
    RevenantHKCompareInt(@"the date refusal's code", (NSInteger)mineError.code, (NSInteger)theirsError.code);
    NSString *theirsTail = [theirsError.localizedDescription hasSuffix:[NSString stringWithFormat:@"is before builder's start date %@", start]]
                             ? [NSString stringWithFormat:@"is before builder's start date %@", start] : theirsError.localizedDescription;
    RevenantHKCompare(@"the date refusal's stable tail",
                    [mineError.localizedDescription hasSuffix:theirsTail] ? theirsTail : mineError.localizedDescription,
                    theirsTail);
    printf("not compared: the whole of the date refusal's wording. The host writes %s\n",
           theirsError.localizedDescription.UTF8String);

    theirsError = nil; mineError = nil;
    BOOL theirsGoodOK = [theirs insertQuantity:theirsBeat date:start error:&theirsError];
    BOOL mineGoodOK = [mine insertQuantity:mineBeat date:start error:&mineError];
    RevenantHKCompareBool(@"a unit the type accepts is taken", mineGoodOK, theirsGoodOK);

    __block NSArray *theirsSamples = nil;
    __block NSError *theirsFinishError = nil;
    __block BOOL theirsFinishRan = NO;
    [theirs finishSeriesWithMetadata:@{ @"k" : @"v" } completion:^(NSArray<HKQuantitySample *> *samples, NSError *error) {
        theirsFinishRan = YES; theirsSamples = samples; theirsFinishError = error;
    }];
    [mine finishSeriesWithMetadata:@{ @"k" : @"v" } completion:^(NSArray *samples, NSError *error) {}];
    RevenantHKWaitForAnswer(&theirsFinishRan);
    RevenantHKCompare(@"the finish's domain", @"com.apple.healthkit", theirsFinishError.domain);
    RevenantHKCompareInt(@"the finish's code", (NSInteger)1, (NSInteger)theirsFinishError.code);
    printf("not compared: what -finishSeriesWithMetadata:completion: returns for a series. The host "
           "answers it with samples nil and %s, having an entitlement this machine does not give it, so "
           "the shape of the samples is this port's own reading of the header and the device test is what "
           "would settle it.\n", theirsFinishError.localizedDescription.UTF8String);

    theirsError = nil; mineError = nil;
    BOOL theirsAfterFinish = [theirs insertQuantity:theirsBeat date:start error:&theirsError];
    BOOL mineAfterFinish = [mine insertQuantity:mineBeat date:start error:&mineError];
    RevenantHKCompareBool(@"an insert after the finish is refused", mineAfterFinish, theirsAfterFinish);
    RevenantHKCompare(@"the finished refusal's wording", mineError.localizedDescription, theirsError.localizedDescription);

    HKQuantitySeriesSampleBuilder *theirsDiscarded = [[HKQuantitySeriesSampleBuilder alloc] initWithHealthStore:theirsStore
                                                                                                 quantityType:theirsType
                                                                                                    startDate:start
                                                                                                       device:nil];
    RevenantHostHKQuantitySeriesSampleBuilder *mineDiscarded = [[RevenantHostHKQuantitySeriesSampleBuilder alloc] initWithHealthStore:mineStore
                                                                                                                   quantityType:mineType
                                                                                                                      startDate:start
                                                                                                                         device:nil];
    [theirsDiscarded discard];
    [mineDiscarded discard];
    BOOL theirsRaised = NO, mineRaised = NO;
    NSString *theirsText = nil, *mineText = nil;
    @try { [theirsDiscarded insertQuantity:theirsBeat date:start error:NULL]; }
    @catch (NSException *exception) { theirsRaised = YES; theirsText = exception.reason; }
    @try { [mineDiscarded insertQuantity:mineBeat date:start error:NULL]; }
    @catch (NSException *exception) { mineRaised = YES; mineText = exception.reason; }
    RevenantHKCompareBool(@"an insert after a discard raises on both sides", mineRaised, theirsRaised);
    RevenantHKCompare(@"the raise's text", mineText, theirsText);
}

@interface RevenantHostHKCumulativeQuantitySeriesSample : NSObject
+ (instancetype)revenant_seriesWithType:(RevenantHostHKQuantityType *)quantityType
                                 sum:(RevenantHostHKQuantity *)sum
                            startDate:(NSDate *)startDate
                              endDate:(NSDate *)endDate;
@property (readonly, copy) RevenantHostHKQuantity *sum;
@property (readonly, copy) RevenantHostHKQuantity *sumQuantity;
@property (readonly, copy) NSUUID *UUID;
@end

@interface RevenantHostHKCumulativeQuantitySample : NSObject
+ (instancetype)revenant_cumulativeWithType:(RevenantHostHKQuantityType *)quantityType
                                      sum:(RevenantHostHKQuantity *)sum
                                 startDate:(NSDate *)startDate
                                   endDate:(NSDate *)endDate;
@property (readonly, copy) RevenantHostHKQuantity *sumQuantity;
@property (readonly, copy) RevenantHostHKQuantityType *sampleType;
@property (readonly, copy) NSDate *startDate;
@property (readonly, copy) NSDate *endDate;
@property (readonly, copy) NSUUID *UUID;
@end

static void RevenantHKSeriesQuery12(void)
{
    NSDate *start = [NSDate dateWithTimeIntervalSince1970:1600000000];
    NSDate *end = [NSDate dateWithTimeIntervalSince1970:1600000060];
    HKQuantityType *theirsType = [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierHeartRate];
    RevenantHostHKQuantityType *mineType = [RevenantHostHKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierHeartRate];
    HKHealthStore *theirsStore = [[HKHealthStore alloc] init];
    RevenantHostHKHealthStore *mineStore = [[RevenantHostHKHealthStore alloc] init];

    HKQuantitySample *theirsSample = [HKQuantitySample quantitySampleWithType:theirsType
                                                                     quantity:[HKQuantity quantityWithUnit:[HKUnit unitFromString:@"count/min"] doubleValue:60.0]
                                                                    startDate:start endDate:end device:nil metadata:nil];
    __block NSInteger theirsCalls = 0, theirsDone = 0;
    __block BOOL theirsHadQuantity = YES, theirsHadDate = YES;
    __block NSError *theirsError = nil;
    HKQuantitySeriesSampleQuery *theirs = [[HKQuantitySeriesSampleQuery alloc] initWithSample:theirsSample
                                                                              quantityHandler:^(HKQuantitySeriesSampleQuery *query, HKQuantity *quantity, NSDate *date, BOOL done, NSError *error) {
        theirsCalls++;
        if (quantity == nil) theirsHadQuantity = NO;
        if (date == nil) theirsHadDate = NO;
        if (done) theirsDone++;
        if (error) theirsError = error;
    }];
    RevenantHKCompareBool(@"the host's series query answers", !!theirs, YES);
    if (theirs) {
        [theirsStore executeQuery:theirs];
        NSDate *until = [NSDate dateWithTimeIntervalSinceNow:2.0];
        while (theirsCalls == 0 && [until timeIntervalSinceNow] > 0)
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
        RevenantHKCompareInt(@"the host calls the handler once", (NSInteger)theirsCalls, (NSInteger)1);
        RevenantHKCompareBool(@"the host's call is finished", theirsDone > 0, YES);
        RevenantHKCompareBool(@"the host hands over no quantity", theirsHadQuantity, NO);
        RevenantHKCompareBool(@"the host hands over no date", theirsHadDate, NO);
        RevenantHKCompare(@"the host's error domain", theirsError.domain, @"com.apple.healthkit");
        RevenantHKCompareInt(@"the host's error code", (NSInteger)theirsError.code, (NSInteger)1);
    }
    printf("not compared: the quantities the host's query delivers and the date each is reported at. Its "
           "HealthKit answers %s, so there is no delivery of its own to compare with; the port's delivery "
           "is compared against the sample and the dates this harness built below.\n",
           theirsError.localizedDescription.UTF8String);

    __block BOOL queryAuthorised = NO;
    [mineStore requestAuthorizationToShareTypes:[NSSet setWithObject:mineType]
                                       readTypes:[NSSet setWithObject:mineType]
                                      completion:^(BOOL success, NSError *error) { queryAuthorised = success; }];
    RevenantHKWaitFor(&queryAuthorised);
    if (!queryAuthorised) {
        printf("skipped: the port's store was not authorised for the type this query saves\n");
        return;
    }

    RevenantHostHKQuantity *mineQuantity = [RevenantHostHKQuantity quantityWithUnit:[RevenantHostHKUnit unitFromString:@"count/min"] doubleValue:60.0];
    RevenantHostHKQuantitySample *mineSample = [RevenantHostHKQuantitySample quantitySampleWithType:mineType
                                                                                        quantity:mineQuantity
                                                                                       startDate:start
                                                                                         endDate:end];
    __block BOOL mineSaved = NO;
    __block NSError *mineSaveError = nil;
    [mineStore saveObject:mineSample withCompletion:^(BOOL success, NSError *error) { mineSaved = success; mineSaveError = error; }];
    RevenantHKWaitForAnswer((volatile BOOL *)&mineSaved);
    if (!mineSaved) {
        printf("skipped: the port's store did not take the sample (%s), so the series query has nothing to deliver\n",
               mineSaveError ? [[NSString stringWithFormat:@"%@ %ld %@", mineSaveError.domain,
                                 (long)mineSaveError.code, mineSaveError.localizedDescription] UTF8String] : "(no error)");
        return;
    }

    __block NSInteger mineCalls = 0, mineDone = 0, mineWithQuantity = 0;
    __block BOOL mineDoneWasLast = NO, mineDoneSeen = NO;
    __block RevenantHostHKQuantity *mineDelivered = nil;
    __block NSDate *mineDate = nil;
    RevenantHostHKQuantitySeriesSampleQuery *mine = [[RevenantHostHKQuantitySeriesSampleQuery alloc] initWithSample:mineSample
                                                                                                   quantityHandler:^(RevenantHostHKQuantitySeriesSampleQuery *query, RevenantHostHKQuantity *quantity, NSDate *date, BOOL done, NSError *error) {
        mineCalls++;
        if (quantity) { mineDelivered = quantity; mineWithQuantity++; mineDate = date; }
        if (done) { mineDone++; mineDoneSeen = YES; mineDoneWasLast = YES; }
        else mineDoneWasLast = NO;
    }];
    [mineStore executeQuery:mine];
    NSDate *mineUntil = [NSDate dateWithTimeIntervalSinceNow:2.0];
    while (mineCalls == 0 && [mineUntil timeIntervalSinceNow] > 0)
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];

    RevenantHKCompareInt(@"the port delivers the sample's one quantity", (NSInteger)mineWithQuantity, (NSInteger)1);
    RevenantHKCompareInt(@"the port finishes with one done", (NSInteger)mineDone, (NSInteger)1);
    RevenantHKCompareInt(@"the port calls the handler once per quantity and once for done", (NSInteger)mineCalls, (NSInteger)2);
    RevenantHKCompareBool(@"the port's done is its last call", mineDoneSeen && mineDoneWasLast, YES);
    RevenantHKCompare(@"the quantity delivered is the one the sample holds", mineDelivered, mineSample.quantity);
    RevenantHKCompareDouble(@"the quantity's value in the unit it was given",
                          [mineDelivered doubleValueForUnit:[RevenantHostHKUnit unitFromString:@"count/min"]], 60.0);
    RevenantHKCompare(@"the date delivered is the sample's start, not its end", mineDate, start);
}

static void RevenantHKDefaultResolver(void)
{
    const char *names[] = { "HKCategorySample", "HKQuantitySample", "HKCorrelation", "HKWorkout", "HKClinicalRecord" };
    for (NSInteger kind = 0; kind < 5; kind++) {
        Class byKind = RevenantHKClassForObjectKind(kind);
        Class byName = NSClassFromString([NSString stringWithUTF8String:names[kind]]);
        RevenantHKCompare(@"the default resolver answers the runtime's own class for a kind",
                        byKind, byName);
    }
    RevenantHKCompare(@"kind 0 is the category sample", RevenantHKClassForObjectKind(0), NSClassFromString(@"HKCategorySample"));
    RevenantHKCompare(@"kind 1 is the quantity sample", RevenantHKClassForObjectKind(1), NSClassFromString(@"HKQuantitySample"));
    RevenantHKCompare(@"kind 2 is the correlation", RevenantHKClassForObjectKind(2), NSClassFromString(@"HKCorrelation"));
    RevenantHKCompare(@"kind 3 is the workout", RevenantHKClassForObjectKind(3), NSClassFromString(@"HKWorkout"));
    RevenantHKCompare(@"kind 4 is the clinical record", RevenantHKClassForObjectKind(4), NSClassFromString(@"HKClinicalRecord"));
    RevenantHKCompare(@"a kind the table does not hold answers nothing", RevenantHKClassForObjectKind(9), Nil);
}

static void RevenantHKStoreRoundTrip(void)
{
    NSDate *start = [NSDate dateWithTimeIntervalSince1970:1600000000];
    NSDate *end = [NSDate dateWithTimeIntervalSince1970:1600000060];
    RevenantHostHKHealthStore *store = [[RevenantHostHKHealthStore alloc] init];
    RevenantHostHKQuantityType *energy = [RevenantHostHKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierActiveEnergyBurned];
    RevenantHostHKWorkoutType *workoutType = [RevenantHostHKObjectType workoutType];

    __block BOOL authorised = NO;
    [store requestAuthorizationToShareTypes:[NSSet setWithObjects:energy, workoutType, nil]
                                  readTypes:[NSSet setWithObjects:energy, workoutType, nil]
                                 completion:^(BOOL success, NSError *error) { authorised = success; }];
    RevenantHKWaitFor(&authorised);
    RevenantHKCompareBool(@"the store is asked for what it writes", authorised, YES);
    if (!authorised) {
        printf("the port's store granted no authorisation, so the round trip cannot be measured here\n");
        return;
    }

    RevenantHostRevenantHKStore *database = [RevenantHostRevenantHKStore sharedStore];
    RevenantHostHKQuantity *quantity = [RevenantHostHKQuantity quantityWithUnit:[RevenantHostHKUnit kilocalorieUnit] doubleValue:250.0];
    RevenantHostHKQuantitySample *sample = [RevenantHostHKQuantitySample quantitySampleWithType:energy
                                                                                   quantity:quantity
                                                                                  startDate:start
                                                                                    endDate:end];
    RevenantHKCompare(@"the type the request named is the type the sample is saved under", energy.identifier, sample.sampleType.identifier);
    RevenantHKCompareInt(@"the store's own status for the type it was asked for", (NSInteger)[store authorizationStatusForType:energy], (NSInteger)2);

    __block BOOL saved = NO;
    __block NSError *saveError = nil;
    [store saveObject:sample withCompletion:^(BOOL success, NSError *error) { saved = success; saveError = error; }];
    RevenantHKWaitFor(&saved);
    if (!saved) {
        printf("the port's store took no quantity sample: %s\n", saveError.localizedDescription.UTF8String);
    }
    RevenantHKCompareBool(@"the store keeps a quantity sample", saved, YES);
    if (saved) {
        NSError *readError = nil;
        NSArray *found = [database objectsWithUUIDs:@[ sample.UUID ] ofType:energy error:&readError];
        RevenantHKCompareInt(@"the saved sample is found again", (NSInteger)found.count, (NSInteger)1);
        RevenantHostHKQuantitySample *back = found.firstObject;
        if (back) {
            RevenantHKCompare(@"the sample read back has the UUID it was saved with", back.UUID, sample.UUID);
            RevenantHKCompare(@"the sample read back has the type it was saved with", back.sampleType.identifier, energy.identifier);
            RevenantHKCompare(@"the sample read back has its start date", back.startDate, start);
            RevenantHKCompare(@"the sample read back has its end date", back.endDate, end);
            RevenantHKCompareDouble(@"the sample read back has its quantity",
                                  [back.quantity doubleValueForUnit:[RevenantHostHKUnit kilocalorieUnit]], 250.0);
        }
    }

    RevenantHostHKWorkoutBuilder *builder = [[RevenantHostHKWorkoutBuilder alloc] initWithHealthStore:store
                                                                                   configuration:[[RevenantHostHKWorkoutConfiguration alloc] revenant_initWithActivityType:HKWorkoutActivityTypeRunning
                                                                                                                                    locationType:0
                                                                                                                                      lapLength:nil
                                                                                                                            swimmingLocationType:0]
                                                                                          device:nil];
    [builder beginCollectionWithStartDate:start completion:^(BOOL ok, NSError *error) {}];
    RevenantHostHKQuantitySample *insideSample = [RevenantHostHKQuantitySample quantitySampleWithType:energy
                                                                                          quantity:quantity
                                                                                         startDate:start
                                                                                           endDate:end];
    [builder addSamples:@[ insideSample ] completion:^(BOOL ok, NSError *error) {}];
    [builder endCollectionWithEndDate:end completion:^(BOOL ok, NSError *error) {}];
    __block RevenantHostHKWorkout *workout = nil;
    __block NSError *finishError = nil;
    __block BOOL workoutRan = NO;
    [builder finishWorkoutWithCompletion:^(RevenantHostHKWorkout *finished, NSError *error) {
        workout = finished; finishError = error; workoutRan = YES;
    }];
    RevenantHKWaitFor(&workoutRan);
    if (!workout) {
        printf("the workout builder's finish kept nothing: %s\n", finishError.localizedDescription.UTF8String);
    }
    RevenantHKCompareBool(@"the workout builder's finish hands back the workout", workout != nil, YES);
    if (workout) {
        RevenantHKCompareDouble(@"the finished workout has the period it was given", workout.duration, 60.0);
        RevenantHKCompareInt(@"the finished workout has the totals its samples sum to",
                           (NSInteger)(workout.totalEnergyBurned ? 1 : 0), (NSInteger)1);
        NSArray *workoutRows = [database objectsWithUUIDs:@[ workout.UUID ] ofType:workoutType error:NULL];
        RevenantHKCompareInt(@"the finished workout is in the store", (NSInteger)workoutRows.count, (NSInteger)1);
    }

    RevenantHostHKQuantitySeriesSampleBuilder *seriesBuilder =
        [[RevenantHostHKQuantitySeriesSampleBuilder alloc] initWithHealthStore:store
                                                                 quantityType:energy
                                                                    startDate:start
                                                                       device:nil];
    NSError *insertError = nil;
    BOOL inserted = [seriesBuilder insertQuantity:quantity date:start error:&insertError];
    RevenantHKCompareBool(@"the series builder takes a quantity of the type", inserted, YES);
    __block NSArray *seriesSamples = nil;
    __block NSError *seriesError = nil;
    __block BOOL seriesRan = NO;
    [seriesBuilder finishSeriesWithMetadata:nil completion:^(NSArray *samples, NSError *error) {
        seriesSamples = samples; seriesError = error; seriesRan = YES;
    }];
    RevenantHKWaitFor(&seriesRan);
    if (!seriesSamples.count) {
        printf("the series builder's finish kept nothing: %s\n", seriesError.localizedDescription.UTF8String);
    }
    RevenantHKCompareInt(@"the series builder's finish hands back its samples", (NSInteger)seriesSamples.count, (NSInteger)1);
    for (RevenantHostHKQuantitySample *each in seriesSamples) {
        NSArray *back2 = [database objectsWithUUIDs:@[ each.UUID ] ofType:energy error:NULL];
        RevenantHKCompareInt(@"a sample the series builder made is in the store", (NSInteger)back2.count, (NSInteger)1);
    }
}

static void RevenantHKStatistics12(void)
{
    NSDate *early = [NSDate dateWithTimeIntervalSince1970:1600000000];
    NSDate *middle = [NSDate dateWithTimeIntervalSince1970:1600000060];
    NSDate *late = [NSDate dateWithTimeIntervalSince1970:1600000120];
    RevenantHostHKQuantityType *type = [RevenantHostHKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierActiveEnergyBurned];
    RevenantHostHKUnit *unit = [RevenantHostHKUnit kilocalorieUnit];

    RevenantHostHKQuantitySample *a = [RevenantHostHKQuantitySample quantitySampleWithType:type
                                                                           quantity:[RevenantHostHKQuantity quantityWithUnit:unit doubleValue:10.0]
                                                                          startDate:middle endDate:middle];
    RevenantHostHKQuantitySample *b = [RevenantHostHKQuantitySample quantitySampleWithType:type
                                                                           quantity:[RevenantHostHKQuantity quantityWithUnit:unit doubleValue:20.0]
                                                                          startDate:late endDate:late];
    RevenantHostHKQuantitySample *c = [RevenantHostHKQuantitySample quantitySampleWithType:type
                                                                           quantity:[RevenantHostHKQuantity quantityWithUnit:unit doubleValue:30.0]
                                                                          startDate:early endDate:early];
    RevenantHostHKStatistics *statistics = [RevenantHostHKStatistics revenant_statisticsForSamples:@[ a, b, c ]
                                                                                    options:HKStatisticsOptionCumulativeSum];
    if (!statistics) {
        printf("skipped: the port's statistics builder answered nothing for these samples\n");
        return;
    }

    RevenantHKCompareDouble(@"mostRecentQuantity is the sample that starts last",
                          [[statistics mostRecentQuantity] doubleValueForUnit:unit], 20.0);
    RevenantHKCompare(@"mostRecentQuantityDateInterval is that sample's own interval",
                    statistics.mostRecentQuantityDateInterval.startDate, late);
    RevenantHKCompareDouble(@"mostRecentQuantityDateInterval ends where the sample ends",
                          statistics.mostRecentQuantityDateInterval.duration, 0.0);

    RevenantHostHKSource *source = [a valueForKey:@"source"];
    if (source) {
        RevenantHKCompareDouble(@"mostRecentQuantityForSource: is that source's own most recent",
                              [[statistics mostRecentQuantityForSource:source] doubleValueForUnit:unit], 20.0);
        RevenantHKCompare(@"mostRecentQuantityDateIntervalForSource: is that source's own interval",
                        [statistics mostRecentQuantityDateIntervalForSource:source].startDate, late);
    }
    RevenantHKCompare(@"every source here shares the one bucket, as the library's keying means",
                    (NSString *)([[a valueForKey:@"source"] valueForKey:@"bundleIdentifier"] ?: @""),
                    (NSString *)([[b valueForKey:@"source"] valueForKey:@"bundleIdentifier"] ?: @""));

    RevenantHostHKStatistics *empty = [RevenantHostHKStatistics revenant_statisticsForSamples:@[] options:HKStatisticsOptionCumulativeSum];
    RevenantHKCompareBool(@"an empty statistics has no most recent quantity", empty.mostRecentQuantity == nil, YES);
    RevenantHKCompareBool(@"an empty statistics has no most recent interval", empty.mostRecentQuantityDateInterval == nil, YES);

    printf("not compared: these four against the host. Its HealthKit has no entitlement here and builds "
           "no statistics this harness could read, so it answers nil for all four and that says nothing "
           "about what a statistics of real samples answers; the port's answers are compared against the "
           "samples and the dates the harness built above.\n");
}

static void RevenantHKCumulative13(void)
{
    NSDate *start = [NSDate dateWithTimeIntervalSince1970:1600000000];
    NSDate *end = [NSDate dateWithTimeIntervalSince1970:1600003600];
    RevenantHostHKQuantityType *type = [RevenantHostHKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierActiveEnergyBurned];
    RevenantHostHKUnit *unit = [RevenantHostHKUnit kilocalorieUnit];
    RevenantHostHKQuantity *sum = [RevenantHostHKQuantity quantityWithUnit:unit doubleValue:1234.0];

    Class theirs = NSClassFromString(@"HKCumulativeQuantitySample");
    RevenantHKCompare(@"the host carries the cumulative quantity sample", theirs ? @"yes" : @"no", @"yes");
    RevenantHKCompareBool(@"the host's class answers a sum", [theirs instancesRespondToSelector:NSSelectorFromString(@"sumQuantity")], YES);
    RevenantHKCompareBool(@"the host's class has no initialiser of its own",
                        [theirs instancesRespondToSelector:@selector(initWithType:quantity:startDate:endDate:)], NO);

    RevenantHostHKHealthStore *store = [[RevenantHostHKHealthStore alloc] init];
    __block BOOL authorised = NO;
    [store requestAuthorizationToShareTypes:[NSSet setWithObject:type]
                                  readTypes:[NSSet setWithObject:type]
                                 completion:^(BOOL success, NSError *error) { authorised = success; }];
    RevenantHKWaitFor(&authorised);
    if (!authorised) {
        printf("skipped: the port's store granted no authorisation, so the cumulative sample cannot be measured here\n");
        return;
    }

    RevenantHostHKCumulativeQuantitySample *sample =
        [RevenantHostHKCumulativeQuantitySample revenant_cumulativeWithType:type sum:sum startDate:start endDate:end];
    RevenantHKCompareDouble(@"the sum is the one it was given",
                          [[sample sumQuantity] doubleValueForUnit:unit], 1234.0);
    RevenantHKCompareBool(@"a cumulative sample is a quantity sample",
                        [sample isKindOfClass:NSClassFromString(@"RevenantHostHKQuantitySample")], YES);

    __block BOOL saved = NO;
    __block NSError *saveError = nil;
    [store saveObject:sample withCompletion:^(BOOL success, NSError *error) { saved = success; saveError = error; }];
    RevenantHKWaitFor(&saved);
    if (!saved) {
        printf("the port's store took no cumulative sample: %s\n", saveError.localizedDescription.UTF8String);
    }
    RevenantHKCompareBool(@"the store keeps a cumulative sample", saved, YES);
    if (saved) {
        RevenantHostRevenantHKStore *database = [RevenantHostRevenantHKStore sharedStore];
        NSArray *found = [database objectsWithUUIDs:@[ sample.UUID ] ofType:type error:NULL];
        RevenantHKCompareInt(@"the cumulative sample is found again", (NSInteger)found.count, (NSInteger)1);
        id back = found.firstObject;
        RevenantHKCompare(@"and it is found as this class, not as its superclass",
                        NSStringFromClass([back class]), NSStringFromClass([sample class]));
        RevenantHKCompareBool(@"and it carries its sum", [back respondsToSelector:NSSelectorFromString(@"sumQuantity")], YES);
    }
}

static void RevenantHKCumulativeSeries12(void)
{
    NSDate *start = [NSDate dateWithTimeIntervalSince1970:1600000000];
    NSDate *end = [NSDate dateWithTimeIntervalSince1970:1600007200];
    RevenantHostHKQuantityType *type = [RevenantHostHKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierActiveEnergyBurned];
    RevenantHostHKUnit *unit = [RevenantHostHKUnit kilocalorieUnit];
    RevenantHostHKQuantity *sum = [RevenantHostHKQuantity quantityWithUnit:unit doubleValue:4321.0];

    Class theirs = NSClassFromString(@"HKCumulativeQuantitySeriesSample");
    RevenantHKCompare(@"the host carries the cumulative sample of a series", theirs ? @"yes" : @"no", @"yes");
    RevenantHKCompareBool(@"the host's class answers a sum", [theirs instancesRespondToSelector:NSSelectorFromString(@"sum")], YES);

    RevenantHostHKHealthStore *store = [[RevenantHostHKHealthStore alloc] init];
    __block BOOL authorised = NO;
    [store requestAuthorizationToShareTypes:[NSSet setWithObject:type]
                                  readTypes:[NSSet setWithObject:type]
                                 completion:^(BOOL success, NSError *error) { authorised = success; }];
    RevenantHKWaitFor(&authorised);
    if (!authorised) {
        printf("skipped: the port's store granted no authorisation, so the series sample cannot be measured here\n");
        return;
    }

    RevenantHostHKCumulativeQuantitySeriesSample *sample =
        [RevenantHostHKCumulativeQuantitySeriesSample revenant_seriesWithType:type sum:sum startDate:start endDate:end];
    RevenantHKCompareDouble(@"the sum is the one it was given",
                          [[sample sum] doubleValueForUnit:unit], 4321.0);
    RevenantHKCompareBool(@"a series sample is a cumulative sample",
                        [sample isKindOfClass:NSClassFromString(@"RevenantHostHKCumulativeQuantitySample")], YES);
    RevenantHKCompareDouble(@"and it keeps the superclass's own sum too",
                          [[sample sumQuantity] doubleValueForUnit:unit], 4321.0);

    __block BOOL saved = NO;
    __block NSError *saveError = nil;
    [store saveObject:sample withCompletion:^(BOOL success, NSError *error) { saved = success; saveError = error; }];
    RevenantHKWaitFor(&saved);
    if (!saved) {
        printf("the port's store took no series sample: %s\n", saveError.localizedDescription.UTF8String);
    }
    RevenantHKCompareBool(@"the store keeps a series sample", saved, YES);
    if (saved) {
        RevenantHostRevenantHKStore *database = [RevenantHostRevenantHKStore sharedStore];
        NSArray *found = [database objectsWithUUIDs:@[ sample.UUID ] ofType:type error:NULL];
        RevenantHKCompareInt(@"the series sample is found again", (NSInteger)found.count, (NSInteger)1);
        id back = found.firstObject;
        RevenantHKCompare(@"and it is found as this class",
                        NSStringFromClass([back class]), NSStringFromClass([sample class]));
        RevenantHKCompareDouble(@"and it comes back carrying its sum",
                              [[back valueForKey:@"sum"] doubleValueForUnit:unit], 4321.0);
    }
}

int main(void)
{
    RevenantHKDefaultResolver();
    RevenantHKInstallClassResolver();
    RevenantHKConstants12();
    RevenantHKMeasuredConstants();
    RevenantHKUnitCases();
    RevenantHKPrefixedFactories();
    RevenantHKUnitArithmetic();
    RevenantHKQuantities();
    RevenantHKTypeTable();
    RevenantHKQueryObjects();
    RevenantHK11Group();
    RevenantHKWorkoutBuilder12();
    RevenantHKSeriesBuilder12();
    RevenantHKStoreRoundTrip();
    RevenantHKSeriesQuery12();
    RevenantHKStatistics12();
    RevenantHKCumulative13();
    RevenantHKCumulativeSeries12();
    printf("healthkit: %lu comparisons, %lu differences\n", (unsigned long)RevenantHKComparisons,
           (unsigned long)RevenantHKDifferences);
    return RevenantHKDifferences == 0 ? 0 : 1;
}
