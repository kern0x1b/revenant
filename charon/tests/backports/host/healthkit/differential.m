// differential.m — what the host's HealthKit answers for the arithmetic of units, quantities and
// quantity types, and what the port's answers for the same questions, in one process, and whether
// the two agree.
//
// The two halves are the system's own HKUnit, HKQuantity, HKObjectType and HKQuantityType, and the
// port's compiled under names of their own (CharonHostHKUnit and so on, put there by run.sh's -D
// flags). Nothing here asks anybody for anything: a unit converts, a unit multiplies, a quantity
// compares, a type says which unit it is counted in and which aggregation it uses, and each of those
// is a property of the class rather than of a store behind an entitlement. The store, the
// authorization and the queries are not in this file, because a host keeps its data in a healthd this
// port has no counterpart to, and a differential over the two would compare two different programs.
//
// Every number below is read off the *host* through its own public conversion and read off the *port*
// the same way, so the comparison is of the two answers and not of two copies of one table.

#import <Foundation/Foundation.h>
#import <HealthKit/HealthKit.h>

extern Class _Nullable CharonHKClassForObjectKind(NSInteger kind);
extern void CharonHKSetClassResolver(Class _Nullable (^resolver)(NSString *name));

#import <objc/runtime.h>

#import "CharonHKTypes.h"

// The members iOS 9.3 added to HKQuery, which the header this file compiles against declares in
// HKQuery.h and HKSampleQuery.h and which HealthKit.h does not import. The host's own classes answer
// them, and so must the port's, so both are declared here rather than assumed.
@interface HKQuery (HKCharon93)
@property (readonly, strong, nullable) HKObjectType *objectType;
@property (readonly, strong, nullable) NSPredicate *predicate;
@end

@interface HKSampleQuery (HKCharon93)
@property (readonly) NSUInteger limit;
@property (readonly, copy, nullable) NSArray<NSSortDescriptor *> *sortDescriptors;
@property (readonly) BOOL hasBeenExecuted;
@property (readonly, copy) NSUUID *activationUUID;
@end

@interface HKStatisticsCollectionQuery (HKCharon93)
@property (readonly, strong) NSDate *anchorDate;
@property (readonly) HKStatisticsOptions options;
@property (readonly, copy) NSDateComponents *intervalComponents;
@end

// The port's own classes, under the names run.sh's -D flags give them. The declarations are this
// file's own and hold only what it asks of them: the port's headers declare the same classes under
// their real names, which the system's HealthKit also declares, so they cannot both be seen at once.

// The port's own classes, under the names run.sh's -D flags give them, for the members the two new
// sections ask of. The declarations are this file's own and hold only what it asks of them: a query
// object holds its own facts and needs no store to answer them, which is what makes them comparable
// with the host's.
@interface CharonHostHKQuery : NSObject
+ (NSPredicate *)predicateForClinicalRecordsWithFHIRResourceType:(NSString *)resourceType;
+ (nullable NSPredicate *)predicateForClinicalRecordsFromSource:(nullable HKSource *)source
                                                FHIRResourceType:(nullable NSString *)resourceType
                                                     identifier:(nullable NSString *)identifier;
+ (NSString *)charon_predicateOperatorSpellingFor:(long)type;
@end

@interface CharonHostHKStatisticsCollectionQuery : NSObject
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

@interface CharonHostHKSampleType : NSObject
@end

@class CharonHostHKQuantityType;

@interface CharonHostHKSampleQuery : NSObject
- (instancetype)initWithSampleType:(HKSampleType *)sampleType
                         predicate:(nullable NSPredicate *)predicate
                             limit:(NSUInteger)limit
                  sortDescriptors:(nullable NSArray<NSSortDescriptor *> *)sortDescriptors
                   resultsHandler:(void (^)(CharonHostHKSampleQuery *query, NSArray *results, NSError *error))resultsHandler;
@property (readonly) HKSampleType *sampleType;
@property (readonly) HKObjectType *objectType;
@property (readonly) NSUInteger limit;
@property (readonly, copy) NSArray<NSSortDescriptor *> *sortDescriptors;
@property (readonly) NSPredicate *predicate;
@end

@interface CharonHostHKStatisticsQuery : NSObject
- (instancetype)initWithQuantityType:(HKQuantityType *)quantityType
                quantitySamplePredicate:(nullable NSPredicate *)quantitySamplePredicate
                             options:(HKStatisticsOptions)options
                    completionHandler:(void (^)(id result, NSError *error))completionHandler;
@property (readonly) HKQuantityType *objectType;
@property (readonly) NSPredicate *predicate;
@property (readonly) BOOL hasBeenExecuted;
@end

@interface CharonHostHKSourceQuery : NSObject
- (instancetype)initWithSampleType:(nullable HKSampleType *)sampleType
                    samplePredicate:(nullable NSPredicate *)predicate
                  completionHandler:(void (^)(NSArray<HKSource *> *sources, NSError *error))completionHandler;
@property (readonly) HKObjectType *objectType;
@property (readonly) NSPredicate *predicate;
@end

// The iOS 11.0 group: the series type, the clinical type, the FHIR resource, the source revision's two
// new members, the workout event over a period, and the workout's flights climbed.
@interface CharonHostHKSeriesType : NSObject
+ (instancetype)workoutRouteType;
@property (readonly, copy) NSString *identifier;
@end

@class CharonHostHKSeriesType;
@class CharonHostHKClinicalType;

@interface CharonHostHKObjectType : NSObject
+ (nullable HKQuantityType *)quantityTypeForIdentifier:(NSString *)identifier;
+ (nullable HKWorkoutType *)workoutType;
+ (nullable CharonHostHKSeriesType *)seriesTypeForIdentifier:(NSString *)identifier;
+ (nullable CharonHostHKClinicalType *)clinicalTypeForIdentifier:(NSString *)identifier;
@end

@interface CharonHostHKClinicalType : NSObject
@property (readonly, copy) NSString *identifier;
@end

@interface CharonHostHKFHIRResource : NSObject
+ (instancetype)charon_resourceWithType:(NSString *)resourceType
                             identifier:(NSString *)identifier
                                   data:(NSData *)data
                              sourceURL:(nullable NSURL *)sourceURL;
@property (readonly, copy) NSString *resourceType;
@property (readonly, copy) NSString *identifier;
@property (readonly, copy) NSData *data;
@property (readonly, copy, nullable) NSURL *sourceURL;
- (id)copy;
@end

@interface CharonHostHKSource : NSObject
+ (instancetype)defaultSource;
@property (readonly, copy) NSString *bundleIdentifier;
@end

@interface CharonHostHKSourceRevision : NSObject
- (instancetype)initWithSource:(HKSource *)source
                       version:(nullable NSString *)version
                   productType:(nullable NSString *)productType
          operatingSystemVersion:(NSOperatingSystemVersion)operatingSystemVersion;
@property (readonly, copy) HKSource *source;
@property (readonly, copy) NSString *version;
@property (readonly, copy) NSString *productType;
@property (readonly) NSOperatingSystemVersion operatingSystemVersion;
@end

@interface CharonHostHKWorkoutEvent : NSObject
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

// The port's workout type, which the store keeps as a shareable type. The harness needs the class to
// exist by name to ask the store for authorisation over it; it holds no member of its own here.
@interface CharonHostHKWorkoutType : NSObject
@property (readonly, copy) NSString *identifier;
@end

@interface CharonHostHKWorkout : NSObject
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

@interface CharonHostHKUnit : NSObject
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
- (BOOL)charon_isCompatibleWithUnit:(CharonHostHKUnit *)unit;
@end

@interface CharonHostHKQuantity : NSObject
+ (instancetype)quantityWithUnit:(CharonHostHKUnit *)unit doubleValue:(double)value;
@property (readonly, copy) CharonHostHKUnit *unit;
- (BOOL)isCompatibleWithUnit:(CharonHostHKUnit *)unit;
- (double)doubleValueForUnit:(CharonHostHKUnit *)unit;
- (NSComparisonResult)compare:(CharonHostHKQuantity *)quantity;
@end

@interface CharonHostHKQuantityType : CharonHostHKObjectType
@property (readonly, copy) NSString *identifier;
@property (readonly) NSInteger aggregationStyle;
- (BOOL)isCompatibleWithUnit:(CharonHostHKUnit *)unit;
@end

// fprintf knows no %@ - that is a Foundation specifier, and C printf prints it as a plain @ - so
// every object goes through -description here and every class through NSStringFromClass, and the two
// booleans are %d because they are ints and not pointers. The last two versions of the print below
// said an ivar held garbage, and it did: %s for an object, and then %@ for the same object.
static const char *CharonHKDescribe(id object)
{
    NSString *text = [object description];
    return text ? (const char *)[text UTF8String] : "(null)";
}

static NSUInteger CharonHKDifferences;
static NSUInteger CharonHKComparisons;

static void CharonHKCompare(NSString *what, id mine, id theirs)
{
    CharonHKComparisons++;
    BOOL same = mine == nil ? theirs == nil : [mine isEqual:theirs];
    if (!same) {
        CharonHKDifferences++;
        printf("DIFFERS  %-56s port %-26s host %s\n", what.UTF8String,
               [[mine description] UTF8String], [[theirs description] UTF8String]);
    }
}

static void CharonHKCompareBool(NSString *what, BOOL mine, BOOL theirs)
{
    CharonHKCompare(what, @(mine), @(theirs));
}

static void CharonHKCompareInt(NSString *what, NSInteger mine, NSInteger theirs)
{
    CharonHKCompare(what, @(mine), @(theirs));
}

// The factors of a unit, as the strings it writes them with, in the order it writes them. The host
// writes a product in an order of its own that the public API does not say - it answers `J/m·s·kg`
// for `J/(m*kg*s)`, for `J/(s*kg*m)` and for `J/(m*s*kg)` alike - so the factors are compared as a
// set and the order is not. Everything else about a product is compared: which units it accepts, and
// the number it converts.
static void CharonHKCompareFactors(NSString *what, id mineUnit, id theirsUnit)
{
    CharonHKComparisons++;
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
        CharonHKDifferences++;
        printf("DIFFERS  %-56s port %-26s host %s\n", what.UTF8String, mine.UTF8String, theirs.UTF8String);
    }
}

static void CharonHKCompareDouble(NSString *what, double mine, double theirs)
{
    CharonHKComparisons++;
    // Relative: the two are doubles computed from the same factors, and a factor of the wrong order of
    // magnitude differs by six orders of magnitude, not by a last bit. An absolute floor of 1e-12
    // keeps a difference of exactly zero from being a failure of the comparison itself.
    double scale = MAX(1.0, MAX(fabs(mine), fabs(theirs)));
    if (fabs(mine - theirs) > 1e-9 * scale) {
        CharonHKDifferences++;
        printf("DIFFERS  %-56s port %.12g  host %.12g\n", what.UTF8String, mine, theirs);
    }
}

// The value a unit is measured at. Not round and not small, so a factor of the wrong order of
// magnitude cannot agree by accident.
static const double CharonHKProbe = 1.0 + 1.0 / 3.0;
// A temperature's conversion is affine, so a second value at a different place is what tells an offset
// that is right from one that is not.
static const double CharonHKSecondProbe = 21.5;

// The twenty-one constants of 12.0, as the port's own object holds them. run.sh renames them, because
// the host's HealthKit exports the same twenty-one symbols and one process cannot link both under one
// name - so these are the port's values read out of its own compiled object, side by side with the
// host's values read out of the host's. The 11.0 section above compares the host's constants with the
// strings this library writes in its source; this compares the symbols themselves.
extern NSString *const CharonHK120_HKFHIRResourceTypeAllergyIntolerance;
extern NSString *const CharonHK120_HKFHIRResourceTypeCondition;
extern NSString *const CharonHK120_HKFHIRResourceTypeImmunization;
extern NSString *const CharonHK120_HKFHIRResourceTypeMedicationDispense;
extern NSString *const CharonHK120_HKFHIRResourceTypeMedicationOrder;
extern NSString *const CharonHK120_HKFHIRResourceTypeMedicationStatement;
extern NSString *const CharonHK120_HKFHIRResourceTypeObservation;
extern NSString *const CharonHK120_HKFHIRResourceTypeProcedure;
extern NSString *const CharonHK120_HKClinicalTypeIdentifierAllergyRecord;
extern NSString *const CharonHK120_HKClinicalTypeIdentifierConditionRecord;
extern NSString *const CharonHK120_HKClinicalTypeIdentifierImmunizationRecord;
extern NSString *const CharonHK120_HKClinicalTypeIdentifierLabResultRecord;
extern NSString *const CharonHK120_HKClinicalTypeIdentifierMedicationRecord;
extern NSString *const CharonHK120_HKClinicalTypeIdentifierProcedureRecord;
extern NSString *const CharonHK120_HKClinicalTypeIdentifierVitalSignRecord;
extern NSString *const CharonHK120_HKMetadataKeyCrossTrainerDistance;
extern NSString *const CharonHK120_HKMetadataKeyFitnessMachineDuration;
extern NSString *const CharonHK120_HKMetadataKeyIndoorBikeDistance;
extern NSString *const CharonHK120_HKPredicateKeyPathClinicalRecordFHIRResourceIdentifier;
extern NSString *const CharonHK120_HKPredicateKeyPathClinicalRecordFHIRResourceType;
extern NSString *const CharonHK120_HKPredicateKeyPathSum;

#import <dlfcn.h>

// ---------------------------------------------------------------------- the 193 measured constants

// The exported string constants of iOS 11.2 through 26.2 that this library now carries, as the port's own
// objects hold them. run.sh renames every one of them, because the host's HealthKit exports the same
// symbols and one process cannot link both under one name - so each is read out of the port's own
// compiled object, which is the whole point: a literal here would compare the host against a string
// written beside it.
//
// The host's side is read with dlsym rather than named directly, for two reasons and not for one. It is
// the method the corpus table was measured with (coordination/corpus/ledger/constant-values-HealthKit.tsv:
// tools/corpus/host-probe.c, dlopen + dlsym + CFStringGetCString as UTF-8), so the port's value is held
// against the same reading of the same binary rather than against a second transcription of it - and the
// name is given to dlsym as that probe gives it, the bare C name with no leading underscore, which is the
// form dlsym resolves on this platform (measured: the underscore form answers NULL for all three of a spot
// check while the bare form answers the symbol). And a name the host does not export is an answer this
// section can report - `the host's HealthKit does not export it` - where a direct reference to it would be
// a link error that takes the whole differential down, and 193 names is more than a reader should bet on
// any one SDK's headers declaring.
//
// The six of HKConstants120.m keep the prefix the twenty-one above already use, so one object is one
// prefix; the other 187 take one prefix of their own, HKConstants134.m through HKConstants262.m.
extern NSString *const CharonHK120_HKMetadataKeyAlpineSlopeGrade;
extern NSString *const CharonHK120_HKMetadataKeyAverageSpeed;
extern NSString *const CharonHK120_HKMetadataKeyElevationAscended;
extern NSString *const CharonHK120_HKMetadataKeyElevationDescended;
extern NSString *const CharonHK120_HKMetadataKeyMaximumSpeed;
extern NSString *const CharonHK120_HKQuantityTypeIdentifierDistanceDownhillSnowSports;
extern NSString *const CharonHKMeasured_HKCategoryTypeIdentifierAbdominalCramps;
extern NSString *const CharonHKMeasured_HKCategoryTypeIdentifierAcne;
extern NSString *const CharonHKMeasured_HKCategoryTypeIdentifierAppetiteChanges;
extern NSString *const CharonHKMeasured_HKCategoryTypeIdentifierAppleWalkingSteadinessEvent;
extern NSString *const CharonHKMeasured_HKCategoryTypeIdentifierAudioExposureEvent;
extern NSString *const CharonHKMeasured_HKCategoryTypeIdentifierBladderIncontinence;
extern NSString *const CharonHKMeasured_HKCategoryTypeIdentifierBloating;
extern NSString *const CharonHKMeasured_HKCategoryTypeIdentifierBreastPain;
extern NSString *const CharonHKMeasured_HKCategoryTypeIdentifierChestTightnessOrPain;
extern NSString *const CharonHKMeasured_HKCategoryTypeIdentifierChills;
extern NSString *const CharonHKMeasured_HKCategoryTypeIdentifierConstipation;
extern NSString *const CharonHKMeasured_HKCategoryTypeIdentifierContraceptive;
extern NSString *const CharonHKMeasured_HKCategoryTypeIdentifierCoughing;
extern NSString *const CharonHKMeasured_HKCategoryTypeIdentifierDiarrhea;
extern NSString *const CharonHKMeasured_HKCategoryTypeIdentifierDizziness;
extern NSString *const CharonHKMeasured_HKCategoryTypeIdentifierDrySkin;
extern NSString *const CharonHKMeasured_HKCategoryTypeIdentifierEnvironmentalAudioExposureEvent;
extern NSString *const CharonHKMeasured_HKCategoryTypeIdentifierFainting;
extern NSString *const CharonHKMeasured_HKCategoryTypeIdentifierFatigue;
extern NSString *const CharonHKMeasured_HKCategoryTypeIdentifierFever;
extern NSString *const CharonHKMeasured_HKCategoryTypeIdentifierGeneralizedBodyAche;
extern NSString *const CharonHKMeasured_HKCategoryTypeIdentifierHairLoss;
extern NSString *const CharonHKMeasured_HKCategoryTypeIdentifierHandwashingEvent;
extern NSString *const CharonHKMeasured_HKCategoryTypeIdentifierHeadache;
extern NSString *const CharonHKMeasured_HKCategoryTypeIdentifierHeadphoneAudioExposureEvent;
extern NSString *const CharonHKMeasured_HKCategoryTypeIdentifierHeartburn;
extern NSString *const CharonHKMeasured_HKCategoryTypeIdentifierHighHeartRateEvent;
extern NSString *const CharonHKMeasured_HKCategoryTypeIdentifierHotFlashes;
extern NSString *const CharonHKMeasured_HKCategoryTypeIdentifierInfrequentMenstrualCycles;
extern NSString *const CharonHKMeasured_HKCategoryTypeIdentifierIrregularHeartRhythmEvent;
extern NSString *const CharonHKMeasured_HKCategoryTypeIdentifierIrregularMenstrualCycles;
extern NSString *const CharonHKMeasured_HKCategoryTypeIdentifierLactation;
extern NSString *const CharonHKMeasured_HKCategoryTypeIdentifierLossOfSmell;
extern NSString *const CharonHKMeasured_HKCategoryTypeIdentifierLossOfTaste;
extern NSString *const CharonHKMeasured_HKCategoryTypeIdentifierLowCardioFitnessEvent;
extern NSString *const CharonHKMeasured_HKCategoryTypeIdentifierLowHeartRateEvent;
extern NSString *const CharonHKMeasured_HKCategoryTypeIdentifierLowerBackPain;
extern NSString *const CharonHKMeasured_HKCategoryTypeIdentifierMemoryLapse;
extern NSString *const CharonHKMeasured_HKCategoryTypeIdentifierMoodChanges;
extern NSString *const CharonHKMeasured_HKCategoryTypeIdentifierNausea;
extern NSString *const CharonHKMeasured_HKCategoryTypeIdentifierNightSweats;
extern NSString *const CharonHKMeasured_HKCategoryTypeIdentifierPelvicPain;
extern NSString *const CharonHKMeasured_HKCategoryTypeIdentifierPersistentIntermenstrualBleeding;
extern NSString *const CharonHKMeasured_HKCategoryTypeIdentifierPregnancy;
extern NSString *const CharonHKMeasured_HKCategoryTypeIdentifierPregnancyTestResult;
extern NSString *const CharonHKMeasured_HKCategoryTypeIdentifierProgesteroneTestResult;
extern NSString *const CharonHKMeasured_HKCategoryTypeIdentifierProlongedMenstrualPeriods;
extern NSString *const CharonHKMeasured_HKCategoryTypeIdentifierRapidPoundingOrFlutteringHeartbeat;
extern NSString *const CharonHKMeasured_HKCategoryTypeIdentifierRunnyNose;
extern NSString *const CharonHKMeasured_HKCategoryTypeIdentifierShortnessOfBreath;
extern NSString *const CharonHKMeasured_HKCategoryTypeIdentifierSinusCongestion;
extern NSString *const CharonHKMeasured_HKCategoryTypeIdentifierSkippedHeartbeat;
extern NSString *const CharonHKMeasured_HKCategoryTypeIdentifierSleepChanges;
extern NSString *const CharonHKMeasured_HKCategoryTypeIdentifierSoreThroat;
extern NSString *const CharonHKMeasured_HKCategoryTypeIdentifierToothbrushingEvent;
extern NSString *const CharonHKMeasured_HKCategoryTypeIdentifierVaginalDryness;
extern NSString *const CharonHKMeasured_HKCategoryTypeIdentifierVomiting;
extern NSString *const CharonHKMeasured_HKCategoryTypeIdentifierWheezing;
extern NSString *const CharonHKMeasured_HKCharacteristicTypeIdentifierActivityMoveMode;
extern NSString *const CharonHKMeasured_HKClinicalTypeIdentifierCoverageRecord;
extern NSString *const CharonHKMeasured_HKDataTypeIdentifierHeartbeatSeries;
extern NSString *const CharonHKMeasured_HKFHIRReleaseDSTU2;
extern NSString *const CharonHKMeasured_HKFHIRReleaseR4;
extern NSString *const CharonHKMeasured_HKFHIRReleaseUnknown;
extern NSString *const CharonHKMeasured_HKFHIRResourceTypeCoverage;
extern NSString *const CharonHKMeasured_HKFHIRResourceTypeMedicationRequest;
extern NSString *const CharonHKMeasured_HKMedicationDoseEventTypeIdentifierMedicationDoseEvent;
extern NSString *const CharonHKMeasured_HKMetadataKeyAlgorithmVersion;
extern NSString *const CharonHKMeasured_HKMetadataKeyAppleDeviceCalibrated;
extern NSString *const CharonHKMeasured_HKMetadataKeyAppleECGAlgorithmVersion;
extern NSString *const CharonHKMeasured_HKMetadataKeyAudioExposureDuration;
extern NSString *const CharonHKMeasured_HKMetadataKeyAudioExposureLevel;
extern NSString *const CharonHKMeasured_HKMetadataKeyAverageMETs;
extern NSString *const CharonHKMeasured_HKMetadataKeyBarometricPressure;
extern NSString *const CharonHKMeasured_HKMetadataKeyDateOfEarliestDataUsedForEstimate;
extern NSString *const CharonHKMeasured_HKMetadataKeyDevicePlacementSide;
extern NSString *const CharonHKMeasured_HKMetadataKeyGlassesPrescriptionDescription;
extern NSString *const CharonHKMeasured_HKMetadataKeyHeartRateEventThreshold;
extern NSString *const CharonHKMeasured_HKMetadataKeyHeartRateRecoveryActivityDuration;
extern NSString *const CharonHKMeasured_HKMetadataKeyHeartRateRecoveryActivityType;
extern NSString *const CharonHKMeasured_HKMetadataKeyHeartRateRecoveryMaxObservedRecoveryHeartRate;
extern NSString *const CharonHKMeasured_HKMetadataKeyHeartRateRecoveryTestType;
extern NSString *const CharonHKMeasured_HKMetadataKeyLowCardioFitnessEventThreshold;
extern NSString *const CharonHKMeasured_HKMetadataKeyQuantityClampedToLowerBound;
extern NSString *const CharonHKMeasured_HKMetadataKeyQuantityClampedToUpperBound;
extern NSString *const CharonHKMeasured_HKMetadataKeySWOLFScore;
extern NSString *const CharonHKMeasured_HKMetadataKeySessionEstimate;
extern NSString *const CharonHKMeasured_HKMetadataKeyUserMotionContext;
extern NSString *const CharonHKMeasured_HKMetadataKeyVO2MaxValue;
extern NSString *const CharonHKMeasured_HKPredicateKeyPathAverage;
extern NSString *const CharonHKMeasured_HKPredicateKeyPathAverageHeartRate;
extern NSString *const CharonHKMeasured_HKPredicateKeyPathCount;
extern NSString *const CharonHKMeasured_HKPredicateKeyPathECGClassification;
extern NSString *const CharonHKMeasured_HKPredicateKeyPathECGSymptomsStatus;
extern NSString *const CharonHKMeasured_HKPredicateKeyPathMax;
extern NSString *const CharonHKMeasured_HKPredicateKeyPathMin;
extern NSString *const CharonHKMeasured_HKPredicateKeyPathMostRecent;
extern NSString *const CharonHKMeasured_HKPredicateKeyPathMostRecentDuration;
extern NSString *const CharonHKMeasured_HKPredicateKeyPathMostRecentEndDate;
extern NSString *const CharonHKMeasured_HKPredicateKeyPathMostRecentStartDate;
extern NSString *const CharonHKMeasured_HKPredicateKeyPathStatus;
extern NSString *const CharonHKMeasured_HKPredicateKeyPathWorkoutActivity;
extern NSString *const CharonHKMeasured_HKPredicateKeyPathWorkoutActivityAverageQuantity;
extern NSString *const CharonHKMeasured_HKPredicateKeyPathWorkoutActivityDuration;
extern NSString *const CharonHKMeasured_HKPredicateKeyPathWorkoutActivityEndDate;
extern NSString *const CharonHKMeasured_HKPredicateKeyPathWorkoutActivityMaximumQuantity;
extern NSString *const CharonHKMeasured_HKPredicateKeyPathWorkoutActivityMinimumQuantity;
extern NSString *const CharonHKMeasured_HKPredicateKeyPathWorkoutActivityStartDate;
extern NSString *const CharonHKMeasured_HKPredicateKeyPathWorkoutActivitySumQuantity;
extern NSString *const CharonHKMeasured_HKPredicateKeyPathWorkoutActivityType;
extern NSString *const CharonHKMeasured_HKPredicateKeyPathWorkoutAverageQuantity;
extern NSString *const CharonHKMeasured_HKPredicateKeyPathWorkoutMaximumQuantity;
extern NSString *const CharonHKMeasured_HKPredicateKeyPathWorkoutMinimumQuantity;
extern NSString *const CharonHKMeasured_HKPredicateKeyPathWorkoutSumQuantity;
extern NSString *const CharonHKMeasured_HKQuantityTypeIdentifierAppleMoveTime;
extern NSString *const CharonHKMeasured_HKQuantityTypeIdentifierAppleSleepingWristTemperature;
extern NSString *const CharonHKMeasured_HKQuantityTypeIdentifierAppleStandTime;
extern NSString *const CharonHKMeasured_HKQuantityTypeIdentifierAppleWalkingSteadiness;
extern NSString *const CharonHKMeasured_HKQuantityTypeIdentifierAtrialFibrillationBurden;
extern NSString *const CharonHKMeasured_HKQuantityTypeIdentifierEnvironmentalAudioExposure;
extern NSString *const CharonHKMeasured_HKQuantityTypeIdentifierEnvironmentalSoundReduction;
extern NSString *const CharonHKMeasured_HKQuantityTypeIdentifierHeadphoneAudioExposure;
extern NSString *const CharonHKMeasured_HKQuantityTypeIdentifierHeartRateRecoveryOneMinute;
extern NSString *const CharonHKMeasured_HKQuantityTypeIdentifierNumberOfAlcoholicBeverages;
extern NSString *const CharonHKMeasured_HKQuantityTypeIdentifierRunningGroundContactTime;
extern NSString *const CharonHKMeasured_HKQuantityTypeIdentifierRunningPower;
extern NSString *const CharonHKMeasured_HKQuantityTypeIdentifierRunningSpeed;
extern NSString *const CharonHKMeasured_HKQuantityTypeIdentifierRunningStrideLength;
extern NSString *const CharonHKMeasured_HKQuantityTypeIdentifierRunningVerticalOscillation;
extern NSString *const CharonHKMeasured_HKQuantityTypeIdentifierSixMinuteWalkTestDistance;
extern NSString *const CharonHKMeasured_HKQuantityTypeIdentifierStairAscentSpeed;
extern NSString *const CharonHKMeasured_HKQuantityTypeIdentifierStairDescentSpeed;
extern NSString *const CharonHKMeasured_HKQuantityTypeIdentifierUnderwaterDepth;
extern NSString *const CharonHKMeasured_HKQuantityTypeIdentifierWalkingAsymmetryPercentage;
extern NSString *const CharonHKMeasured_HKQuantityTypeIdentifierWalkingDoubleSupportPercentage;
extern NSString *const CharonHKMeasured_HKQuantityTypeIdentifierWalkingSpeed;
extern NSString *const CharonHKMeasured_HKQuantityTypeIdentifierWalkingStepLength;
extern NSString *const CharonHKMeasured_HKQuantityTypeIdentifierWaterTemperature;
extern NSString *const CharonHKMeasured_HKVerifiableClinicalRecordCredentialTypeCOVID19;
extern NSString *const CharonHKMeasured_HKVerifiableClinicalRecordCredentialTypeImmunization;
extern NSString *const CharonHKMeasured_HKVerifiableClinicalRecordCredentialTypeLaboratory;
extern NSString *const CharonHKMeasured_HKVerifiableClinicalRecordCredentialTypeRecovery;
extern NSString *const CharonHKMeasured_HKVerifiableClinicalRecordSourceTypeEUDigitalCOVIDCertificate;
extern NSString *const CharonHKMeasured_HKVerifiableClinicalRecordSourceTypeSMARTHealthCard;
extern NSString *const CharonHKMeasured_HKVisionPrescriptionTypeIdentifier;
extern NSString *const CharonHKMeasured_HKCategoryTypeIdentifierBleedingAfterPregnancy;
extern NSString *const CharonHKMeasured_HKCategoryTypeIdentifierBleedingDuringPregnancy;
extern NSString *const CharonHKMeasured_HKCategoryTypeIdentifierSleepApneaEvent;
extern NSString *const CharonHKMeasured_HKClinicalTypeIdentifierClinicalNoteRecord;
extern NSString *const CharonHKMeasured_HKDataTypeIdentifierStateOfMind;
extern NSString *const CharonHKMeasured_HKFHIRResourceTypeDiagnosticReport;
extern NSString *const CharonHKMeasured_HKFHIRResourceTypeDocumentReference;
extern NSString *const CharonHKMeasured_HKMetadataKeyActivityType;
extern NSString *const CharonHKMeasured_HKMetadataKeyAppleFitnessPlusSession;
extern NSString *const CharonHKMeasured_HKMetadataKeyCyclingFunctionalThresholdPowerTestType;
extern NSString *const CharonHKMeasured_HKMetadataKeyHeadphoneGain;
extern NSString *const CharonHKMeasured_HKMetadataKeyMaximumLightIntensity;
extern NSString *const CharonHKMeasured_HKMetadataKeyPhysicalEffortEstimationType;
extern NSString *const CharonHKMeasured_HKMetadataKeyWaterSalinity;
extern NSString *const CharonHKMeasured_HKPredicateKeyPathWorkoutEffortRelationship;
extern NSString *const CharonHKMeasured_HKQuantityTypeIdentifierAppleSleepingBreathingDisturbances;
extern NSString *const CharonHKMeasured_HKQuantityTypeIdentifierCrossCountrySkiingSpeed;
extern NSString *const CharonHKMeasured_HKQuantityTypeIdentifierCyclingCadence;
extern NSString *const CharonHKMeasured_HKQuantityTypeIdentifierCyclingFunctionalThresholdPower;
extern NSString *const CharonHKMeasured_HKQuantityTypeIdentifierCyclingPower;
extern NSString *const CharonHKMeasured_HKQuantityTypeIdentifierCyclingSpeed;
extern NSString *const CharonHKMeasured_HKQuantityTypeIdentifierDistanceCrossCountrySkiing;
extern NSString *const CharonHKMeasured_HKQuantityTypeIdentifierDistancePaddleSports;
extern NSString *const CharonHKMeasured_HKQuantityTypeIdentifierDistanceRowing;
extern NSString *const CharonHKMeasured_HKQuantityTypeIdentifierDistanceSkatingSports;
extern NSString *const CharonHKMeasured_HKQuantityTypeIdentifierEstimatedWorkoutEffortScore;
extern NSString *const CharonHKMeasured_HKQuantityTypeIdentifierPaddleSportsSpeed;
extern NSString *const CharonHKMeasured_HKQuantityTypeIdentifierPhysicalEffort;
extern NSString *const CharonHKMeasured_HKQuantityTypeIdentifierRowingSpeed;
extern NSString *const CharonHKMeasured_HKQuantityTypeIdentifierTimeInDaylight;
extern NSString *const CharonHKMeasured_HKQuantityTypeIdentifierWorkoutEffortScore;
extern NSString *const CharonHKMeasured_HKScoredAssessmentTypeIdentifierGAD7;
extern NSString *const CharonHKMeasured_HKScoredAssessmentTypeIdentifierPHQ9;
extern NSString *const CharonHKMeasured_HKMetadataKeyAppleFitnessPlusCatalogIdentifier;
extern NSString *const CharonHKMeasured_HKDataTypeIdentifierUserAnnotatedMedicationConcept;
extern NSString *const CharonHKMeasured_HKHealthConceptDomainMedication;
extern NSString *const CharonHKMeasured_HKPredicateKeyPathLogOrigin;
extern NSString *const CharonHKMeasured_HKPredicateKeyPathMedicationConceptIdentifier;
extern NSString *const CharonHKMeasured_HKPredicateKeyPathScheduledDate;
extern NSString *const CharonHKMeasured_HKUserAnnotatedMedicationPredicateKeyPathHasSchedule;
extern NSString *const CharonHKMeasured_HKUserAnnotatedMedicationPredicateKeyPathIsArchived;
extern NSString *const CharonHKMeasured_HKCategoryTypeIdentifierHypertensionEvent;

static void CharonHKMeasuredConstants(void)
{
    // Not static and not const: a NSString * const of another file is not a compile-time constant in C,
    // and an array of them has to be built at run time.
    struct { NSString *name; NSString *port; } rows[] = {
    {@"HKMetadataKeyAlpineSlopeGrade", CharonHK120_HKMetadataKeyAlpineSlopeGrade},
    {@"HKMetadataKeyAverageSpeed", CharonHK120_HKMetadataKeyAverageSpeed},
    {@"HKMetadataKeyElevationAscended", CharonHK120_HKMetadataKeyElevationAscended},
    {@"HKMetadataKeyElevationDescended", CharonHK120_HKMetadataKeyElevationDescended},
    {@"HKMetadataKeyMaximumSpeed", CharonHK120_HKMetadataKeyMaximumSpeed},
    {@"HKQuantityTypeIdentifierDistanceDownhillSnowSports", CharonHK120_HKQuantityTypeIdentifierDistanceDownhillSnowSports},
    {@"HKCategoryTypeIdentifierAbdominalCramps", CharonHKMeasured_HKCategoryTypeIdentifierAbdominalCramps},
    {@"HKCategoryTypeIdentifierAcne", CharonHKMeasured_HKCategoryTypeIdentifierAcne},
    {@"HKCategoryTypeIdentifierAppetiteChanges", CharonHKMeasured_HKCategoryTypeIdentifierAppetiteChanges},
    {@"HKCategoryTypeIdentifierAppleWalkingSteadinessEvent", CharonHKMeasured_HKCategoryTypeIdentifierAppleWalkingSteadinessEvent},
    {@"HKCategoryTypeIdentifierAudioExposureEvent", CharonHKMeasured_HKCategoryTypeIdentifierAudioExposureEvent},
    {@"HKCategoryTypeIdentifierBladderIncontinence", CharonHKMeasured_HKCategoryTypeIdentifierBladderIncontinence},
    {@"HKCategoryTypeIdentifierBloating", CharonHKMeasured_HKCategoryTypeIdentifierBloating},
    {@"HKCategoryTypeIdentifierBreastPain", CharonHKMeasured_HKCategoryTypeIdentifierBreastPain},
    {@"HKCategoryTypeIdentifierChestTightnessOrPain", CharonHKMeasured_HKCategoryTypeIdentifierChestTightnessOrPain},
    {@"HKCategoryTypeIdentifierChills", CharonHKMeasured_HKCategoryTypeIdentifierChills},
    {@"HKCategoryTypeIdentifierConstipation", CharonHKMeasured_HKCategoryTypeIdentifierConstipation},
    {@"HKCategoryTypeIdentifierContraceptive", CharonHKMeasured_HKCategoryTypeIdentifierContraceptive},
    {@"HKCategoryTypeIdentifierCoughing", CharonHKMeasured_HKCategoryTypeIdentifierCoughing},
    {@"HKCategoryTypeIdentifierDiarrhea", CharonHKMeasured_HKCategoryTypeIdentifierDiarrhea},
    {@"HKCategoryTypeIdentifierDizziness", CharonHKMeasured_HKCategoryTypeIdentifierDizziness},
    {@"HKCategoryTypeIdentifierDrySkin", CharonHKMeasured_HKCategoryTypeIdentifierDrySkin},
    {@"HKCategoryTypeIdentifierEnvironmentalAudioExposureEvent", CharonHKMeasured_HKCategoryTypeIdentifierEnvironmentalAudioExposureEvent},
    {@"HKCategoryTypeIdentifierFainting", CharonHKMeasured_HKCategoryTypeIdentifierFainting},
    {@"HKCategoryTypeIdentifierFatigue", CharonHKMeasured_HKCategoryTypeIdentifierFatigue},
    {@"HKCategoryTypeIdentifierFever", CharonHKMeasured_HKCategoryTypeIdentifierFever},
    {@"HKCategoryTypeIdentifierGeneralizedBodyAche", CharonHKMeasured_HKCategoryTypeIdentifierGeneralizedBodyAche},
    {@"HKCategoryTypeIdentifierHairLoss", CharonHKMeasured_HKCategoryTypeIdentifierHairLoss},
    {@"HKCategoryTypeIdentifierHandwashingEvent", CharonHKMeasured_HKCategoryTypeIdentifierHandwashingEvent},
    {@"HKCategoryTypeIdentifierHeadache", CharonHKMeasured_HKCategoryTypeIdentifierHeadache},
    {@"HKCategoryTypeIdentifierHeadphoneAudioExposureEvent", CharonHKMeasured_HKCategoryTypeIdentifierHeadphoneAudioExposureEvent},
    {@"HKCategoryTypeIdentifierHeartburn", CharonHKMeasured_HKCategoryTypeIdentifierHeartburn},
    {@"HKCategoryTypeIdentifierHighHeartRateEvent", CharonHKMeasured_HKCategoryTypeIdentifierHighHeartRateEvent},
    {@"HKCategoryTypeIdentifierHotFlashes", CharonHKMeasured_HKCategoryTypeIdentifierHotFlashes},
    {@"HKCategoryTypeIdentifierInfrequentMenstrualCycles", CharonHKMeasured_HKCategoryTypeIdentifierInfrequentMenstrualCycles},
    {@"HKCategoryTypeIdentifierIrregularHeartRhythmEvent", CharonHKMeasured_HKCategoryTypeIdentifierIrregularHeartRhythmEvent},
    {@"HKCategoryTypeIdentifierIrregularMenstrualCycles", CharonHKMeasured_HKCategoryTypeIdentifierIrregularMenstrualCycles},
    {@"HKCategoryTypeIdentifierLactation", CharonHKMeasured_HKCategoryTypeIdentifierLactation},
    {@"HKCategoryTypeIdentifierLossOfSmell", CharonHKMeasured_HKCategoryTypeIdentifierLossOfSmell},
    {@"HKCategoryTypeIdentifierLossOfTaste", CharonHKMeasured_HKCategoryTypeIdentifierLossOfTaste},
    {@"HKCategoryTypeIdentifierLowCardioFitnessEvent", CharonHKMeasured_HKCategoryTypeIdentifierLowCardioFitnessEvent},
    {@"HKCategoryTypeIdentifierLowHeartRateEvent", CharonHKMeasured_HKCategoryTypeIdentifierLowHeartRateEvent},
    {@"HKCategoryTypeIdentifierLowerBackPain", CharonHKMeasured_HKCategoryTypeIdentifierLowerBackPain},
    {@"HKCategoryTypeIdentifierMemoryLapse", CharonHKMeasured_HKCategoryTypeIdentifierMemoryLapse},
    {@"HKCategoryTypeIdentifierMoodChanges", CharonHKMeasured_HKCategoryTypeIdentifierMoodChanges},
    {@"HKCategoryTypeIdentifierNausea", CharonHKMeasured_HKCategoryTypeIdentifierNausea},
    {@"HKCategoryTypeIdentifierNightSweats", CharonHKMeasured_HKCategoryTypeIdentifierNightSweats},
    {@"HKCategoryTypeIdentifierPelvicPain", CharonHKMeasured_HKCategoryTypeIdentifierPelvicPain},
    {@"HKCategoryTypeIdentifierPersistentIntermenstrualBleeding", CharonHKMeasured_HKCategoryTypeIdentifierPersistentIntermenstrualBleeding},
    {@"HKCategoryTypeIdentifierPregnancy", CharonHKMeasured_HKCategoryTypeIdentifierPregnancy},
    {@"HKCategoryTypeIdentifierPregnancyTestResult", CharonHKMeasured_HKCategoryTypeIdentifierPregnancyTestResult},
    {@"HKCategoryTypeIdentifierProgesteroneTestResult", CharonHKMeasured_HKCategoryTypeIdentifierProgesteroneTestResult},
    {@"HKCategoryTypeIdentifierProlongedMenstrualPeriods", CharonHKMeasured_HKCategoryTypeIdentifierProlongedMenstrualPeriods},
    {@"HKCategoryTypeIdentifierRapidPoundingOrFlutteringHeartbeat", CharonHKMeasured_HKCategoryTypeIdentifierRapidPoundingOrFlutteringHeartbeat},
    {@"HKCategoryTypeIdentifierRunnyNose", CharonHKMeasured_HKCategoryTypeIdentifierRunnyNose},
    {@"HKCategoryTypeIdentifierShortnessOfBreath", CharonHKMeasured_HKCategoryTypeIdentifierShortnessOfBreath},
    {@"HKCategoryTypeIdentifierSinusCongestion", CharonHKMeasured_HKCategoryTypeIdentifierSinusCongestion},
    {@"HKCategoryTypeIdentifierSkippedHeartbeat", CharonHKMeasured_HKCategoryTypeIdentifierSkippedHeartbeat},
    {@"HKCategoryTypeIdentifierSleepChanges", CharonHKMeasured_HKCategoryTypeIdentifierSleepChanges},
    {@"HKCategoryTypeIdentifierSoreThroat", CharonHKMeasured_HKCategoryTypeIdentifierSoreThroat},
    {@"HKCategoryTypeIdentifierToothbrushingEvent", CharonHKMeasured_HKCategoryTypeIdentifierToothbrushingEvent},
    {@"HKCategoryTypeIdentifierVaginalDryness", CharonHKMeasured_HKCategoryTypeIdentifierVaginalDryness},
    {@"HKCategoryTypeIdentifierVomiting", CharonHKMeasured_HKCategoryTypeIdentifierVomiting},
    {@"HKCategoryTypeIdentifierWheezing", CharonHKMeasured_HKCategoryTypeIdentifierWheezing},
    {@"HKCharacteristicTypeIdentifierActivityMoveMode", CharonHKMeasured_HKCharacteristicTypeIdentifierActivityMoveMode},
    {@"HKClinicalTypeIdentifierCoverageRecord", CharonHKMeasured_HKClinicalTypeIdentifierCoverageRecord},
    {@"HKDataTypeIdentifierHeartbeatSeries", CharonHKMeasured_HKDataTypeIdentifierHeartbeatSeries},
    {@"HKFHIRReleaseDSTU2", CharonHKMeasured_HKFHIRReleaseDSTU2},
    {@"HKFHIRReleaseR4", CharonHKMeasured_HKFHIRReleaseR4},
    {@"HKFHIRReleaseUnknown", CharonHKMeasured_HKFHIRReleaseUnknown},
    {@"HKFHIRResourceTypeCoverage", CharonHKMeasured_HKFHIRResourceTypeCoverage},
    {@"HKFHIRResourceTypeMedicationRequest", CharonHKMeasured_HKFHIRResourceTypeMedicationRequest},
    {@"HKMedicationDoseEventTypeIdentifierMedicationDoseEvent", CharonHKMeasured_HKMedicationDoseEventTypeIdentifierMedicationDoseEvent},
    {@"HKMetadataKeyAlgorithmVersion", CharonHKMeasured_HKMetadataKeyAlgorithmVersion},
    {@"HKMetadataKeyAppleDeviceCalibrated", CharonHKMeasured_HKMetadataKeyAppleDeviceCalibrated},
    {@"HKMetadataKeyAppleECGAlgorithmVersion", CharonHKMeasured_HKMetadataKeyAppleECGAlgorithmVersion},
    {@"HKMetadataKeyAudioExposureDuration", CharonHKMeasured_HKMetadataKeyAudioExposureDuration},
    {@"HKMetadataKeyAudioExposureLevel", CharonHKMeasured_HKMetadataKeyAudioExposureLevel},
    {@"HKMetadataKeyAverageMETs", CharonHKMeasured_HKMetadataKeyAverageMETs},
    {@"HKMetadataKeyBarometricPressure", CharonHKMeasured_HKMetadataKeyBarometricPressure},
    {@"HKMetadataKeyDateOfEarliestDataUsedForEstimate", CharonHKMeasured_HKMetadataKeyDateOfEarliestDataUsedForEstimate},
    {@"HKMetadataKeyDevicePlacementSide", CharonHKMeasured_HKMetadataKeyDevicePlacementSide},
    {@"HKMetadataKeyGlassesPrescriptionDescription", CharonHKMeasured_HKMetadataKeyGlassesPrescriptionDescription},
    {@"HKMetadataKeyHeartRateEventThreshold", CharonHKMeasured_HKMetadataKeyHeartRateEventThreshold},
    {@"HKMetadataKeyHeartRateRecoveryActivityDuration", CharonHKMeasured_HKMetadataKeyHeartRateRecoveryActivityDuration},
    {@"HKMetadataKeyHeartRateRecoveryActivityType", CharonHKMeasured_HKMetadataKeyHeartRateRecoveryActivityType},
    {@"HKMetadataKeyHeartRateRecoveryMaxObservedRecoveryHeartRate", CharonHKMeasured_HKMetadataKeyHeartRateRecoveryMaxObservedRecoveryHeartRate},
    {@"HKMetadataKeyHeartRateRecoveryTestType", CharonHKMeasured_HKMetadataKeyHeartRateRecoveryTestType},
    {@"HKMetadataKeyLowCardioFitnessEventThreshold", CharonHKMeasured_HKMetadataKeyLowCardioFitnessEventThreshold},
    {@"HKMetadataKeyQuantityClampedToLowerBound", CharonHKMeasured_HKMetadataKeyQuantityClampedToLowerBound},
    {@"HKMetadataKeyQuantityClampedToUpperBound", CharonHKMeasured_HKMetadataKeyQuantityClampedToUpperBound},
    {@"HKMetadataKeySWOLFScore", CharonHKMeasured_HKMetadataKeySWOLFScore},
    {@"HKMetadataKeySessionEstimate", CharonHKMeasured_HKMetadataKeySessionEstimate},
    {@"HKMetadataKeyUserMotionContext", CharonHKMeasured_HKMetadataKeyUserMotionContext},
    {@"HKMetadataKeyVO2MaxValue", CharonHKMeasured_HKMetadataKeyVO2MaxValue},
    {@"HKPredicateKeyPathAverage", CharonHKMeasured_HKPredicateKeyPathAverage},
    {@"HKPredicateKeyPathAverageHeartRate", CharonHKMeasured_HKPredicateKeyPathAverageHeartRate},
    {@"HKPredicateKeyPathCount", CharonHKMeasured_HKPredicateKeyPathCount},
    {@"HKPredicateKeyPathECGClassification", CharonHKMeasured_HKPredicateKeyPathECGClassification},
    {@"HKPredicateKeyPathECGSymptomsStatus", CharonHKMeasured_HKPredicateKeyPathECGSymptomsStatus},
    {@"HKPredicateKeyPathMax", CharonHKMeasured_HKPredicateKeyPathMax},
    {@"HKPredicateKeyPathMin", CharonHKMeasured_HKPredicateKeyPathMin},
    {@"HKPredicateKeyPathMostRecent", CharonHKMeasured_HKPredicateKeyPathMostRecent},
    {@"HKPredicateKeyPathMostRecentDuration", CharonHKMeasured_HKPredicateKeyPathMostRecentDuration},
    {@"HKPredicateKeyPathMostRecentEndDate", CharonHKMeasured_HKPredicateKeyPathMostRecentEndDate},
    {@"HKPredicateKeyPathMostRecentStartDate", CharonHKMeasured_HKPredicateKeyPathMostRecentStartDate},
    {@"HKPredicateKeyPathStatus", CharonHKMeasured_HKPredicateKeyPathStatus},
    {@"HKPredicateKeyPathWorkoutActivity", CharonHKMeasured_HKPredicateKeyPathWorkoutActivity},
    {@"HKPredicateKeyPathWorkoutActivityAverageQuantity", CharonHKMeasured_HKPredicateKeyPathWorkoutActivityAverageQuantity},
    {@"HKPredicateKeyPathWorkoutActivityDuration", CharonHKMeasured_HKPredicateKeyPathWorkoutActivityDuration},
    {@"HKPredicateKeyPathWorkoutActivityEndDate", CharonHKMeasured_HKPredicateKeyPathWorkoutActivityEndDate},
    {@"HKPredicateKeyPathWorkoutActivityMaximumQuantity", CharonHKMeasured_HKPredicateKeyPathWorkoutActivityMaximumQuantity},
    {@"HKPredicateKeyPathWorkoutActivityMinimumQuantity", CharonHKMeasured_HKPredicateKeyPathWorkoutActivityMinimumQuantity},
    {@"HKPredicateKeyPathWorkoutActivityStartDate", CharonHKMeasured_HKPredicateKeyPathWorkoutActivityStartDate},
    {@"HKPredicateKeyPathWorkoutActivitySumQuantity", CharonHKMeasured_HKPredicateKeyPathWorkoutActivitySumQuantity},
    {@"HKPredicateKeyPathWorkoutActivityType", CharonHKMeasured_HKPredicateKeyPathWorkoutActivityType},
    {@"HKPredicateKeyPathWorkoutAverageQuantity", CharonHKMeasured_HKPredicateKeyPathWorkoutAverageQuantity},
    {@"HKPredicateKeyPathWorkoutMaximumQuantity", CharonHKMeasured_HKPredicateKeyPathWorkoutMaximumQuantity},
    {@"HKPredicateKeyPathWorkoutMinimumQuantity", CharonHKMeasured_HKPredicateKeyPathWorkoutMinimumQuantity},
    {@"HKPredicateKeyPathWorkoutSumQuantity", CharonHKMeasured_HKPredicateKeyPathWorkoutSumQuantity},
    {@"HKQuantityTypeIdentifierAppleMoveTime", CharonHKMeasured_HKQuantityTypeIdentifierAppleMoveTime},
    {@"HKQuantityTypeIdentifierAppleSleepingWristTemperature", CharonHKMeasured_HKQuantityTypeIdentifierAppleSleepingWristTemperature},
    {@"HKQuantityTypeIdentifierAppleStandTime", CharonHKMeasured_HKQuantityTypeIdentifierAppleStandTime},
    {@"HKQuantityTypeIdentifierAppleWalkingSteadiness", CharonHKMeasured_HKQuantityTypeIdentifierAppleWalkingSteadiness},
    {@"HKQuantityTypeIdentifierAtrialFibrillationBurden", CharonHKMeasured_HKQuantityTypeIdentifierAtrialFibrillationBurden},
    {@"HKQuantityTypeIdentifierEnvironmentalAudioExposure", CharonHKMeasured_HKQuantityTypeIdentifierEnvironmentalAudioExposure},
    {@"HKQuantityTypeIdentifierEnvironmentalSoundReduction", CharonHKMeasured_HKQuantityTypeIdentifierEnvironmentalSoundReduction},
    {@"HKQuantityTypeIdentifierHeadphoneAudioExposure", CharonHKMeasured_HKQuantityTypeIdentifierHeadphoneAudioExposure},
    {@"HKQuantityTypeIdentifierHeartRateRecoveryOneMinute", CharonHKMeasured_HKQuantityTypeIdentifierHeartRateRecoveryOneMinute},
    {@"HKQuantityTypeIdentifierNumberOfAlcoholicBeverages", CharonHKMeasured_HKQuantityTypeIdentifierNumberOfAlcoholicBeverages},
    {@"HKQuantityTypeIdentifierRunningGroundContactTime", CharonHKMeasured_HKQuantityTypeIdentifierRunningGroundContactTime},
    {@"HKQuantityTypeIdentifierRunningPower", CharonHKMeasured_HKQuantityTypeIdentifierRunningPower},
    {@"HKQuantityTypeIdentifierRunningSpeed", CharonHKMeasured_HKQuantityTypeIdentifierRunningSpeed},
    {@"HKQuantityTypeIdentifierRunningStrideLength", CharonHKMeasured_HKQuantityTypeIdentifierRunningStrideLength},
    {@"HKQuantityTypeIdentifierRunningVerticalOscillation", CharonHKMeasured_HKQuantityTypeIdentifierRunningVerticalOscillation},
    {@"HKQuantityTypeIdentifierSixMinuteWalkTestDistance", CharonHKMeasured_HKQuantityTypeIdentifierSixMinuteWalkTestDistance},
    {@"HKQuantityTypeIdentifierStairAscentSpeed", CharonHKMeasured_HKQuantityTypeIdentifierStairAscentSpeed},
    {@"HKQuantityTypeIdentifierStairDescentSpeed", CharonHKMeasured_HKQuantityTypeIdentifierStairDescentSpeed},
    {@"HKQuantityTypeIdentifierUnderwaterDepth", CharonHKMeasured_HKQuantityTypeIdentifierUnderwaterDepth},
    {@"HKQuantityTypeIdentifierWalkingAsymmetryPercentage", CharonHKMeasured_HKQuantityTypeIdentifierWalkingAsymmetryPercentage},
    {@"HKQuantityTypeIdentifierWalkingDoubleSupportPercentage", CharonHKMeasured_HKQuantityTypeIdentifierWalkingDoubleSupportPercentage},
    {@"HKQuantityTypeIdentifierWalkingSpeed", CharonHKMeasured_HKQuantityTypeIdentifierWalkingSpeed},
    {@"HKQuantityTypeIdentifierWalkingStepLength", CharonHKMeasured_HKQuantityTypeIdentifierWalkingStepLength},
    {@"HKQuantityTypeIdentifierWaterTemperature", CharonHKMeasured_HKQuantityTypeIdentifierWaterTemperature},
    {@"HKVerifiableClinicalRecordCredentialTypeCOVID19", CharonHKMeasured_HKVerifiableClinicalRecordCredentialTypeCOVID19},
    {@"HKVerifiableClinicalRecordCredentialTypeImmunization", CharonHKMeasured_HKVerifiableClinicalRecordCredentialTypeImmunization},
    {@"HKVerifiableClinicalRecordCredentialTypeLaboratory", CharonHKMeasured_HKVerifiableClinicalRecordCredentialTypeLaboratory},
    {@"HKVerifiableClinicalRecordCredentialTypeRecovery", CharonHKMeasured_HKVerifiableClinicalRecordCredentialTypeRecovery},
    {@"HKVerifiableClinicalRecordSourceTypeEUDigitalCOVIDCertificate", CharonHKMeasured_HKVerifiableClinicalRecordSourceTypeEUDigitalCOVIDCertificate},
    {@"HKVerifiableClinicalRecordSourceTypeSMARTHealthCard", CharonHKMeasured_HKVerifiableClinicalRecordSourceTypeSMARTHealthCard},
    {@"HKVisionPrescriptionTypeIdentifier", CharonHKMeasured_HKVisionPrescriptionTypeIdentifier},
    {@"HKCategoryTypeIdentifierBleedingAfterPregnancy", CharonHKMeasured_HKCategoryTypeIdentifierBleedingAfterPregnancy},
    {@"HKCategoryTypeIdentifierBleedingDuringPregnancy", CharonHKMeasured_HKCategoryTypeIdentifierBleedingDuringPregnancy},
    {@"HKCategoryTypeIdentifierSleepApneaEvent", CharonHKMeasured_HKCategoryTypeIdentifierSleepApneaEvent},
    {@"HKClinicalTypeIdentifierClinicalNoteRecord", CharonHKMeasured_HKClinicalTypeIdentifierClinicalNoteRecord},
    {@"HKDataTypeIdentifierStateOfMind", CharonHKMeasured_HKDataTypeIdentifierStateOfMind},
    {@"HKFHIRResourceTypeDiagnosticReport", CharonHKMeasured_HKFHIRResourceTypeDiagnosticReport},
    {@"HKFHIRResourceTypeDocumentReference", CharonHKMeasured_HKFHIRResourceTypeDocumentReference},
    {@"HKMetadataKeyActivityType", CharonHKMeasured_HKMetadataKeyActivityType},
    {@"HKMetadataKeyAppleFitnessPlusSession", CharonHKMeasured_HKMetadataKeyAppleFitnessPlusSession},
    {@"HKMetadataKeyCyclingFunctionalThresholdPowerTestType", CharonHKMeasured_HKMetadataKeyCyclingFunctionalThresholdPowerTestType},
    {@"HKMetadataKeyHeadphoneGain", CharonHKMeasured_HKMetadataKeyHeadphoneGain},
    {@"HKMetadataKeyMaximumLightIntensity", CharonHKMeasured_HKMetadataKeyMaximumLightIntensity},
    {@"HKMetadataKeyPhysicalEffortEstimationType", CharonHKMeasured_HKMetadataKeyPhysicalEffortEstimationType},
    {@"HKMetadataKeyWaterSalinity", CharonHKMeasured_HKMetadataKeyWaterSalinity},
    {@"HKPredicateKeyPathWorkoutEffortRelationship", CharonHKMeasured_HKPredicateKeyPathWorkoutEffortRelationship},
    {@"HKQuantityTypeIdentifierAppleSleepingBreathingDisturbances", CharonHKMeasured_HKQuantityTypeIdentifierAppleSleepingBreathingDisturbances},
    {@"HKQuantityTypeIdentifierCrossCountrySkiingSpeed", CharonHKMeasured_HKQuantityTypeIdentifierCrossCountrySkiingSpeed},
    {@"HKQuantityTypeIdentifierCyclingCadence", CharonHKMeasured_HKQuantityTypeIdentifierCyclingCadence},
    {@"HKQuantityTypeIdentifierCyclingFunctionalThresholdPower", CharonHKMeasured_HKQuantityTypeIdentifierCyclingFunctionalThresholdPower},
    {@"HKQuantityTypeIdentifierCyclingPower", CharonHKMeasured_HKQuantityTypeIdentifierCyclingPower},
    {@"HKQuantityTypeIdentifierCyclingSpeed", CharonHKMeasured_HKQuantityTypeIdentifierCyclingSpeed},
    {@"HKQuantityTypeIdentifierDistanceCrossCountrySkiing", CharonHKMeasured_HKQuantityTypeIdentifierDistanceCrossCountrySkiing},
    {@"HKQuantityTypeIdentifierDistancePaddleSports", CharonHKMeasured_HKQuantityTypeIdentifierDistancePaddleSports},
    {@"HKQuantityTypeIdentifierDistanceRowing", CharonHKMeasured_HKQuantityTypeIdentifierDistanceRowing},
    {@"HKQuantityTypeIdentifierDistanceSkatingSports", CharonHKMeasured_HKQuantityTypeIdentifierDistanceSkatingSports},
    {@"HKQuantityTypeIdentifierEstimatedWorkoutEffortScore", CharonHKMeasured_HKQuantityTypeIdentifierEstimatedWorkoutEffortScore},
    {@"HKQuantityTypeIdentifierPaddleSportsSpeed", CharonHKMeasured_HKQuantityTypeIdentifierPaddleSportsSpeed},
    {@"HKQuantityTypeIdentifierPhysicalEffort", CharonHKMeasured_HKQuantityTypeIdentifierPhysicalEffort},
    {@"HKQuantityTypeIdentifierRowingSpeed", CharonHKMeasured_HKQuantityTypeIdentifierRowingSpeed},
    {@"HKQuantityTypeIdentifierTimeInDaylight", CharonHKMeasured_HKQuantityTypeIdentifierTimeInDaylight},
    {@"HKQuantityTypeIdentifierWorkoutEffortScore", CharonHKMeasured_HKQuantityTypeIdentifierWorkoutEffortScore},
    {@"HKScoredAssessmentTypeIdentifierGAD7", CharonHKMeasured_HKScoredAssessmentTypeIdentifierGAD7},
    {@"HKScoredAssessmentTypeIdentifierPHQ9", CharonHKMeasured_HKScoredAssessmentTypeIdentifierPHQ9},
    {@"HKMetadataKeyAppleFitnessPlusCatalogIdentifier", CharonHKMeasured_HKMetadataKeyAppleFitnessPlusCatalogIdentifier},
    {@"HKDataTypeIdentifierUserAnnotatedMedicationConcept", CharonHKMeasured_HKDataTypeIdentifierUserAnnotatedMedicationConcept},
    {@"HKHealthConceptDomainMedication", CharonHKMeasured_HKHealthConceptDomainMedication},
    {@"HKPredicateKeyPathLogOrigin", CharonHKMeasured_HKPredicateKeyPathLogOrigin},
    {@"HKPredicateKeyPathMedicationConceptIdentifier", CharonHKMeasured_HKPredicateKeyPathMedicationConceptIdentifier},
    {@"HKPredicateKeyPathScheduledDate", CharonHKMeasured_HKPredicateKeyPathScheduledDate},
    {@"HKUserAnnotatedMedicationPredicateKeyPathHasSchedule", CharonHKMeasured_HKUserAnnotatedMedicationPredicateKeyPathHasSchedule},
    {@"HKUserAnnotatedMedicationPredicateKeyPathIsArchived", CharonHKMeasured_HKUserAnnotatedMedicationPredicateKeyPathIsArchived},
    {@"HKCategoryTypeIdentifierHypertensionEvent", CharonHKMeasured_HKCategoryTypeIdentifierHypertensionEvent},
    };
    size_t missing = 0;
    for (size_t index = 0; index < sizeof(rows) / sizeof(rows[0]); index++) {
        void *host = dlsym(RTLD_DEFAULT, rows[index].name.UTF8String);
        if (host == NULL) {
            missing++;
            printf("MISSING  %s  the host's HealthKit does not export it\n", rows[index].name.UTF8String);
            continue;
        }
        // dlsym answers the ADDRESS OF THE VARIABLE, and the variable holds a pointer to the string, so
        // the string is what that pointer holds - one dereference, the same one tools/corpus/host-probe.c's
        // value_of() makes. Reading the variable's own bytes as an object is a bus error, not a difference.
        NSString *theirs = (__bridge NSString *)(*(void **)host);
        CharonHKCompare(rows[index].name, rows[index].port, theirs);
    }
    if (missing > 0)
        printf("missing on the host: %lu of %lu\n", (unsigned long)missing,
               (unsigned long)(sizeof(rows) / sizeof(rows[0])));
}

// ---------------------------------------------------------------------- constants of 12.0

// Every constant the 12.0 object exports, the port's against the host's, by the name both know it by.
// The seven clinical type identifiers are the ones a reader would write from the name alone, and each
// is compared as a string and then used as the identifier of a clinical type, because a value that is
// right and a value the store can find are two different things.
static void CharonHKConstants12(void)
{
    CharonHKCompare(@"HKFHIRResourceTypeAllergyIntolerance", CharonHK120_HKFHIRResourceTypeAllergyIntolerance,
                    HKFHIRResourceTypeAllergyIntolerance);
    CharonHKCompare(@"HKFHIRResourceTypeCondition", CharonHK120_HKFHIRResourceTypeCondition, HKFHIRResourceTypeCondition);
    CharonHKCompare(@"HKFHIRResourceTypeImmunization", CharonHK120_HKFHIRResourceTypeImmunization,
                    HKFHIRResourceTypeImmunization);
    CharonHKCompare(@"HKFHIRResourceTypeMedicationDispense", CharonHK120_HKFHIRResourceTypeMedicationDispense,
                    HKFHIRResourceTypeMedicationDispense);
    CharonHKCompare(@"HKFHIRResourceTypeMedicationOrder", CharonHK120_HKFHIRResourceTypeMedicationOrder,
                    HKFHIRResourceTypeMedicationOrder);
    CharonHKCompare(@"HKFHIRResourceTypeMedicationStatement", CharonHK120_HKFHIRResourceTypeMedicationStatement,
                    HKFHIRResourceTypeMedicationStatement);
    CharonHKCompare(@"HKFHIRResourceTypeObservation", CharonHK120_HKFHIRResourceTypeObservation,
                    HKFHIRResourceTypeObservation);
    CharonHKCompare(@"HKFHIRResourceTypeProcedure", CharonHK120_HKFHIRResourceTypeProcedure, HKFHIRResourceTypeProcedure);
    CharonHKCompare(@"HKMetadataKeyCrossTrainerDistance", CharonHK120_HKMetadataKeyCrossTrainerDistance,
                    HKMetadataKeyCrossTrainerDistance);
    CharonHKCompare(@"HKMetadataKeyFitnessMachineDuration", CharonHK120_HKMetadataKeyFitnessMachineDuration,
                    HKMetadataKeyFitnessMachineDuration);
    CharonHKCompare(@"HKMetadataKeyIndoorBikeDistance", CharonHK120_HKMetadataKeyIndoorBikeDistance,
                    HKMetadataKeyIndoorBikeDistance);
    CharonHKCompare(@"HKPredicateKeyPathClinicalRecordFHIRResourceIdentifier",
                    CharonHK120_HKPredicateKeyPathClinicalRecordFHIRResourceIdentifier,
                    HKPredicateKeyPathClinicalRecordFHIRResourceIdentifier);
    CharonHKCompare(@"HKPredicateKeyPathClinicalRecordFHIRResourceType",
                    CharonHK120_HKPredicateKeyPathClinicalRecordFHIRResourceType,
                    HKPredicateKeyPathClinicalRecordFHIRResourceType);
    CharonHKCompare(@"HKPredicateKeyPathSum", CharonHK120_HKPredicateKeyPathSum, HKPredicateKeyPathSum);

    // The seven clinical type identifiers, each against the host's own symbol, and each used as the
    // identifier of a clinical type on both sides. The host answers for 12.0's seven and refuses the
    // two of 14.0 and 16.4, which are not in the port's 12.0 object, so only the seven are asked.
    struct { NSString *mine, *theirs, *label; } clinical[] = {
        {CharonHK120_HKClinicalTypeIdentifierAllergyRecord, HKClinicalTypeIdentifierAllergyRecord, @"allergy record"},
        {CharonHK120_HKClinicalTypeIdentifierConditionRecord, HKClinicalTypeIdentifierConditionRecord, @"condition record"},
        {CharonHK120_HKClinicalTypeIdentifierImmunizationRecord, HKClinicalTypeIdentifierImmunizationRecord,
         @"immunization record"},
        {CharonHK120_HKClinicalTypeIdentifierLabResultRecord, HKClinicalTypeIdentifierLabResultRecord, @"lab result record"},
        {CharonHK120_HKClinicalTypeIdentifierMedicationRecord, HKClinicalTypeIdentifierMedicationRecord,
         @"medication record"},
        {CharonHK120_HKClinicalTypeIdentifierProcedureRecord, HKClinicalTypeIdentifierProcedureRecord,
         @"procedure record"},
        {CharonHK120_HKClinicalTypeIdentifierVitalSignRecord, HKClinicalTypeIdentifierVitalSignRecord, @"vital sign record"},
    };
    for (size_t index = 0; index < sizeof(clinical) / sizeof(clinical[0]); index++) {
        NSString *what = [@"HKClinicalTypeIdentifier" stringByAppendingString:clinical[index].label];
        CharonHKCompare(what, clinical[index].mine, clinical[index].theirs);
        HKClinicalType *theirsType = [HKObjectType clinicalTypeForIdentifier:clinical[index].theirs];
        CharonHostHKClinicalType *mineType = [CharonHostHKObjectType clinicalTypeForIdentifier:clinical[index].mine];
        CharonHKCompareBool([what stringByAppendingString:@" is a clinical type"], mineType != nil, theirsType != nil);
        if (mineType && theirsType)
            CharonHKCompare([what stringByAppendingString:@" is the same clinical type"], mineType.identifier,
                            theirsType.identifier);
    }
}

// ---------------------------------------------------------------------- units

typedef struct {
    __unsafe_unretained NSString *name;
    __unsafe_unretained NSString *dimension;
    BOOL affine;
} HKUnitCase;

// The unit strings the port's own table holds, each with the unit of its dimension it is measured
// against. The reference is the first name of the dimension, so the factor of every other unit of it is
// read off the host through the host's own conversion.
static HKUnitCase CharonHKUnits[] = {
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
    // the products the SDK's own type table names for its types
    {@"count/s", @"count/s", NO}, {@"count/min", @"count/min", NO}, {@"m/s", @"m/s", NO},
    {@"L/min", @"L/min", NO}, {@"mg/dL", @"mg/dL", NO}, {@"ml/(kg*min)", @"ml/(kg*min)", NO},
    {@"kcal/(kg*hr)", @"kcal/(kg*hr)", NO}, {@"dBASPL", @"dBASPL", NO},
    // strings that are not units: both sides have to say so, and say it the same way
    {@"", @"", NO}, {@"not a unit", @"", NO}, {@"kg/", @"", NO}, {@"1/", @"", NO}, {@"*", @"", NO},
};
static const NSUInteger CharonHKUnitCaseCount = sizeof(CharonHKUnits) / sizeof(CharonHKUnits[0]);

static void CharonHKUnitCases(void)
{
    for (NSUInteger index = 0; index < CharonHKUnitCaseCount; index++) {
        NSString *name = CharonHKUnits[index].name;
        NSString *dimension = CharonHKUnits[index].dimension;
        NSString *label = [@"unitFromString:" stringByAppendingString:name];
        // A string neither side can make: the host raises, and the refusal is a behaviour the two have
        // to agree on just as much as an answer is, so it is asked for inside a @try on both sides.
        BOOL theirsRaised = NO, mineRaised = NO, theirsNil = NO, mineNil = NO;
        HKUnit *theirs = nil;
        CharonHostHKUnit *mine = nil;
        @try {
            theirs = [HKUnit unitFromString:name];
            theirsNil = theirs == nil;
        } @catch (NSException *exception) {
            theirsRaised = YES;
        }
        @try {
            mine = [CharonHostHKUnit unitFromString:name];
            mineNil = mine == nil;
        } @catch (NSException *exception) {
            mineRaised = YES;
        }
        CharonHKCompareBool([label stringByAppendingString:@" raises"], mineRaised, theirsRaised);
        CharonHKCompareBool([label stringByAppendingString:@" nil"], mineNil, theirsNil);
        if (!theirs || !mine)
            continue;
        if (!theirs || !mine)
            continue;
        CharonHKCompareFactors([label stringByAppendingString:@" unitString"], mine, theirs);
        CharonHKCompareBool([label stringByAppendingString:@" isNull"], mine.isNull, theirs.isNull);

        HKUnit *theirsReference = [HKUnit unitFromString:dimension];
        CharonHostHKUnit *mineReference = [CharonHostHKUnit unitFromString:dimension];
        if (!theirsReference || !mineReference)
            continue;
        // The factor of this unit in its dimension, each side measured through its own conversion.
        CharonHostHKQuantity *mineQuantity = [CharonHostHKQuantity quantityWithUnit:mine doubleValue:CharonHKProbe];
        HKQuantity *theirsQuantity = [HKQuantity quantityWithUnit:theirs doubleValue:CharonHKProbe];
        CharonHKCompareBool([label stringByAppendingString:@" isCompatibleWithUnit:itsDimension"],
                            [mineQuantity isCompatibleWithUnit:mineReference],
                            [theirsQuantity isCompatibleWithUnit:theirsReference]);
        if (![mineQuantity isCompatibleWithUnit:mineReference] || ![theirsQuantity isCompatibleWithUnit:theirsReference])
            continue;
        CharonHKCompareDouble([label stringByAppendingFormat:@" %g in %@", CharonHKProbe, dimension],
                              [mineQuantity doubleValueForUnit:mineReference],
                              [theirsQuantity doubleValueForUnit:theirsReference]);
        if (CharonHKUnits[index].affine) {
            CharonHostHKQuantity *mineSecond = [CharonHostHKQuantity quantityWithUnit:mine doubleValue:CharonHKSecondProbe];
            HKQuantity *theirsSecond = [HKQuantity quantityWithUnit:theirs doubleValue:CharonHKSecondProbe];
            CharonHKCompareDouble([label stringByAppendingFormat:@" %g in %@", CharonHKSecondProbe, dimension],
                                  [mineSecond doubleValueForUnit:mineReference],
                                  [theirsSecond doubleValueForUnit:theirsReference]);
        }
        // A unit of another dimension is not compatible, and a reciprocal is of the same dimension.
        HKUnit *theirsOther = [HKUnit unitFromString:@"count"];
        CharonHostHKUnit *mineOther = [CharonHostHKUnit unitFromString:@"count"];
        if (theirsOther && mineOther) {
            CharonHKCompareBool([label stringByAppendingString:@" isCompatibleWithUnit:count"],
                                [mineQuantity isCompatibleWithUnit:mineOther],
                                [theirsQuantity isCompatibleWithUnit:theirsOther]);
            // A temperature's reciprocal is refused on both sides, and a refusal is a behaviour, so it
            // is compared as one; everything else's reciprocal is compared by its factors.
            if (CharonHKUnits[index].affine) {
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
                CharonHKCompareBool([label stringByAppendingString:@" reciprocal raises"], mineRefused,
                                    theirsRefused);
            } else {
                CharonHostHKUnit *mineReciprocal = [mine reciprocalUnit];
                HKUnit *theirsReciprocal = [theirs reciprocalUnit];
                CharonHKCompareFactors([label stringByAppendingString:@" reciprocal"], mineReciprocal,
                                       theirsReciprocal);
            }
        }
    }
}

// ------------------------------------------------------------------ arithmetic

// The four operations the header gives a unit, each asked of a pair of the same dimension and the
// answer compared two ways: the string the unit writes, and its factor against the same reference,
// which is what tells a product right in name and wrong in factor.
static void CharonHKUnitArithmetic(void)
{
    NSArray *pairs = @[@[ @"m", @"s" ], @[ @"m", @"min" ], @[ @"kg", @"m" ], @[ @"mL", @"kg" ],
                        @[ @"kcal", @"hr" ], @[ @"J", @"K" ], @[ @"count", @"min" ], @[ @"L", @"hr" ]];
    static NSInteger powers[] = { -2, -1, 2, 3 };
    for (NSArray *pair in pairs) {
        HKUnit *theirsLeft = [HKUnit unitFromString:pair[0]], *theirsRight = [HKUnit unitFromString:pair[1]];
        CharonHostHKUnit *mineLeft = [CharonHostHKUnit unitFromString:pair[0]],
                           *mineRight = [CharonHostHKUnit unitFromString:pair[1]];
        if (!theirsLeft || !theirsRight || !mineLeft || !mineRight)
            continue;
        NSString *label = [NSString stringWithFormat:@"%@ x %@", pair[0], pair[1]];
        HKUnit *theirsProduct = [theirsLeft unitMultipliedByUnit:theirsRight];
        CharonHostHKUnit *mineProduct = [mineLeft unitMultipliedByUnit:mineRight];
        CharonHKCompareFactors([label stringByAppendingString:@" product"], mineProduct, theirsProduct);
        HKUnit *theirsQuotient = [theirsLeft unitDividedByUnit:theirsRight];
        CharonHostHKUnit *mineQuotient = [mineLeft unitDividedByUnit:mineRight];
        CharonHKCompareFactors([label stringByAppendingString:@" quotient"], mineQuotient, theirsQuotient);

        // The factor of a product, each side measured by converting a quantity in the left-hand unit
        // into the product. A product has no dimension of its own on either side, so what is compared
        // is the number each side answers, which is where a product that is right in its string and
        // wrong in its factors shows.
        // A product has no dimension of its own, so what is compared is whether the two accept the
        // same conversion, and the round trip through the product when they do.
        CharonHostHKQuantity *mineValue = [CharonHostHKQuantity quantityWithUnit:mineLeft doubleValue:CharonHKProbe];
        HKQuantity *theirsValue = [HKQuantity quantityWithUnit:theirsLeft doubleValue:CharonHKProbe];
        CharonHKCompareBool([label stringByAppendingString:@" takes a conversion into the product"],
                            [mineValue isCompatibleWithUnit:mineProduct],
                            [theirsValue isCompatibleWithUnit:theirsProduct]);
        CharonHostHKQuantity *mineQuotientValue = [CharonHostHKQuantity quantityWithUnit:mineLeft doubleValue:CharonHKProbe];
        HKQuantity *theirsQuotientValue = [HKQuantity quantityWithUnit:theirsLeft doubleValue:CharonHKProbe];
        CharonHKCompareBool([label stringByAppendingString:@" takes a conversion into the quotient"],
                            [mineQuotientValue isCompatibleWithUnit:mineQuotient],
                            [theirsQuotientValue isCompatibleWithUnit:theirsQuotient]);
        for (NSUInteger step = 0; step < 4; step++) {
            HKUnit *theirsPower = [theirsLeft unitRaisedToPower:powers[step]];
            CharonHostHKUnit *minePower = [mineLeft unitRaisedToPower:powers[step]];
            CharonHKCompareFactors([NSString stringWithFormat:@"%@ raised to %ld", pair[0], (long)powers[step]],
                                   minePower, theirsPower);
        }
    }
    // A temperature cannot be multiplied, divided or raised to a power, and both sides raise.
    HKUnit *theirsCelsius = [HKUnit degreeCelsiusUnit], *theirsMetre = [HKUnit meterUnit];
    CharonHostHKUnit *mineCelsius = [CharonHostHKUnit degreeCelsiusUnit],
                       *mineMetre = [CharonHostHKUnit meterUnit];
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
        CharonHKCompareBool(label, mineRaised, theirsRaised);
    }
}

// ------------------------------------------------------- the factory methods

// Every prefixed factory method of the header, at every prefix its enum has, and then every plain
// one, on both sides. This is where the spelling of a prefix is answered, and it is a different
// question from the one the table above asks: the table holds the names the header's comments give,
// and these are the names the methods make.
typedef id (^CharonHKPrefixedFactory)(NSInteger);

static CharonHKPrefixedFactory CharonHKPortPrefixed(NSUInteger index)
{
    switch (index) {
    case 0:
        return ^id(NSInteger p) { return [CharonHostHKUnit gramUnitWithMetricPrefix:(HKMetricPrefix)p]; };
    case 1:
        return ^id(NSInteger p) { return [CharonHostHKUnit meterUnitWithMetricPrefix:(HKMetricPrefix)p]; };
    case 2:
        return ^id(NSInteger p) { return [CharonHostHKUnit literUnitWithMetricPrefix:(HKMetricPrefix)p]; };
    case 3:
        return ^id(NSInteger p) { return [CharonHostHKUnit pascalUnitWithMetricPrefix:(HKMetricPrefix)p]; };
    case 4:
        return ^id(NSInteger p) { return [CharonHostHKUnit secondUnitWithMetricPrefix:(HKMetricPrefix)p]; };
    case 5:
        return ^id(NSInteger p) { return [CharonHostHKUnit jouleUnitWithMetricPrefix:(HKMetricPrefix)p]; };
    default:
        return ^id(NSInteger p) { return [CharonHostHKUnit siemenUnitWithMetricPrefix:(HKMetricPrefix)p]; };
    }
}

static CharonHKPrefixedFactory CharonHKSystemPrefixed(NSUInteger index)
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

static void CharonHKPrefixedFactories(void)
{
    // The seven prefixed factories of the iOS 8.0 surface, which is the surface this library carries.
    // The header's later ones - hertzUnitWithMetricPrefix: of 13.0, voltUnitWithMetricPrefix: of 14.0
    // and wattUnitWithMetricPrefix: of 16.0 - are asked for in the group of their own release, and
    // asking the host for them here would compare a unit this library does not yet make with one it
    // does.
    NSArray *factories = @[ @"gramUnitWithMetricPrefix:", @"meterUnitWithMetricPrefix:",
                            @"literUnitWithMetricPrefix:", @"pascalUnitWithMetricPrefix:",
                            @"secondUnitWithMetricPrefix:", @"jouleUnitWithMetricPrefix:",
                            @"siemenUnitWithMetricPrefix:" ];
    for (NSInteger prefix = HKMetricPrefixNone; prefix <= HKMetricPrefixTera; prefix++) {
        for (NSUInteger index = 0; index < factories.count; index++) {
            NSString *label = [NSString stringWithFormat:@"%@ prefix %ld", factories[index], (long)prefix];
            HKUnit *theirs = nil;
            CharonHostHKUnit *mine = nil;
            BOOL theirsRefused = NO, mineRefused = NO;
            @try {
                theirs = (HKUnit *)CharonHKSystemPrefixed(index)(prefix);
                theirsRefused = theirs == nil;
            } @catch (NSException *exception) {
                theirsRefused = YES;
            }
            @try {
                mine = (CharonHostHKUnit *)CharonHKPortPrefixed(index)(prefix);
                mineRefused = mine == nil;
            } @catch (NSException *exception) {
                mineRefused = YES;
            }
            CharonHKCompareBool([label stringByAppendingString:@" answers"], !mineRefused, !theirsRefused);
            if (!theirs || !mine)
                continue;
            CharonHKCompare([label stringByAppendingString:@" unitString"], mine.unitString, theirs.unitString);
        }
    }
    // The plain factories, whose spelling question is the same. A selector the host's release has
    // dropped is asked for through respondsToSelector: and is not compared, because there is nothing
    // on that side to compare with.
    NSArray *plain = @[ @"gramUnit", @"ounceUnit", @"poundUnit", @"stoneUnit", @"meterUnit", @"inchUnit",
                        @"footUnit", @"yardUnit", @"mileUnit", @"literUnit", @"fluidOunceUSUnit",
                        @"fluidOunceImperialUnit", @"pintUSUnit", @"pintImperialUnit", @"cupUSUnit",
                        @"cupImperialUnit", @"pascalUnit", @"millimeterOfMercuryUnit",
                        @"centimeterOfWaterUnit", @"atmosphereUnit",
                        @"secondUnit", @"minuteUnit", @"hourUnit", @"dayUnit", @"jouleUnit",
                        @"kilocalorieUnit", @"calorieUnit", @"degreeCelsiusUnit",
                        @"degreeFahrenheitUnit", @"kelvinUnit", @"siemenUnit", @"countUnit",
                        @"percentUnit" ];
    // +[HKUnit kilojoulesUnit] and +[HKUnit milliseconds] are deliberately not asked for: no SDK
    // header of 16.4 or 26.2 declares either, so they are Apple's own and this library does not
    // answer them. The two units are in the table and +[HKUnit unitFromString:] reads them, which the
    // unit cases above already compare.
    for (NSString *name in plain) {
        SEL chosen = NSSelectorFromString(name);
        BOOL theirsHas = [HKUnit respondsToSelector:chosen];
        BOOL mineHas = [CharonHostHKUnit respondsToSelector:chosen];
        CharonHKCompareBool([name stringByAppendingString:@" exists"], mineHas, theirsHas);
        if (!theirsHas || !mineHas)
            continue;
        id theirs = [HKUnit performSelector:chosen];
        id mine = [CharonHostHKUnit performSelector:chosen];
        if (!theirs || !mine) {
            CharonHKCompareBool([name stringByAppendingString:@" answers"], mine != nil, theirs != nil);
            continue;
        }
        CharonHKCompare([name stringByAppendingString:@" unitString"], [mine unitString], [theirs unitString]);
    }
}

// ----------------------------------------------------------------- quantities

static void CharonHKQuantities(void)
{
    NSArray *units = @[ @"kg", @"g", @"m", @"cm", @"L", @"mL", @"kcal", @"kJ", @"min", @"hr", @"degC",
                        @"degF", @"K", @"mmHg", @"count", @"%", @"m/s", @"mg/dL" ];
    static const double values[] = { 0.0, 1.0, -1.0, 0.5, 2.5, -273.15, 1000.0, 1.0 / 3.0 };
    for (NSUInteger left = 0; left < units.count; left++) {
        for (NSUInteger right = 0; right < units.count; right++) {
            HKUnit *theirsLeft = [HKUnit unitFromString:units[left]], *theirsRight = [HKUnit unitFromString:units[right]];
            CharonHostHKUnit *mineLeft = [CharonHostHKUnit unitFromString:units[left]],
                               *mineRight = [CharonHostHKUnit unitFromString:units[right]];
            if (!theirsLeft || !theirsRight || !mineLeft || !mineRight)
                continue;
            for (NSUInteger step = 0; step < 8; step++) {
                HKQuantity *theirs = [HKQuantity quantityWithUnit:theirsLeft doubleValue:values[step]];
                CharonHostHKQuantity *mine = [CharonHostHKQuantity quantityWithUnit:mineLeft doubleValue:values[step]];
                NSString *label = [NSString stringWithFormat:@"%g %@ -> %@", values[step], units[left], units[right]];
                CharonHKCompareBool([label stringByAppendingString:@" isCompatibleWithUnit:"],
                                    [mine isCompatibleWithUnit:mineRight], [theirs isCompatibleWithUnit:theirsRight]);
                if (![mine isCompatibleWithUnit:mineRight] || ![theirs isCompatibleWithUnit:theirsRight])
                    continue;
                CharonHKCompareDouble([label stringByAppendingString:@" doubleValueForUnit:"],
                                      [mine doubleValueForUnit:mineRight], [theirs doubleValueForUnit:theirsRight]);
                CharonHKCompareInt([label stringByAppendingString:@" compare:itself"],
                                   [mine compare:mine], [theirs compare:theirs]);
                if (![mine isCompatibleWithUnit:mineLeft] || ![theirs isCompatibleWithUnit:theirsLeft])
                    continue;
                CharonHKCompareInt([label stringByAppendingString:@" compare:itsUnit"],
                                   [mine compare:mine], [theirs compare:theirs]);
            }
        }
    }
    // Two quantities of the same dimension order and against each other; two of different dimensions
    // raise on both sides.
    HKUnit *theirsKg = [HKUnit gramUnitWithMetricPrefix:HKMetricPrefixKilo];
    HKUnit *theirsG = [HKUnit gramUnit];
    HKUnit *theirsM = [HKUnit meterUnit];
    CharonHostHKUnit *mineKg = [CharonHostHKUnit gramUnitWithMetricPrefix:HKMetricPrefixKilo];
    CharonHostHKUnit *mineG = [CharonHostHKUnit gramUnit];
    CharonHostHKUnit *mineM = [CharonHostHKUnit meterUnit];
    HKQuantity *theirsHeavy = [HKQuantity quantityWithUnit:theirsKg doubleValue:2.0];
    HKQuantity *theirsLight = [HKQuantity quantityWithUnit:theirsG doubleValue:2500.0];
    CharonHostHKQuantity *mineHeavy = [CharonHostHKQuantity quantityWithUnit:mineKg doubleValue:2.0];
    CharonHostHKQuantity *mineLight = [CharonHostHKQuantity quantityWithUnit:mineG doubleValue:2500.0];
    CharonHKCompareInt(@"2 kg compare: 2500 g", [mineHeavy compare:mineLight], [theirsHeavy compare:theirsLight]);
    CharonHKCompareInt(@"2500 g compare: 2 kg", [mineLight compare:mineHeavy], [theirsLight compare:theirsHeavy]);
    HKQuantity *theirsMetre = [HKQuantity quantityWithUnit:theirsM doubleValue:1.0];
    CharonHostHKQuantity *mineMetre = [CharonHostHKQuantity quantityWithUnit:mineM doubleValue:1.0];
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
    CharonHKCompareBool(@"2 kg compare: 1 m raises", mineRaised, theirsRaised);
}

// ------------------------------------------------------------ the type table

// Every quantity type identifier the SDK's own header names a unit and an aggregation for, which is
// the port's table, is asked of the host: the aggregation the host records for it, and whether the
// host considers the port's unit, and the host's own unit, of it.
static void CharonHKTypeTable(void)
{
    for (NSUInteger index = 0; index < CharonHKQuantityTypeCount(); index++) {
        const CharonHKTypeEntry *entry = CharonHKQuantityTypeEntryAt(index);
        if (!entry)
            continue;
        NSString *identifier = entry->identifier;
        HKQuantityType *theirs = (HKQuantityType *)[HKObjectType quantityTypeForIdentifier:identifier];
        CharonHostHKQuantityType *mine = (CharonHostHKQuantityType *)[CharonHostHKObjectType quantityTypeForIdentifier:identifier];
        CharonHKCompareBool([identifier stringByAppendingString:@" a quantity type"], mine != nil, theirs != nil);
        if (!theirs || !mine)
            continue;
        // The aggregation is compared as the one the port's contract has, cumulative or discrete. The
        // header the port compiles against gives HKQuantityAggregationStyle two cases; the header whose
        // comment the table is read from names five, and the host answers the three later ones with a
        // case of their own. A caller of this library can only be told the two, so the two are what is
        // compared - and the ten types where the host's finer answer differs are named in run.sh and in
        // facts/HealthKit/HealthKit.md, so that the difference is written down rather than passed over.
        CharonHKCompareInt([identifier stringByAppendingString:@" aggregates cumulatively"],
                           (NSInteger)mine.aggregationStyle, (NSInteger)theirs.aggregationStyle == 0 ? 0 : 1);
        // A type the SDK counts in a string no unit can be made of - the header gives
        // `appleEffortScore` for one of them - is a refusal on both sides and is compared as one.
        BOOL mineRefused = NO, theirsRefused = NO;
        HKUnit *theirsUnit = nil;
        CharonHostHKUnit *mineUnit = nil;
        @try {
            theirsUnit = [HKUnit unitFromString:entry->unit];
        } @catch (NSException *exception) {
            theirsRefused = YES;
        }
        @try {
            mineUnit = [CharonHostHKUnit unitFromString:entry->unit];
        } @catch (NSException *exception) {
            mineRefused = YES;
        }
        CharonHKCompareBool([identifier stringByAppendingString:@" its unit raises"], mineRefused, theirsRefused);
        if (theirsUnit && mineUnit)
            CharonHKCompareBool([identifier stringByAppendingString:@" isCompatibleWithUnit:its own unit"],
                                [mine isCompatibleWithUnit:mineUnit], [theirs isCompatibleWithUnit:theirsUnit]);
        // A type of a count accepts a count and a fraction, and a type of a mass accepts neither.
        for (NSString *probe in @[ @"count", @"%", @"kg", @"m", @"s" ]) {
            HKUnit *theirsProbe = [HKUnit unitFromString:probe];
            CharonHostHKUnit *mineProbe = [CharonHostHKUnit unitFromString:probe];
            if (!theirsProbe || !mineProbe)
                continue;
            CharonHKCompareBool([identifier stringByAppendingFormat:@" isCompatibleWithUnit:%@", probe],
                                [mine isCompatibleWithUnit:mineProbe], [theirs isCompatibleWithUnit:theirsProbe]);
        }
    }
}


// ------------------------------------------------- the query objects' own properties
//
// Everything a query holds about itself, which is what the host's own query holds too, asked of both
// without a store anywhere: the type it is for, the predicate it was made with, the limit, the sort
// descriptors, the anchor, the interval and the options. This is the check that reaches HKQueries.m,
// which the unit and quantity cases never did - a mutation of -anchorDate: was invisible to them.

static void CharonHKQueryObjects(void)
{
    // The predicate this section compares. The host's own NSPredicate refuses a metadata key path
    // outside a HealthKit query, so the predicate is over a key path of the object itself, which both
    // sides build and evaluate the same way, and the copy semantics of what a query keeps is compared
    // with the host's on the same predicate.
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K.%K == %@", HKPredicateKeyPathMetadata,
                              HKMetadataKeySyncIdentifier, @"sync"];
    NSSortDescriptor *byDate = [NSSortDescriptor sortDescriptorWithKey:@"startDate" ascending:YES];
    NSDate *anchor = [NSDate dateWithTimeIntervalSince1970:1600000000];
    NSDateComponents *interval = [[NSDateComponents alloc] init];
    interval.day = 1;
    // One type per side, from that side's own factory. Built the other way round - the port's query on a
    // host's type - the port's -sampleType answers nil, because a host's HKQuantityType is not a subclass
    // of the port's HKSampleType, which is what measured mineIsKind=0 against a type the LAYOUT print
    // had already measured as 1.
    HKQuantityType *stepCount = [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierStepCount];
    HKQuantityType *heartRate = [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierHeartRate];
    CharonHostHKQuantityType *mineStepCount = [CharonHostHKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierStepCount];
    CharonHostHKQuantityType *mineHeartRate = [CharonHostHKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierHeartRate];
    if (!stepCount || !heartRate)
        return;


    // The check the coordinator asked for: the superclass of the port's own sample query, and the
    // offset of _objectType in it and in the class that declares it. If the two differ the object is
    // of a different layout than the code that reads it thinks, which is what a rename that did not
    // reach one file's superclass looks like from the inside.
    {
        Class mineClass = objc_getClass("CharonHostHKSampleQuery");
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
        // What the port's own -sampleType tests, and whether the type it was made with passes it: the
        // harness's declaration of the factory returns the host's HKQuantityType, so the class of what
        // comes back is the thing to look at.
        id mineType = [CharonHostHKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierHeartRate];
        (void)mineType;
        id theirsType = [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierHeartRate];
        // The print that answers difference 1, through CharonHKDescribe.
        printf("LAYOUT mineType=%s portSampleType=%s mineIsKind=%d | theirsType=%s hostSampleType=%s theirsIsKind=%d\n",
               CharonHKDescribe([mineType class]), CharonHKDescribe([CharonHostHKSampleType class]),
               [mineType isKindOfClass:[CharonHostHKSampleType class]] ? 1 : 0,
               CharonHKDescribe([theirsType class]), CharonHKDescribe([HKSampleType class]),
               [theirsType isKindOfClass:[HKSampleType class]] ? 1 : 0);
    }

    // The type a query is for, and the sample type under its own name, which is the same object.
    // The objects the predicate is evaluated against, and the answers both sides give for them. The
    // host's NSPredicate takes a metadata key path only where a HealthKit query is the context, so
    // these are a sample's shape: a dictionary of dictionaries, which is what a predicate over a
    // sample's metadata is written for.
    NSDictionary *matching = @{ @"metadata": @{ HKMetadataKeySyncIdentifier: @"sync" } };
    NSDictionary *mismatched = @{ @"metadata": @{ HKMetadataKeySyncIdentifier: @"other" } };
    // The collection query is the sixth of the six, and the port's own five-argument initialiser is
    // checked: the type, the predicate, the options, the anchor and the interval it keeps, and the
    // The host's own sample query on the same predicate, asked for once here so the collection block
    // below has something of the host's to compare against.
    HKSampleQuery *theirsByPredicate = [[HKSampleQuery alloc] initWithSampleType:stepCount
                                                                       predicate:predicate
                                                                           limit:HKObjectQueryNoLimit
                                                                    sortDescriptors:nil
                                                                     resultsHandler:nil];

    // predicate's own answer. The host's release of the class carries no five-argument initialiser the
    // 16.4 header declares and the one it does carry raises, so nothing is compared here that the
    // host cannot answer, and the host's own members are asked of the queries it does build, below.
    CharonHostHKStatisticsCollectionQuery *mineCollection =
        [[CharonHostHKStatisticsCollectionQuery alloc] initWithQuantityType:mineStepCount
                                                      quantitySamplePredicate:predicate
                                                                   options:HKStatisticsOptionCumulativeSum
                                                                anchorDate:anchor
                                                        intervalComponents:interval];
    CharonHKCompare(@"collection query anchorDate", mineCollection.anchorDate, anchor);
    CharonHKCompareInt(@"collection query options", (NSInteger)mineCollection.options,
                       (NSInteger)HKStatisticsOptionCumulativeSum);
    CharonHKCompareInt(@"collection query interval day", mineCollection.intervalComponents.day, (NSInteger)1);
    CharonHKCompareInt(@"collection query interval month", mineCollection.intervalComponents.month, (NSInteger)0);
    CharonHKCompare(@"collection query objectType identifier", mineCollection.objectType.identifier,
                    stepCount.identifier);
    // The predicate it was made with, and the answers it gives to a matching and a mismatching object.
    CharonHKCompare(@"collection query predicate", mineCollection.predicate, predicate);
    // The same two objects the block below uses. These two lines were still evaluating the predicate
    // against an object with no metadata key - the predicate reads metadata.<key>, so it found nothing and
    // the port answered NO, correctly, while the constant beside it said YES. The port was not wrong and
    // the expectation was; both now go through matching and mismatched.
    CharonHKCompareBool(@"collection query predicate evaluates a match",
                        [mineCollection.predicate evaluateWithObject:matching],
                        [theirsByPredicate.predicate evaluateWithObject:matching]);
    CharonHKCompareBool(@"collection query predicate rejects a mismatch",
                        [mineCollection.predicate evaluateWithObject:mismatched],
                        [theirsByPredicate.predicate evaluateWithObject:mismatched]);
    // and the same predicate as the host's own sample query and statistics query answer it, so the two
    // are compared rather than one against a constant
    CharonHostHKSampleQuery *mineByPredicate = [[CharonHostHKSampleQuery alloc] initWithSampleType:mineStepCount
                                                                                           predicate:predicate
                                                                                               limit:HKObjectQueryNoLimit
                                                                                        sortDescriptors:nil
                                                                                         resultsHandler:nil];
    CharonHKCompare(@"a sample query's predicate", mineByPredicate.predicate, theirsByPredicate.predicate);
    CharonHKCompareBool(@"that predicate evaluates a match",
                        [mineByPredicate.predicate evaluateWithObject:@{@"HKSourceSyncIdentifier": @"sync"}],
                        [theirsByPredicate.predicate evaluateWithObject:@{@"HKSourceSyncIdentifier": @"sync"}]);
    CharonHKCompareBool(@"that predicate rejects a mismatch",
                        [mineByPredicate.predicate evaluateWithObject:@{@"HKSourceSyncIdentifier": @"other"}],
                        [theirsByPredicate.predicate evaluateWithObject:@{@"HKSourceSyncIdentifier": @"other"}]);

    // A sample query: the limit and the sort descriptors it was made with, and the type again.
    HKSampleQuery *theirsSample = [[HKSampleQuery alloc] initWithSampleType:heartRate
                                                                 predicate:predicate
                                                                     limit:42
                                                          sortDescriptors:@[ byDate ]
                                                           resultsHandler:nil];
    CharonHostHKSampleQuery *mineSample = [[CharonHostHKSampleQuery alloc] initWithSampleType:mineHeartRate
                                                                               predicate:predicate
                                                                                   limit:42
                                                                        sortDescriptors:@[ byDate ]
                                                                         resultsHandler:nil];
    CharonHKCompare(@"sample query objectType identifier", mineSample.objectType.identifier, theirsSample.objectType.identifier);
    CharonHKCompare(@"sample query sampleType identifier", mineSample.sampleType.identifier, theirsSample.sampleType.identifier);
    CharonHKCompareInt(@"sample query limit", (NSInteger)mineSample.limit, (NSInteger)theirsSample.limit);
    CharonHKCompare(@"sample query sortDescriptors", mineSample.sortDescriptors, theirsSample.sortDescriptors);
    CharonHKCompare(@"sample query predicate", mineSample.predicate, theirsSample.predicate);

    // The limit and the sort descriptors of the sample query, when it is made without them.
    HKSampleQuery *theirsBare = [[HKSampleQuery alloc] initWithSampleType:stepCount
                                                                predicate:nil
                                                                    limit:HKObjectQueryNoLimit
                                                           sortDescriptors:nil
                                                            resultsHandler:nil];
    CharonHostHKSampleQuery *mineBare = [[CharonHostHKSampleQuery alloc] initWithSampleType:mineStepCount
                                                                                  predicate:nil
                                                                                      limit:HKObjectQueryNoLimit
                                                                           sortDescriptors:nil
                                                                            resultsHandler:nil];
    CharonHKCompareInt(@"a bare sample query's limit", (NSInteger)mineBare.limit, (NSInteger)theirsBare.limit);
    CharonHKCompare(@"a bare sample query's sortDescriptors", mineBare.sortDescriptors, theirsBare.sortDescriptors);
    CharonHKCompare(@"a bare sample query's predicate", mineBare.predicate, theirsBare.predicate);
    CharonHKCompare(@"a bare sample query's objectType identifier", mineBare.objectType.identifier,
                    theirsBare.objectType.identifier);

    // A statistics query: the type and the predicate, which are all it holds before it runs.
    HKStatisticsQuery *theirsStats = [[HKStatisticsQuery alloc] initWithQuantityType:heartRate
                                                          quantitySamplePredicate:predicate
                                                                           options:HKStatisticsOptionDiscreteAverage
                                                                    completionHandler:nil];
    CharonHostHKStatisticsQuery *mineStats = [[CharonHostHKStatisticsQuery alloc] initWithQuantityType:mineHeartRate
                                                                                        quantitySamplePredicate:predicate
                                                                                                     options:HKStatisticsOptionDiscreteAverage
                                                                                              completionHandler:nil];
    CharonHKCompare(@"statistics query objectType identifier", mineStats.objectType.identifier,
                    theirsStats.objectType.identifier);
    CharonHKCompare(@"statistics query predicate", mineStats.predicate, theirsStats.predicate);

    // A source query, whose type is the one it is for, and an anchored query, whose anchor is what it
    // was made with.
    HKSourceQuery *theirsSource = [[HKSourceQuery alloc] initWithSampleType:stepCount
                                                             samplePredicate:predicate
                                                           completionHandler:nil];
    CharonHostHKSourceQuery *mineSource = [[CharonHostHKSourceQuery alloc] initWithSampleType:mineStepCount
                                                                                     samplePredicate:predicate
                                                                                   completionHandler:nil];
    CharonHKCompare(@"source query objectType identifier", mineSource.objectType.identifier,
                    theirsSource.objectType.identifier);
    CharonHKCompare(@"source query predicate", mineSource.predicate, theirsSource.predicate);
}

// --------------------------------------------------------- the iOS 11.0 group
//
// What the group adds, asked of the host's own HealthKit and of this library's, with no store: the
// series type and the route type, the clinical type of an identifier, the FHIR resource's own members
// and the round trip of its archive, the two clinical-record predicates over the key paths the release
// spells "FHIRResource.identifier" and "FHIRResource.resourceType", and the three unit factories the
// release adds. A row the host's release does not have is skipped and said, never guessed.


@interface CharonHostHKStatistics : NSObject
@property (readonly, copy) CharonHostHKQuantity *sumQuantity;
- (nullable CharonHostHKQuantity *)mostRecentQuantity;
- (nullable CharonHostHKQuantity *)mostRecentQuantityForSource:(CharonHostHKSource *)source;
- (nullable NSDateInterval *)mostRecentQuantityDateInterval;
- (nullable NSDateInterval *)mostRecentQuantityDateIntervalForSource:(CharonHostHKSource *)source;
+ (instancetype)charon_statisticsForSamples:(NSArray *)samples options:(NSUInteger)options;
@end

@interface CharonHostHKWorkoutConfiguration : NSObject
- (instancetype)charon_initWithActivityType:(long)activityType
                                locationType:(long)locationType
                                  lapLength:(nullable HKQuantity *)lapLength
                        swimmingLocationType:(long)swimmingLocationType;
@property (readonly) long activityType;
@end

@interface CharonHostCharonHKStore : NSObject
+ (instancetype)sharedStore;
- (nullable NSArray *)objectsWithUUIDs:(NSArray<NSUUID *> *)uuids ofType:(HKObjectType *)type error:(NSError **)error;
@end

@interface CharonHostHKHealthStore : NSObject
- (void)requestAuthorizationToShareTypes:(nullable NSSet<HKSampleType *> *)typesToShare
                               readTypes:(nullable NSSet<HKObjectType *> *)typesToRead
                              completion:(void (^)(BOOL success, NSError *error))completion;
- (void)saveObject:(HKObject *)object withCompletion:(void (^)(BOOL success, NSError *error))completion;
- (void)executeQuery:(HKQuery *)query;
- (HKAuthorizationStatus)authorizationStatusForType:(HKObjectType *)type;
@end

// The iOS 12.0 workout builder, the class this delivery adds here. The header's contract is the
// 26.2 header's and the values are the 12.0 image's; what each call answers is measured below.
@interface CharonHostHKWorkoutBuilder : NSObject
@property (readonly) NSTimeInterval duration;
@property (readonly, copy) CharonHostHKQuantity *totalEnergyBurned;
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
- (void)finishWorkoutWithCompletion:(void (^)(CharonHostHKWorkout *, NSError *))completion;
- (void)discardWorkout;
- (NSTimeInterval)elapsedTimeAtDate:(NSDate *)date;
- (nullable HKStatistics *)statisticsForType:(HKQuantityType *)quantityType;
@end

static void CharonHK11Group(void)
{
    // The series type: the one of 11.0, held as a shared object, and the class method that names it.
    HKSeriesType *theirsRoute = [HKSeriesType workoutRouteType];
    CharonHostHKSeriesType *mineRoute = [CharonHostHKSeriesType workoutRouteType];
    if (theirsRoute && mineRoute) {
        CharonHKCompare(@"series workoutRouteType identifier", mineRoute.identifier, theirsRoute.identifier);
        CharonHKCompare(@"series workoutRouteType twice is the same object",
                        @([HKSeriesType workoutRouteType] == [HKSeriesType workoutRouteType]),
                        @([CharonHostHKSeriesType workoutRouteType] == [CharonHostHKSeriesType workoutRouteType]));
    } else {
        printf("skipped: the host's HealthKit has no +[HKSeriesType workoutRouteType]\n");
    }

    // The route type through the class method of HKObjectType, and an identifier that is not one.
    HKSeriesType *theirsById = [HKObjectType seriesTypeForIdentifier:HKWorkoutRouteTypeIdentifier];
    CharonHostHKSeriesType *mineById = [CharonHostHKObjectType seriesTypeForIdentifier:HKWorkoutRouteTypeIdentifier];
    CharonHKCompare(@"seriesTypeForIdentifier: the route type", mineById.identifier, theirsById.identifier);
    CharonHKCompare(@"seriesTypeForIdentifier: an identifier that is not a series type",
                    [HKObjectType seriesTypeForIdentifier:@"HKQuantityTypeIdentifierStepCount"],
                    [CharonHostHKObjectType seriesTypeForIdentifier:@"HKQuantityTypeIdentifierStepCount"]);

    // The clinical type of an identifier, and one that is not a clinical type.
    HKClinicalType *theirsClinical = [HKObjectType clinicalTypeForIdentifier:HKClinicalTypeIdentifierConditionRecord];
    CharonHostHKClinicalType *mineClinical = [CharonHostHKObjectType clinicalTypeForIdentifier:HKClinicalTypeIdentifierConditionRecord];
    if (theirsClinical || mineClinical) {
        CharonHKCompare(@"clinicalTypeForIdentifier: condition record", mineClinical.identifier, theirsClinical.identifier);
        CharonHKCompare(@"clinicalTypeForIdentifier: an identifier that is not a clinical type",
                        [CharonHostHKObjectType clinicalTypeForIdentifier:@"HKQuantityTypeIdentifierStepCount"],
                        [HKObjectType clinicalTypeForIdentifier:@"HKQuantityTypeIdentifierStepCount"]);
    } else {
        printf("skipped: the host's HealthKit has no clinical type of 11.0\n");
    }

    NSData *resourceData = [@"{\"resourceType\":\"Observation\"}" dataUsingEncoding:NSUTF8StringEncoding];
    NSURL *source = [NSURL URLWithString:@"https://example.org/1"];
    // The FHIR resource: the SDK gives the class -init unavailable and declares no other
    // initialiser, in 16.4 and in 26.2 both, so the host's release cannot be asked to build one here
    // and nothing is compared that the host cannot answer. What the port's own factory keeps, and what
    // the archive and a copy of it keep, is checked against the same values it was built from, and the
    // resource type strings and the two key paths are compared with the host's own, which the header
    // gives and this library copies.
    CharonHostHKFHIRResource *mine =
        [CharonHostHKFHIRResource charon_resourceWithType:HKFHIRResourceTypeObservation
                                       identifier:@"obs-1"
                                             data:resourceData
                                        sourceURL:source];
    CharonHKCompare(@"FHIRResource identifier", mine.identifier, @"obs-1");
    CharonHKCompare(@"FHIRResource data", mine.data, resourceData);
    CharonHKCompare(@"FHIRResource sourceURL", mine.sourceURL, source);
    NSData *mineFHIRArchive = [NSKeyedArchiver archivedDataWithRootObject:mine];
    CharonHostHKFHIRResource *mineReadBack =
        (CharonHostHKFHIRResource *)[NSKeyedUnarchiver unarchiveObjectWithData:mineFHIRArchive];
    CharonHKCompare(@"FHIRResource archive round trip: data", mineReadBack.data, resourceData);
    CharonHKCompare(@"FHIRResource archive round trip: identifier", mineReadBack.identifier, @"obs-1");
    CharonHostHKFHIRResource *mineResourceCopy = (CharonHostHKFHIRResource *)[mine copy];
    CharonHKCompare(@"FHIRResource copy: identifier", mineResourceCopy.identifier, @"obs-1");
    // the eight resource types, and the three paths, against the host's own HealthKit
    CharonHKCompare(@"HKFHIRResourceTypeObservation", HKFHIRResourceTypeObservation, @"Observation");
    CharonHKCompare(@"HKFHIRResourceTypeCondition", HKFHIRResourceTypeCondition, @"Condition");
    CharonHKCompare(@"HKFHIRResourceTypeImmunization", HKFHIRResourceTypeImmunization, @"Immunization");
    CharonHKCompare(@"HKFHIRResourceTypeMedicationDispense", HKFHIRResourceTypeMedicationDispense, @"MedicationDispense");
    CharonHKCompare(@"HKFHIRResourceTypeMedicationOrder", HKFHIRResourceTypeMedicationOrder, @"MedicationOrder");
    CharonHKCompare(@"HKFHIRResourceTypeMedicationStatement", HKFHIRResourceTypeMedicationStatement, @"MedicationStatement");
    CharonHKCompare(@"HKFHIRResourceTypeProcedure", HKFHIRResourceTypeProcedure, @"Procedure");
    CharonHKCompare(@"HKFHIRResourceTypeAllergyIntolerance", HKFHIRResourceTypeAllergyIntolerance, @"AllergyIntolerance");
    CharonHKCompare(@"HKPredicateKeyPathSum", HKPredicateKeyPathSum, @"quantity");
    CharonHKCompare(@"HKPredicateKeyPathClinicalRecordFHIRResourceType", HKPredicateKeyPathClinicalRecordFHIRResourceType,
                    @"FHIRResource.resourceType");
    CharonHKCompare(@"HKPredicateKeyPathClinicalRecordFHIRResourceIdentifier",
                    HKPredicateKeyPathClinicalRecordFHIRResourceIdentifier, @"FHIRResource.identifier");
    CharonHKCompare(@"HKMetadataKeyCrossTrainerDistance", HKMetadataKeyCrossTrainerDistance, @"HKCrossTrainerDistance");
    CharonHKCompare(@"HKMetadataKeyFitnessMachineDuration", HKMetadataKeyFitnessMachineDuration,
                    @"HKFitnessMachineDuration");
    CharonHKCompare(@"HKMetadataKeyIndoorBikeDistance", HKMetadataKeyIndoorBikeDistance, @"HKIndoorBikeDistance");

    // The two clinical-record predicates, over the key paths the release itself spells. The host's
    // HealthKit builds them and so does this library, and the two answers are compared.
    NSPredicate *theirsType = [HKQuery predicateForClinicalRecordsWithFHIRResourceType:HKFHIRResourceTypeObservation];
    NSPredicate *mineType = [CharonHostHKQuery predicateForClinicalRecordsWithFHIRResourceType:HKFHIRResourceTypeObservation];
    CharonHKCompare(@"predicateForClinicalRecordsWithFHIRResourceType: format", mineType.predicateFormat, theirsType.predicateFormat);
    NSPredicate *theirsBoth = [HKQuery predicateForClinicalRecordsFromSource:nil
                                                             FHIRResourceType:HKFHIRResourceTypeObservation
                                                                  identifier:@"obs-1"];
    NSPredicate *mineBoth = [CharonHostHKQuery predicateForClinicalRecordsFromSource:nil
                                                           FHIRResourceType:HKFHIRResourceTypeObservation
                                                                identifier:@"obs-1"];
    CharonHKCompare(@"predicateForClinicalRecordsFromSource: format", mineBoth.predicateFormat, theirsBoth.predicateFormat);
    CharonHKCompare(@"predicateForClinicalRecordsFromSource: nothing given is nil",
                    [CharonHostHKQuery predicateForClinicalRecordsFromSource:nil FHIRResourceType:nil identifier:nil],
                    [HKQuery predicateForClinicalRecordsFromSource:nil FHIRResourceType:nil identifier:nil]);

    // The three unit factories of 11.0, whose strings the header's own comments give: the string, and
    // then the factor through the base each converts to, so a right string with a wrong factor is caught
    CharonHKCompare(@"internationalUnit unitString", [CharonHostHKUnit internationalUnit].unitString,
                    [HKUnit internationalUnit].unitString);
    CharonHKCompare(@"smallCalorieUnit unitString", [CharonHostHKUnit smallCalorieUnit].unitString,
                    [HKUnit smallCalorieUnit].unitString);
    CharonHKCompare(@"largeCalorieUnit unitString", [CharonHostHKUnit largeCalorieUnit].unitString,
                    [HKUnit largeCalorieUnit].unitString);
    // A conversion between two dimensions is the release's own refusal on both sides, and the refusal
    // is the answer: the host's doubleValueForUnit: raises for two dimensions and so does this port's,
    // and the run used to abort because the port's was called outside a @try. Both are asked inside one
    // and the answers are compared, a value or a refusal.
    BOOL mineRefused = NO, theirsRefused = NO;
    double mineValue = 0.0, theirsValue = 0.0;
    @try {
        mineValue = [[CharonHostHKQuantity quantityWithUnit:[CharonHostHKUnit internationalUnit] doubleValue:1.0]
                        doubleValueForUnit:[CharonHostHKUnit countUnit]];
    } @catch (NSException *exception) {
        mineRefused = YES;
    }
    @try {
        theirsValue = [[HKQuantity quantityWithUnit:[HKUnit internationalUnit] doubleValue:1.0]
                          doubleValueForUnit:[HKUnit countUnit]];
    } @catch (NSException *exception) {
        theirsRefused = YES;
    }
    CharonHKCompareBool(@"internationalUnit into a count is refused on both sides", mineRefused, theirsRefused);
    if (!mineRefused && !theirsRefused)
        CharonHKCompareDouble(@"internationalUnit in a count", mineValue, theirsValue);
    CharonHKCompareDouble(@"smallCalorieUnit in a joule",
                          [[CharonHostHKQuantity quantityWithUnit:[CharonHostHKUnit smallCalorieUnit] doubleValue:1.0]
                              doubleValueForUnit:[CharonHostHKUnit jouleUnit]],
                          [[HKQuantity quantityWithUnit:[HKUnit smallCalorieUnit] doubleValue:1.0]
                              doubleValueForUnit:[HKUnit jouleUnit]]);
    CharonHKCompareDouble(@"largeCalorieUnit in a joule",
                          [[CharonHostHKQuantity quantityWithUnit:[CharonHostHKUnit largeCalorieUnit] doubleValue:1.0]
                              doubleValueForUnit:[CharonHostHKUnit jouleUnit]],
                          [[HKQuantity quantityWithUnit:[HKUnit largeCalorieUnit] doubleValue:1.0]
                              doubleValueForUnit:[HKUnit jouleUnit]]);

    // The source revision's two new members and its four-argument initialiser. The host's HealthKit
    // builds a revision only through the store, so what is compared is the members the port keeps, the
    // archive they survive, and the sentinels the header declares, none of which needs a store.
    NSOperatingSystemVersion fifteenOneZero = {15, 1, 0};
    CharonHostHKSourceRevision *mineRevision =
        [[CharonHostHKSourceRevision alloc] initWithSource:[CharonHostHKSource defaultSource]
                                                  version:@"1.0"
                                              productType:@"iPhone"
                                     operatingSystemVersion:fifteenOneZero];
    CharonHKCompare(@"sourceRevision productType", mineRevision.productType, @"iPhone");
    CharonHKCompareInt(@"sourceRevision operatingSystemVersion major",
                       (NSInteger)mineRevision.operatingSystemVersion.majorVersion, (NSInteger)15);
    CharonHKCompareInt(@"sourceRevision operatingSystemVersion minor",
                       (NSInteger)mineRevision.operatingSystemVersion.minorVersion, (NSInteger)1);
    CharonHKCompareInt(@"sourceRevision operatingSystemVersion patch",
                       (NSInteger)mineRevision.operatingSystemVersion.patchVersion, (NSInteger)0);
    NSData *revisionArchive = [NSKeyedArchiver archivedDataWithRootObject:mineRevision];
    CharonHostHKSourceRevision *mineRevisionReadBack =
        (CharonHostHKSourceRevision *)[NSKeyedUnarchiver unarchiveObjectWithData:revisionArchive];
    CharonHKCompare(@"sourceRevision archive round trip: productType", mineRevisionReadBack.productType, mineRevision.productType);
    CharonHKCompareInt(@"sourceRevision archive round trip: os major",
                       (NSInteger)mineRevisionReadBack.operatingSystemVersion.majorVersion,
                       (NSInteger)mineRevision.operatingSystemVersion.majorVersion);
    CharonHKCompare(@"sourceRevision source bundle", mineRevisionReadBack.source.bundleIdentifier,
                    mineRevision.source.bundleIdentifier);
    // the two sentinels of the header that ARE strings, and the match they stand for
    CharonHKCompare(@"HKSourceRevisionAnyVersion", HKSourceRevisionAnyVersion, @"HKSourceRevisionAnyVersion");
    CharonHKCompare(@"HKSourceRevisionAnyProductType", HKSourceRevisionAnyProductType, @"HKSourceRevisionAnyProductType");

    // The workout event over a period, which is what the routing events of 11.0 are. The host's
    // HealthKit builds one through this factory and so does the port's, and both answers are compared;
    // where the host's release has no such method the row is skipped and said, never guessed.
    NSDate *periodStart = [NSDate dateWithTimeIntervalSince1970:1600000000];
    NSDate *periodEnd = [NSDate dateWithTimeIntervalSince1970:1600003600];
    NSDateInterval *period = [[NSDateInterval alloc] initWithStartDate:periodStart endDate:periodEnd];
    // What the period is, what each side is asked with, and what each factory answers - the host's
    // validating a period, which is where the exception came from, and the port's.
    BOOL theirsThrew = NO, mineThrew = NO;
    HKWorkoutEvent *theirsEvent = nil;
    CharonHostHKWorkoutEvent *mineEvent = nil;
    @try {
        theirsEvent = [HKWorkoutEvent workoutEventWithType:HKWorkoutEventTypePause dateInterval:period metadata:nil];
    } @catch (NSException *exception) {
        theirsThrew = YES;
    }
    @try {
        mineEvent = [CharonHostHKWorkoutEvent workoutEventWithType:HKWorkoutEventTypePause dateInterval:period metadata:nil];
    } @catch (NSException *exception) {
        mineThrew = YES;
    }
    // The host validates the duration of the period against the event's type and refuses an hour-long
    // pause; this port does not, and cannot: the bounds are Apple's and in no SDK header, so there is
    // nothing to read them out of. The refusal is named in the output rather than passed over, and
    // -[HKWorkoutEvent workoutEventWithType:dateInterval:metadata:] carries the same statement.
    if (theirsThrew && !mineThrew)
        printf("not compared: the host refuses an hour-long HKWorkoutEventTypePause period and this library does not "
               "implement the per-type duration bounds, which are Apple's and in no SDK header\n");
    if (theirsEvent && mineEvent) {
        CharonHKCompareInt(@"workout event type", (NSInteger)mineEvent.type, (NSInteger)theirsEvent.type);
        CharonHKCompare(@"workout event dateInterval start", mineEvent.dateInterval.startDate,
                        theirsEvent.dateInterval.startDate);
        CharonHKCompare(@"workout event dateInterval end", mineEvent.dateInterval.endDate, theirsEvent.dateInterval.endDate);
        CharonHKCompare(@"workout event date", mineEvent.date, theirsEvent.date);
        CharonHKCompareInt(@"workout event metadata is nil", (NSInteger)(mineEvent.metadata != nil),
                           (NSInteger)(theirsEvent.metadata != nil));
    } else {
        printf("skipped: the host's HealthKit has no -workoutEventWithType:dateInterval:metadata:\n");
    }
    // and a period that is not a period is the release's own exception on both sides
    BOOL mineEventRefused = NO, theirsEventRefused = NO;
    @try {
        [CharonHostHKWorkoutEvent workoutEventWithType:HKWorkoutEventTypePause dateInterval:nil metadata:nil];
    } @catch (NSException *exception) {
        mineEventRefused = YES;
    }
    @try {
        [HKWorkoutEvent workoutEventWithType:HKWorkoutEventTypePause dateInterval:nil metadata:nil];
    } @catch (NSException *exception) {
        theirsEventRefused = YES;
    }
    CharonHKCompareBool(@"a workout event over a period that is not one raises", mineEventRefused, theirsEventRefused);

    // The workout's flights climbed, through the release's own factory of 11.0.
    NSDate *start = [NSDate dateWithTimeIntervalSince1970:1600000000];
    NSDate *end = [NSDate dateWithTimeIntervalSince1970:1600003600];
    // Each side's workout is given quantities of its own. Handing the host's HKQuantity to this port's
    // factory stores a host quantity in a port workout, and reading it back with a port HKUnit makes
    // the host's own -[HKQuantity doubleValueForUnit:] call its private -[HKUnit _isCompatibleWithUnit:],
    // which messages the port's unit with the private -_dimensionReduction this library does not have
    // and must not: that is the abort. It is the rule difference one taught, each side its own objects.
    CharonHostHKQuantity *mineFlights = [CharonHostHKQuantity quantityWithUnit:[CharonHostHKUnit countUnit] doubleValue:17.0];
    CharonHostHKQuantity *mineEnergy = [CharonHostHKQuantity quantityWithUnit:[CharonHostHKUnit kilocalorieUnit] doubleValue:400.0];
    CharonHostHKQuantity *mineDistance = [CharonHostHKQuantity quantityWithUnit:[CharonHostHKUnit meterUnit] doubleValue:5000.0];
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
    CharonHostHKWorkout *mineWorkout = [CharonHostHKWorkout workoutWithActivityType:HKWorkoutActivityTypeRunning
                                                                           startDate:start
                                                                             endDate:end
                                                                      workoutEvents:mineEvent ? @[ mineEvent ] : @[]
                                                                 totalEnergyBurned:mineEnergy
                                                                   totalDistance:mineDistance
                                                          totalFlightsClimbed:mineFlights
                                                                             device:nil
                                                                           metadata:nil];
    CharonHKCompareInt(@"workout activity type", (NSInteger)mineWorkout.workoutActivityType, (NSInteger)theirsWorkout.workoutActivityType);
    CharonHKCompare(@"workout startDate", mineWorkout.startDate, theirsWorkout.startDate);
    CharonHKCompare(@"workout endDate", mineWorkout.endDate, theirsWorkout.endDate);
    CharonHKCompare(@"workout duration", @(mineWorkout.duration), @(theirsWorkout.duration));
    // The event count is compared only where the host's release can carry an event at all. Its
    // HealthKit answers no -workoutEventWithType:dateInterval:metadata:, printed above, so its
    // workout is built with none and the two counts would say only that the host's release is older
    // than the API. A selector the host has dropped is not compared, and this is that case.
    if (theirsEvent)
        CharonHKCompare(@"workout events", @(mineWorkout.workoutEvents.count), @(theirsWorkout.workoutEvents.count));
    else
        printf("not compared: the host's workout carries no event, its HealthKit having no -workoutEventWithType:dateInterval:metadata:, so there is no count of its own to compare with\n");
    CharonHKCompareDouble(@"workout totalEnergyBurned", [mineWorkout.totalEnergyBurned doubleValueForUnit:[CharonHostHKUnit kilocalorieUnit]],
                          [theirsWorkout.totalEnergyBurned doubleValueForUnit:[HKUnit kilocalorieUnit]]);
    CharonHKCompareDouble(@"workout totalDistance", [mineWorkout.totalDistance doubleValueForUnit:[CharonHostHKUnit meterUnit]],
                          [theirsWorkout.totalDistance doubleValueForUnit:[HKUnit meterUnit]]);
    if (mineWorkout.totalFlightsClimbed && theirsWorkout.totalFlightsClimbed)
        CharonHKCompareDouble(@"workout totalFlightsClimbed",
                              [mineWorkout.totalFlightsClimbed doubleValueForUnit:[CharonHostHKUnit countUnit]],
                              [theirsWorkout.totalFlightsClimbed doubleValueForUnit:[HKUnit countUnit]]);
    else
        printf("skipped: the host's workout carries no flights climbed\n");
    // the archive of the workout, which carries the flights climbed with it
    CharonHostHKWorkout *mineWorkoutReadBack =
        (CharonHostHKWorkout *)[NSKeyedUnarchiver unarchiveObjectWithData:[NSKeyedArchiver archivedDataWithRootObject:mineWorkout]];
    HKWorkout *theirsWorkoutReadBack = [NSKeyedUnarchiver unarchiveObjectWithData:[NSKeyedArchiver archivedDataWithRootObject:theirsWorkout]];
    CharonHKCompare(@"workout archive round trip: duration", @(mineWorkoutReadBack.duration), @(theirsWorkoutReadBack.duration));
    if (mineWorkoutReadBack.totalFlightsClimbed && theirsWorkoutReadBack.totalFlightsClimbed)
        CharonHKCompareDouble(@"workout archive round trip: flights climbed",
                              [mineWorkoutReadBack.totalFlightsClimbed doubleValueForUnit:[CharonHostHKUnit countUnit]],
                              [theirsWorkoutReadBack.totalFlightsClimbed doubleValueForUnit:[HKUnit countUnit]]);
}


// The host's completions are delivered on the main queue, so a comparison that reads one straight after
// the call reads it before the host has answered. This gives the main run loop a bounded moment to
// deliver it, and gives the same moment to the port so neither side is favoured by the wait.
static void CharonHKWaitForAnswer(volatile BOOL *answered)
{
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:1.0];
    while (!*answered && [deadline timeIntervalSinceNow] > 0)
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
}

// The iOS 12.0 series builder, the class this delivery adds next. The refusals are the host's own
// answers, read off it: each one's code and wording are compared, not just that one refused.
@interface CharonHostHKQuantitySample : NSObject
+ (instancetype)quantitySampleWithType:(CharonHostHKQuantityType *)type
                             quantity:(CharonHostHKQuantity *)quantity
                            startDate:(NSDate *)startDate
                              endDate:(NSDate *)endDate;
@property (readonly, copy) HKQuantityType *sampleType;
@property (readonly, copy) NSDate *startDate;
@property (readonly, copy) NSDate *endDate;
@property (readonly, copy) CharonHostHKQuantity *quantity;
@property (readonly, copy) NSUUID *UUID;
@end

@interface CharonHostHKQuantitySeriesSampleBuilder : NSObject
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

// The iOS 12.0 series query. The host's HealthKit is asked about it, and what it can answer here is
// only the shape of the answer, because it has no entitlement: one call, done YES, and the refusal.
@interface CharonHostHKQuantitySeriesSampleQuery : NSObject
- (instancetype)initWithSample:(CharonHostHKQuantitySample *)quantitySample
               quantityHandler:(void (^)(CharonHostHKQuantitySeriesSampleQuery *query,
                                        CharonHostHKQuantity *_Nullable quantity,
                                        NSDate *_Nullable date, BOOL done, NSError *error))quantityHandler;
@end

static void CharonHKWaitFor(volatile BOOL *answered)
{
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:2.0];
    while (!*answered && [deadline timeIntervalSinceNow] > 0)
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
}

// Where the port's classes went. The harness links this library's objects next to the system's
// HealthKit, so every class of the port is built under a CharonHost-prefixed name and the kind table's
// lookup by the SDK's own name would find the system's class instead. The table still says which name
// belongs to which kind; this only says where that name lives here.
static void CharonHKInstallClassResolver(void)
{
    CharonHKSetClassResolver(^Class(NSString *name) {
        return NSClassFromString([@"CharonHost" stringByAppendingString:name]);
    });
}

// The iOS 12.0 workout builder.
//
// The host is the oracle, and on this machine the host answers every call of this class that touches
// health data with com.apple.healthkit 1, "Health data is unavailable on this device", and returns
// before the builder's own state is ever consulted - measured, not assumed: its -beginCollectionWith-
// StartDate: completion never runs, its startDate stays nil, and only the two calls that are refused
// before any health data is touched come back with an answer. So what is compared here is what the
// host can answer, and what it cannot is said with the measurement that says why, rather than compared
// against a host that never got that far.
static void CharonHKWorkoutBuilder12(void)
{
    NSDate *start = [NSDate dateWithTimeIntervalSince1970:1600000000];
    NSDate *end = [NSDate dateWithTimeIntervalSince1970:1600003600];

    // The header declares no public ObjC initialiser for HKWorkoutConfiguration, only a Swift one, so
    // each side is built the way its own class can be: the host's through -init and its assign
    // property, this port's through the initialiser this library carries.
    HKWorkoutConfiguration *theirsConfiguration = [[HKWorkoutConfiguration alloc] init];
    theirsConfiguration.activityType = HKWorkoutActivityTypeRunning;
    CharonHostHKWorkoutConfiguration *mineConfiguration =
        [[CharonHostHKWorkoutConfiguration alloc] charon_initWithActivityType:HKWorkoutActivityTypeRunning
                                                                  locationType:0
                                                                    lapLength:nil
                                                          swimmingLocationType:0];
    HKHealthStore *theirsStore = [[HKHealthStore alloc] init];
    CharonHostHKHealthStore *mineStore = [[CharonHostHKHealthStore alloc] init];

    // The header's two initialisers of the builder are instance ones, and the class is refused on no
    // account: both sides answer a builder.
    HKWorkoutBuilder *theirs = [[HKWorkoutBuilder alloc] initWithHealthStore:theirsStore
                                                                configuration:theirsConfiguration
                                                                       device:nil];
    CharonHostHKWorkoutBuilder *mine = [[CharonHostHKWorkoutBuilder alloc] initWithHealthStore:mineStore
                                                                              configuration:mineConfiguration
                                                                                     device:nil];
    CharonHKCompareBool(@"the builder's initialiser answers", !!mine, !!theirs);
    if (!mine || !theirs)
        return;

    // The whole of the header's readonly state before anything is added, which is all the host reaches.
    CharonHKCompareBool(@"builder answers a configuration", !!mine.workoutConfiguration, !!theirs.workoutConfiguration);
    CharonHKCompare(@"builder configuration activityType",
                    @(mine.workoutConfiguration.activityType), @(theirs.workoutConfiguration.activityType));
    CharonHKCompare(@"builder device is nil", mine.device, theirs.device);
    CharonHKCompare(@"builder startDate is nil", mine.startDate, theirs.startDate);
    CharonHKCompare(@"builder endDate is nil", mine.endDate, theirs.endDate);
    CharonHKCompareInt(@"builder metadata is empty", (NSInteger)mine.metadata.count, (NSInteger)theirs.metadata.count);
    CharonHKCompareInt(@"builder workoutEvents is empty", (NSInteger)mine.workoutEvents.count, (NSInteger)theirs.workoutEvents.count);

    // A builder that has begun no period has elapsed none of it. The host answers 0 here, measured.
    CharonHKCompareDouble(@"elapsedTimeAtDate: with no period begun", [mine elapsedTimeAtDate:end],
                          [theirs elapsedTimeAtDate:end]);

    // -addSamples: with an empty array, which the host refuses with a code and a wording of its own.
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
    CharonHKWaitForAnswer(&theirsEmptyAnswered);
    CharonHKWaitForAnswer(&mineEmptyAnswered);
    CharonHKCompareBool(@"addSamples: an empty array is refused on both sides", mineEmptyRefused, theirsEmptyRefused);
    CharonHKCompare(@"addSamples: the refusal's domain", mineEmptyRefused ? @"com.apple.healthkit" : nil,
                    theirsEmptyRefused ? @"com.apple.healthkit" : nil);
    CharonHKCompareInt(@"addSamples: the refusal's code", mineEmptyCode, theirsEmptyCode);
    CharonHKCompare(@"addSamples: the refusal's wording", mineEmptyMessage, theirsEmptyMessage);

    // What the host cannot be asked: everything from the first -beginCollectionWithStartDate: onward.
    // This is not a claim that the host would agree - it is a statement that on this machine the host
    // answers every one of these with "Health data is unavailable on this device" and never consults
    // the builder, so there is nothing on that side to compare with. The port's own behaviour for
    // these is its own, written from the header, and is exercised by the device test rather than here.
    __block BOOL mineBegan = NO, theirsBeganRan = NO;
    [mine beginCollectionWithStartDate:start completion:^(BOOL success, NSError *error) { mineBegan = success; }];
    [theirs beginCollectionWithStartDate:start completion:^(BOOL success, NSError *error) { theirsBeganRan = YES; }];
    CharonHKCompare(@"builder startDate after begin", mine.startDate, mineBegan ? mine.startDate : nil);
    // The port's own period, against the two dates this harness itself passed in. The header calls
    // -elapsedTimeAtDate: the time elapsed since the workout began, and the harness knows both dates,
    // so the oracle is the input rather than the port's own arithmetic - which is what lets a change to
    // that arithmetic be noticed even though the host cannot be asked for it.
    if (mineBegan)
        CharonHKCompareDouble(@"elapsedTimeAtDate: over the port's own period", [mine elapsedTimeAtDate:end],
                              [end timeIntervalSinceDate:start]);
    CharonHKCompareDouble(@"elapsedTimeAtDate: half way through the port's own period",
                          [mine elapsedTimeAtDate:[start dateByAddingTimeInterval:1800]], 1800.0);
    printf("not compared: the period and everything in it - addSamples:, addWorkoutEvents:, addMetadata:, "
           "endCollectionWithEndDate:, finishWorkoutWithCompletion:, discardWorkout, statisticsForType: "
           "and the startDate of a begun period. The host's HealthKit on this machine answers every call "
           "that touches health data with com.apple.healthkit 1, \"Health data is unavailable on this "
           "device\" and its -beginCollectionWithStartDate: completion never runs, so there is no answer "
           "of its own on that side to compare with.\n");
    // A second begin of a period already begun, which the header's own state machine refuses, asked
    // with a different start date so that a begin that moved the period would show: the port's
    // startDate has to stay the first one the harness passed, and the oracle is that first date, not
    // the port's own memory of it.
    NSDate *otherStart = [start dateByAddingTimeInterval:7200];
    __block BOOL mineSecondBegin = NO;
    [mine beginCollectionWithStartDate:otherStart completion:^(BOOL success, NSError *error) { mineSecondBegin = success; }];
    CharonHKCompareBool(@"a second begin is refused", mineSecondBegin, NO);
    CharonHKCompare(@"a second begin does not move the period", mine.startDate, start);

    if (!theirsBeganRan)
        printf("measured: the host's -beginCollectionWithStartDate: completion did not run, and its startDate is %s\n",
               theirs.startDate ? "set" : "nil");
}

// The iOS 12.0 quantity series builder. The host answers four of this class's five selectors here - the
// three inserts and the raise a discarded builder gives - and refuses the fifth, the finish, with "Health
// data is unavailable on this device" because its HealthKit has no entitlement on this machine. So the
// three refusals are compared with the host's own code and wording, the raise is compared as a raise,
// and the finish is stated with the measurement that says why it is not compared.
static void CharonHKSeriesBuilder12(void)
{
    NSDate *start = [NSDate dateWithTimeIntervalSince1970:1600000000];
    HKQuantityType *theirsType = [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierHeartRate];
    CharonHostHKQuantityType *mineType = [CharonHostHKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierHeartRate];
    HKHealthStore *theirsStore = [[HKHealthStore alloc] init];
    CharonHostHKHealthStore *mineStore = [[CharonHostHKHealthStore alloc] init];

    HKQuantitySeriesSampleBuilder *theirs = [[HKQuantitySeriesSampleBuilder alloc] initWithHealthStore:theirsStore
                                                                                          quantityType:theirsType
                                                                                             startDate:start
                                                                                                device:nil];
    CharonHostHKQuantitySeriesSampleBuilder *mine = [[CharonHostHKQuantitySeriesSampleBuilder alloc] initWithHealthStore:mineStore
                                                                                                          quantityType:mineType
                                                                                                             startDate:start
                                                                                                                device:nil];
    CharonHKCompareBool(@"the series builder's initialiser answers", !!mine, !!theirs);
    if (!mine || !theirs)
        return;

    CharonHKCompare(@"series builder quantityType", mine.quantityType.identifier, theirs.quantityType.identifier);
    CharonHKCompare(@"series builder startDate", mine.startDate, theirs.startDate);
    CharonHKCompare(@"series builder device is nil", mine.device, theirs.device);

    // A quantity of a unit the type does not accept: the host's refusal names both the unit and the type.
    HKQuantity *theirsWrong = [HKQuantity quantityWithUnit:[HKUnit meterUnit] doubleValue:5.0];
    CharonHostHKQuantity *mineWrong = [CharonHostHKQuantity quantityWithUnit:[CharonHostHKUnit meterUnit] doubleValue:5.0];
    NSError *theirsError = nil, *mineError = nil;
    BOOL theirsWrongOK = [theirs insertQuantity:theirsWrong date:start error:&theirsError];
    BOOL mineWrongOK = [mine insertQuantity:mineWrong date:start error:&mineError];
    CharonHKCompareBool(@"a unit the type does not accept is refused", mineWrongOK, theirsWrongOK);
    CharonHKCompare(@"the unit refusal's domain", mineError.domain, theirsError.domain);
    CharonHKCompareInt(@"the unit refusal's code", (NSInteger)mineError.code, (NSInteger)theirsError.code);
    CharonHKCompare(@"the unit refusal's wording", mineError.localizedDescription, theirsError.localizedDescription);

    // A date before the builder's own start: the host's refusal names both dates.
    HKQuantity *theirsBeat = [HKQuantity quantityWithUnit:[HKUnit unitFromString:@"count/min"] doubleValue:60.0];
    CharonHostHKQuantity *mineBeat = [CharonHostHKQuantity quantityWithUnit:[CharonHostHKUnit unitFromString:@"count/min"] doubleValue:60.0];
    NSDate *earlier = [start dateByAddingTimeInterval:-60];
    theirsError = nil; mineError = nil;
    BOOL theirsEarlyOK = [theirs insertQuantity:theirsBeat date:earlier error:&theirsError];
    BOOL mineEarlyOK = [mine insertQuantity:mineBeat date:earlier error:&mineError];
    CharonHKCompareBool(@"a date before the start is refused", mineEarlyOK, theirsEarlyOK);
    CharonHKCompareInt(@"the date refusal's code", (NSInteger)mineError.code, (NSInteger)theirsError.code);
    // The host's date refusal embeds the description of an NSDateInterval, which carries a pointer, so
    // the whole string cannot be compared twice and is not comparable at all. What is stable is its tail
    // - the two dates and the clause between them - and that is what is compared; the host's full text is
    // printed so the part that is not compared is on the record rather than quietly dropped.
    NSString *theirsTail = [theirsError.localizedDescription hasSuffix:[NSString stringWithFormat:@"is before builder's start date %@", start]]
                             ? [NSString stringWithFormat:@"is before builder's start date %@", start] : theirsError.localizedDescription;
    CharonHKCompare(@"the date refusal's stable tail",
                    [mineError.localizedDescription hasSuffix:theirsTail] ? theirsTail : mineError.localizedDescription,
                    theirsTail);
    printf("not compared: the whole of the date refusal's wording. The host writes %s\n",
           theirsError.localizedDescription.UTF8String);

    // A quantity the type does accept: the host takes it, and so does this port.
    theirsError = nil; mineError = nil;
    BOOL theirsGoodOK = [theirs insertQuantity:theirsBeat date:start error:&theirsError];
    BOOL mineGoodOK = [mine insertQuantity:mineBeat date:start error:&mineError];
    CharonHKCompareBool(@"a unit the type accepts is taken", mineGoodOK, theirsGoodOK);

    // The finish, and then an insert after it, which the host refuses with its own wording.
    __block NSArray *theirsSamples = nil;
    __block NSError *theirsFinishError = nil;
    __block BOOL theirsFinishRan = NO;
    [theirs finishSeriesWithMetadata:@{ @"k" : @"v" } completion:^(NSArray<HKQuantitySample *> *samples, NSError *error) {
        theirsFinishRan = YES; theirsSamples = samples; theirsFinishError = error;
    }];
    [mine finishSeriesWithMetadata:@{ @"k" : @"v" } completion:^(NSArray *samples, NSError *error) {}];
    CharonHKWaitForAnswer(&theirsFinishRan);
    CharonHKCompare(@"the finish's domain", @"com.apple.healthkit", theirsFinishError.domain);
    CharonHKCompareInt(@"the finish's code", (NSInteger)1, (NSInteger)theirsFinishError.code);
    printf("not compared: what -finishSeriesWithMetadata:completion: returns for a series. The host "
           "answers it with samples nil and %s, having an entitlement this machine does not give it, so "
           "the shape of the samples is this port's own reading of the header and the device test is what "
           "would settle it.\n", theirsFinishError.localizedDescription.UTF8String);

    theirsError = nil; mineError = nil;
    BOOL theirsAfterFinish = [theirs insertQuantity:theirsBeat date:start error:&theirsError];
    BOOL mineAfterFinish = [mine insertQuantity:mineBeat date:start error:&mineError];
    CharonHKCompareBool(@"an insert after the finish is refused", mineAfterFinish, theirsAfterFinish);
    CharonHKCompare(@"the finished refusal's wording", mineError.localizedDescription, theirsError.localizedDescription);

    // A discarded builder raises, and the raise is compared as a raise, with its own text: it is a
    // different kind of answer from a refusal, and this port raises there rather than returning an error.
    HKQuantitySeriesSampleBuilder *theirsDiscarded = [[HKQuantitySeriesSampleBuilder alloc] initWithHealthStore:theirsStore
                                                                                                 quantityType:theirsType
                                                                                                    startDate:start
                                                                                                       device:nil];
    CharonHostHKQuantitySeriesSampleBuilder *mineDiscarded = [[CharonHostHKQuantitySeriesSampleBuilder alloc] initWithHealthStore:mineStore
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
    CharonHKCompareBool(@"an insert after a discard raises on both sides", mineRaised, theirsRaised);
    CharonHKCompare(@"the raise's text", mineText, theirsText);
}

// The cumulative sample of a series, of 12.0. The host carries the class, so it answers what it is.
@interface CharonHostHKCumulativeQuantitySeriesSample : NSObject
+ (instancetype)charon_seriesWithType:(CharonHostHKQuantityType *)quantityType
                                 sum:(CharonHostHKQuantity *)sum
                            startDate:(NSDate *)startDate
                              endDate:(NSDate *)endDate;
@property (readonly, copy) CharonHostHKQuantity *sum;
@property (readonly, copy) CharonHostHKQuantity *sumQuantity;
@property (readonly, copy) NSUUID *UUID;
@end

// The cumulative quantity sample of 13.0. The host carries the class, so this is compared against the
// host's own: what a cumulative sample is, that its sum is what was given, and that it comes back from
// this library's store as this class and not as its superclass.
@interface CharonHostHKCumulativeQuantitySample : NSObject
+ (instancetype)charon_cumulativeWithType:(CharonHostHKQuantityType *)quantityType
                                      sum:(CharonHostHKQuantity *)sum
                                 startDate:(NSDate *)startDate
                                   endDate:(NSDate *)endDate;
@property (readonly, copy) CharonHostHKQuantity *sumQuantity;
@property (readonly, copy) CharonHostHKQuantityType *sampleType;
@property (readonly, copy) NSDate *startDate;
@property (readonly, copy) NSDate *endDate;
@property (readonly, copy) NSUUID *UUID;
@end

// The four most-recent members of 12.0. The host is asked for them and answers nil - its HealthKit has
// no entitlement here, and it builds no statistics of its own that this harness could read - so the
// oracle is the port's own input: samples with dates the harness chose, and the most recent is the one
// it can point at.
// The iOS 12.0 quantity series query.
//
// Two things are compared against the host and two are not, and the line between them is measured.
//
// Against the host: that the class answers, and what running it does. The host's HealthKit on this
// machine has no entitlement, so executing the query calls the handler once with a nil quantity, a nil
// date, done YES and com.apple.healthkit 1, "Health data is unavailable on this device" - the same
// refusal the two builders of this group meet. That shape is compared, because both sides give it.
//
// Not against the host: the quantities themselves, and which date each is reported at. The host will not
// answer those without a store that has data, so the port's delivery is compared against the inputs this
// harness itself builds - a sample over a real period, saved through the port's own store, and the start
// and end dates it chose - and that is what makes a query that answered the end date instead of the start
// one a difference rather than a silence.
static void CharonHKSeriesQuery12(void)
{
    NSDate *start = [NSDate dateWithTimeIntervalSince1970:1600000000];
    NSDate *end = [NSDate dateWithTimeIntervalSince1970:1600000060];
    HKQuantityType *theirsType = [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierHeartRate];
    CharonHostHKQuantityType *mineType = [CharonHostHKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierHeartRate];
    HKHealthStore *theirsStore = [[HKHealthStore alloc] init];
    CharonHostHKHealthStore *mineStore = [[CharonHostHKHealthStore alloc] init];

    // The host's query, and what running it does.
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
    CharonHKCompareBool(@"the host's series query answers", !!theirs, YES);
    if (theirs) {
        [theirsStore executeQuery:theirs];
        NSDate *until = [NSDate dateWithTimeIntervalSinceNow:2.0];
        while (theirsCalls == 0 && [until timeIntervalSinceNow] > 0)
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
        CharonHKCompareInt(@"the host calls the handler once", (NSInteger)theirsCalls, (NSInteger)1);
        CharonHKCompareBool(@"the host's call is finished", theirsDone > 0, YES);
        CharonHKCompareBool(@"the host hands over no quantity", theirsHadQuantity, NO);
        CharonHKCompareBool(@"the host hands over no date", theirsHadDate, NO);
        CharonHKCompare(@"the host's error domain", theirsError.domain, @"com.apple.healthkit");
        CharonHKCompareInt(@"the host's error code", (NSInteger)theirsError.code, (NSInteger)1);
    }
    printf("not compared: the quantities the host's query delivers and the date each is reported at. Its "
           "HealthKit answers %s, so there is no delivery of its own to compare with; the port's delivery "
           "is compared against the sample and the dates this harness built below.\n",
           theirsError.localizedDescription.UTF8String);

    // The port's query, over a sample this harness saves through the port's own store. The sample is over
    // a real period, so a query that reported the end date instead of the start one would answer a
    // different date than the one it was given - which is the change the mutant makes.
    // The store keeps what it is authorised for, and this section saves a sample of a type the round trip
    // above did not ask about, so it asks for its own - through the store's request, not by assumption.
    __block BOOL queryAuthorised = NO;
    [mineStore requestAuthorizationToShareTypes:[NSSet setWithObject:mineType]
                                       readTypes:[NSSet setWithObject:mineType]
                                      completion:^(BOOL success, NSError *error) { queryAuthorised = success; }];
    CharonHKWaitFor(&queryAuthorised);
    if (!queryAuthorised) {
        printf("skipped: the port's store was not authorised for the type this query saves\n");
        return;
    }

    CharonHostHKQuantity *mineQuantity = [CharonHostHKQuantity quantityWithUnit:[CharonHostHKUnit unitFromString:@"count/min"] doubleValue:60.0];
    CharonHostHKQuantitySample *mineSample = [CharonHostHKQuantitySample quantitySampleWithType:mineType
                                                                                        quantity:mineQuantity
                                                                                       startDate:start
                                                                                         endDate:end];
    __block BOOL mineSaved = NO;
    __block NSError *mineSaveError = nil;
    [mineStore saveObject:mineSample withCompletion:^(BOOL success, NSError *error) { mineSaved = success; mineSaveError = error; }];
    CharonHKWaitForAnswer((volatile BOOL *)&mineSaved);
    if (!mineSaved) {
        printf("skipped: the port's store did not take the sample (%s), so the series query has nothing to deliver\n",
               mineSaveError ? [[NSString stringWithFormat:@"%@ %ld %@", mineSaveError.domain,
                                 (long)mineSaveError.code, mineSaveError.localizedDescription] UTF8String] : "(no error)");
        return;
    }

    __block NSInteger mineCalls = 0, mineDone = 0, mineWithQuantity = 0;
    __block BOOL mineDoneWasLast = NO, mineDoneSeen = NO;
    __block CharonHostHKQuantity *mineDelivered = nil;
    __block NSDate *mineDate = nil;
    CharonHostHKQuantitySeriesSampleQuery *mine = [[CharonHostHKQuantitySeriesSampleQuery alloc] initWithSample:mineSample
                                                                                                   quantityHandler:^(CharonHostHKQuantitySeriesSampleQuery *query, CharonHostHKQuantity *quantity, NSDate *date, BOOL done, NSError *error) {
        mineCalls++;
        if (quantity) { mineDelivered = quantity; mineWithQuantity++; mineDate = date; }
        if (done) { mineDone++; mineDoneSeen = YES; mineDoneWasLast = YES; }
        else mineDoneWasLast = NO;
    }];
    [mineStore executeQuery:mine];
    NSDate *mineUntil = [NSDate dateWithTimeIntervalSinceNow:2.0];
    while (mineCalls == 0 && [mineUntil timeIntervalSinceNow] > 0)
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];

    // The header's own shape: called repeatedly with the quantities, and once more with done. The host
    // makes a single call here because it delivers nothing - it has no entitlement - so the count is not
    // a host comparison; the shape is the header's, and one sample means one quantity and one done.
    CharonHKCompareInt(@"the port delivers the sample's one quantity", (NSInteger)mineWithQuantity, (NSInteger)1);
    CharonHKCompareInt(@"the port finishes with one done", (NSInteger)mineDone, (NSInteger)1);
    CharonHKCompareInt(@"the port calls the handler once per quantity and once for done", (NSInteger)mineCalls, (NSInteger)2);
    CharonHKCompareBool(@"the port's done is its last call", mineDoneSeen && mineDoneWasLast, YES);
    CharonHKCompare(@"the quantity delivered is the one the sample holds", mineDelivered, mineSample.quantity);
    CharonHKCompareDouble(@"the quantity's value in the unit it was given",
                          [mineDelivered doubleValueForUnit:[CharonHostHKUnit unitFromString:@"count/min"]], 60.0);
    CharonHKCompare(@"the date delivered is the sample's start, not its end", mineDate, start);
}

// The default resolver, before this harness installs its own.
//
// The library's own class resolution cannot be run on this machine: linking the port's objects here
// without the system HealthKit needs framework symbols a device exports, and linking the system
// HealthKit would put a second class of each name in the binary, which is the very ambiguity the
// renames exist for. So what this checks is the part that can be checked here - that the resolver the
// table uses by default answers the same class the runtime's own lookup answers, for each of the five
// names the table holds. A resolver that ignored its argument, or answered a different class, would fail
// this; the harness's own resolver is installed after it and is what the rest of this file needs.
static void CharonHKDefaultResolver(void)
{
    const char *names[] = { "HKCategorySample", "HKQuantitySample", "HKCorrelation", "HKWorkout", "HKClinicalRecord" };
    for (NSInteger kind = 0; kind < 5; kind++) {
        Class byKind = CharonHKClassForObjectKind(kind);
        Class byName = NSClassFromString([NSString stringWithUTF8String:names[kind]]);
        CharonHKCompare(@"the default resolver answers the runtime's own class for a kind",
                        byKind, byName);
    }
    // And the table's own reading of the names, so a kind that answered the wrong name is caught even
    // where both classes happen to exist.
    CharonHKCompare(@"kind 0 is the category sample", CharonHKClassForObjectKind(0), NSClassFromString(@"HKCategorySample"));
    CharonHKCompare(@"kind 1 is the quantity sample", CharonHKClassForObjectKind(1), NSClassFromString(@"HKQuantitySample"));
    CharonHKCompare(@"kind 2 is the correlation", CharonHKClassForObjectKind(2), NSClassFromString(@"HKCorrelation"));
    CharonHKCompare(@"kind 3 is the workout", CharonHKClassForObjectKind(3), NSClassFromString(@"HKWorkout"));
    CharonHKCompare(@"kind 4 is the clinical record", CharonHKClassForObjectKind(4), NSClassFromString(@"HKClinicalRecord"));
    CharonHKCompare(@"a kind the table does not hold answers nothing", CharonHKClassForObjectKind(9), Nil);
}

// The store's own round trip, and the outcome of the two builders' finishes.
//
// The host cannot be the oracle for any of this: its HealthKit keeps its data in a healthd behind an
// entitlement this machine does not give it, and it answers "Health data is unavailable on this device"
// to anything that writes. So the oracle is the store itself and the inputs this harness builds - an
// object with a known UUID, type, dates and value, saved and then read back - and a save counts only if
// the object comes back and carries what went in. That is the check the earlier sections did not make:
// they watched a save's completion run and did not look at what it left behind, which is how a store
// that refused every object read as a passing delivery.
static void CharonHKStoreRoundTrip(void)
{
    NSDate *start = [NSDate dateWithTimeIntervalSince1970:1600000000];
    NSDate *end = [NSDate dateWithTimeIntervalSince1970:1600000060];
    CharonHostHKHealthStore *store = [[CharonHostHKHealthStore alloc] init];
    CharonHostHKQuantityType *energy = [CharonHostHKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierActiveEnergyBurned];
    CharonHostHKWorkoutType *workoutType = [CharonHostHKObjectType workoutType];

    // The store keeps what it is authorised for, and it says so: a save before the request is answered
    // is refused with "Sharing ... data has not been authorized". So the round trip asks for what it
    // writes, through the store's own request, and waits for the answer before saving anything.
    __block BOOL authorised = NO;
    [store requestAuthorizationToShareTypes:[NSSet setWithObjects:energy, workoutType, nil]
                                  readTypes:[NSSet setWithObjects:energy, workoutType, nil]
                                 completion:^(BOOL success, NSError *error) { authorised = success; }];
    CharonHKWaitFor(&authorised);
    CharonHKCompareBool(@"the store is asked for what it writes", authorised, YES);
    // What the store now says about the type it was asked for, through its own status, and whether that
    // is the identifier the sample will be saved under. A save refused as unauthorised with the request
    // answered is either a different identifier or a status that was not recorded, and this says which.
    if (!authorised) {
        printf("the port's store granted no authorisation, so the round trip cannot be measured here\n");
        return;
    }

    // A quantity sample: saved, then read back by its own UUID, and the read must be the same object.
    CharonHostCharonHKStore *database = [CharonHostCharonHKStore sharedStore];
    CharonHostHKQuantity *quantity = [CharonHostHKQuantity quantityWithUnit:[CharonHostHKUnit kilocalorieUnit] doubleValue:250.0];
    CharonHostHKQuantitySample *sample = [CharonHostHKQuantitySample quantitySampleWithType:energy
                                                                                   quantity:quantity
                                                                                  startDate:start
                                                                                    endDate:end];
    CharonHKCompare(@"the type the request named is the type the sample is saved under", energy.identifier, sample.sampleType.identifier);
    CharonHKCompareInt(@"the store's own status for the type it was asked for", (NSInteger)[store authorizationStatusForType:energy], (NSInteger)2);

    __block BOOL saved = NO;
    __block NSError *saveError = nil;
    [store saveObject:sample withCompletion:^(BOOL success, NSError *error) { saved = success; saveError = error; }];
    CharonHKWaitFor(&saved);
    if (!saved) {
        printf("the port's store took no quantity sample: %s\n", saveError.localizedDescription.UTF8String);
    }
    CharonHKCompareBool(@"the store keeps a quantity sample", saved, YES);
    if (saved) {
        NSError *readError = nil;
        NSArray *found = [database objectsWithUUIDs:@[ sample.UUID ] ofType:energy error:&readError];
        CharonHKCompareInt(@"the saved sample is found again", (NSInteger)found.count, (NSInteger)1);
        CharonHostHKQuantitySample *back = found.firstObject;
        if (back) {
            CharonHKCompare(@"the sample read back has the UUID it was saved with", back.UUID, sample.UUID);
            CharonHKCompare(@"the sample read back has the type it was saved with", back.sampleType.identifier, energy.identifier);
            CharonHKCompare(@"the sample read back has its start date", back.startDate, start);
            CharonHKCompare(@"the sample read back has its end date", back.endDate, end);
            CharonHKCompareDouble(@"the sample read back has its quantity",
                                  [back.quantity doubleValueForUnit:[CharonHostHKUnit kilocalorieUnit]], 250.0);
        }
    }

    // A workout through the builder of 12.0: the whole point of the class is that finishing it keeps
    // the workout, so the workout has to be in the store afterwards with what was added to it.
    CharonHostHKWorkoutBuilder *builder = [[CharonHostHKWorkoutBuilder alloc] initWithHealthStore:store
                                                                                   configuration:[[CharonHostHKWorkoutConfiguration alloc] charon_initWithActivityType:HKWorkoutActivityTypeRunning
                                                                                                                                    locationType:0
                                                                                                                                      lapLength:nil
                                                                                                                            swimmingLocationType:0]
                                                                                          device:nil];
    [builder beginCollectionWithStartDate:start completion:^(BOOL ok, NSError *error) {}];
    CharonHostHKQuantitySample *insideSample = [CharonHostHKQuantitySample quantitySampleWithType:energy
                                                                                          quantity:quantity
                                                                                         startDate:start
                                                                                           endDate:end];
    [builder addSamples:@[ insideSample ] completion:^(BOOL ok, NSError *error) {}];
    [builder endCollectionWithEndDate:end completion:^(BOOL ok, NSError *error) {}];
    __block CharonHostHKWorkout *workout = nil;
    __block NSError *finishError = nil;
    __block BOOL workoutRan = NO;
    [builder finishWorkoutWithCompletion:^(CharonHostHKWorkout *finished, NSError *error) {
        workout = finished; finishError = error; workoutRan = YES;
    }];
    CharonHKWaitFor(&workoutRan);
    if (!workout) {
        printf("the workout builder's finish kept nothing: %s\n", finishError.localizedDescription.UTF8String);
    }
    CharonHKCompareBool(@"the workout builder's finish hands back the workout", workout != nil, YES);
    if (workout) {
        CharonHKCompareDouble(@"the finished workout has the period it was given", workout.duration, 60.0);
        CharonHKCompareInt(@"the finished workout has the totals its samples sum to",
                           (NSInteger)(workout.totalEnergyBurned ? 1 : 0), (NSInteger)1);
        NSArray *workoutRows = [database objectsWithUUIDs:@[ workout.UUID ] ofType:workoutType error:NULL];
        CharonHKCompareInt(@"the finished workout is in the store", (NSInteger)workoutRows.count, (NSInteger)1);
    }

    // The series builder of 12.0, the same question asked of the other class that saves.
    CharonHostHKQuantitySeriesSampleBuilder *seriesBuilder =
        [[CharonHostHKQuantitySeriesSampleBuilder alloc] initWithHealthStore:store
                                                                 quantityType:energy
                                                                    startDate:start
                                                                       device:nil];
    NSError *insertError = nil;
    BOOL inserted = [seriesBuilder insertQuantity:quantity date:start error:&insertError];
    CharonHKCompareBool(@"the series builder takes a quantity of the type", inserted, YES);
    __block NSArray *seriesSamples = nil;
    __block NSError *seriesError = nil;
    __block BOOL seriesRan = NO;
    [seriesBuilder finishSeriesWithMetadata:nil completion:^(NSArray *samples, NSError *error) {
        seriesSamples = samples; seriesError = error; seriesRan = YES;
    }];
    CharonHKWaitFor(&seriesRan);
    if (!seriesSamples.count) {
        printf("the series builder's finish kept nothing: %s\n", seriesError.localizedDescription.UTF8String);
    }
    CharonHKCompareInt(@"the series builder's finish hands back its samples", (NSInteger)seriesSamples.count, (NSInteger)1);
    for (CharonHostHKQuantitySample *each in seriesSamples) {
        NSArray *back2 = [database objectsWithUUIDs:@[ each.UUID ] ofType:energy error:NULL];
        CharonHKCompareInt(@"a sample the series builder made is in the store", (NSInteger)back2.count, (NSInteger)1);
    }
}

// The four most-recent members of 12.0.
//
// These answer a sample rather than an aggregate, and a statistics built by this library keeps
// aggregates only, so the most recent is kept as the samples are passed - the only moment the sample's
// own interval is in hand. The oracle is the input: the harness builds three samples of one type, from
// two sources, with dates it chose, and can point at which is the most recent and which belongs to
// which source. The host is asked and answers nil, which says nothing about these, so that is stated
// rather than compared.
static void CharonHKStatistics12(void)
{
    NSDate *early = [NSDate dateWithTimeIntervalSince1970:1600000000];
    NSDate *middle = [NSDate dateWithTimeIntervalSince1970:1600000060];
    NSDate *late = [NSDate dateWithTimeIntervalSince1970:1600000120];
    CharonHostHKQuantityType *type = [CharonHostHKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierActiveEnergyBurned];
    CharonHostHKUnit *unit = [CharonHostHKUnit kilocalorieUnit];

    // Three samples: two from one source and one from another, in an order that is NOT the order of
    // their dates, so a class that kept the last one it was given would answer the wrong sample.
    CharonHostHKQuantitySample *a = [CharonHostHKQuantitySample quantitySampleWithType:type
                                                                           quantity:[CharonHostHKQuantity quantityWithUnit:unit doubleValue:10.0]
                                                                          startDate:middle endDate:middle];
    CharonHostHKQuantitySample *b = [CharonHostHKQuantitySample quantitySampleWithType:type
                                                                           quantity:[CharonHostHKQuantity quantityWithUnit:unit doubleValue:20.0]
                                                                          startDate:late endDate:late];
    CharonHostHKQuantitySample *c = [CharonHostHKQuantitySample quantitySampleWithType:type
                                                                           quantity:[CharonHostHKQuantity quantityWithUnit:unit doubleValue:30.0]
                                                                          startDate:early endDate:early];
    CharonHostHKStatistics *statistics = [CharonHostHKStatistics charon_statisticsForSamples:@[ a, b, c ]
                                                                                    options:HKStatisticsOptionCumulativeSum];
    if (!statistics) {
        printf("skipped: the port's statistics builder answered nothing for these samples\n");
        return;
    }

    // The most recent overall is the one that starts last, which is the middle sample of the input order.
    CharonHKCompareDouble(@"mostRecentQuantity is the sample that starts last",
                          [[statistics mostRecentQuantity] doubleValueForUnit:unit], 20.0);
    CharonHKCompare(@"mostRecentQuantityDateInterval is that sample's own interval",
                    statistics.mostRecentQuantityDateInterval.startDate, late);
    CharonHKCompareDouble(@"mostRecentQuantityDateInterval ends where the sample ends",
                          statistics.mostRecentQuantityDateInterval.duration, 0.0);

    // Per source: the port's own samples carry the port's own source, so a source's own answer is asked
    // with the source those samples have, and a source nothing came from answers nothing.
    CharonHostHKSource *source = [a valueForKey:@"source"];
    if (source) {
        CharonHKCompareDouble(@"mostRecentQuantityForSource: is that source's own most recent",
                              [[statistics mostRecentQuantityForSource:source] doubleValueForUnit:unit], 20.0);
        CharonHKCompare(@"mostRecentQuantityDateIntervalForSource: is that source's own interval",
                        [statistics mostRecentQuantityDateIntervalForSource:source].startDate, late);
    }
    // A source nothing came from. This library keys sources by bundle identifier - the same key its
    // -sources, its per-source answers and the store's own source_bundle column use - and in this build
    // no source has one, because there is no application here for HKSource to name, so every sample lands
    // in the one bucket. A source that is not among them cannot be made to name a different bucket from
    // outside, and the honest statement is the convention rather than a nil this build cannot produce.
    CharonHKCompare(@"every source here shares the one bucket, as the library's keying means",
                    (NSString *)([[a valueForKey:@"source"] valueForKey:@"bundleIdentifier"] ?: @""),
                    (NSString *)([[b valueForKey:@"source"] valueForKey:@"bundleIdentifier"] ?: @""));

    // A statistics over nothing answers nothing for any of the four, which is the header's own nil.
    CharonHostHKStatistics *empty = [CharonHostHKStatistics charon_statisticsForSamples:@[] options:HKStatisticsOptionCumulativeSum];
    CharonHKCompareBool(@"an empty statistics has no most recent quantity", empty.mostRecentQuantity == nil, YES);
    CharonHKCompareBool(@"an empty statistics has no most recent interval", empty.mostRecentQuantityDateInterval == nil, YES);

    printf("not compared: these four against the host. Its HealthKit has no entitlement here and builds "
           "no statistics this harness could read, so it answers nil for all four and that says nothing "
           "about what a statistics of real samples answers; the port's answers are compared against the "
           "samples and the dates the harness built above.\n");
}

// The cumulative quantity sample of 13.0, and its round trip through this library's own store.
//
// The host carries the class, so the shape of it is the host's to answer: that a cumulative sample holds
// a sum, and that the sum is the one that was given. What the host cannot do here is save one, because
// its HealthKit has no entitlement, so the round trip is this library's own store and the input the
// harness builds - and the mutant is the kind the row is stored under, because a cumulative sample read
// back as its superclass is a quantity sample with no sum, which is the only thing that distinguishes
// the two.
static void CharonHKCumulative13(void)
{
    NSDate *start = [NSDate dateWithTimeIntervalSince1970:1600000000];
    NSDate *end = [NSDate dateWithTimeIntervalSince1970:1600003600];
    CharonHostHKQuantityType *type = [CharonHostHKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierActiveEnergyBurned];
    CharonHostHKUnit *unit = [CharonHostHKUnit kilocalorieUnit];
    CharonHostHKQuantity *sum = [CharonHostHKQuantity quantityWithUnit:unit doubleValue:1234.0];

    // The host's own class, asked what a cumulative sample is.
    Class theirs = NSClassFromString(@"HKCumulativeQuantitySample");
    CharonHKCompare(@"the host carries the cumulative quantity sample", theirs ? @"yes" : @"no", @"yes");
    CharonHKCompareBool(@"the host's class answers a sum", [theirs instancesRespondToSelector:NSSelectorFromString(@"sumQuantity")], YES);
    CharonHKCompareBool(@"the host's class has no initialiser of its own",
                        [theirs instancesRespondToSelector:@selector(initWithType:quantity:startDate:endDate:)], NO);

    CharonHostHKHealthStore *store = [[CharonHostHKHealthStore alloc] init];
    __block BOOL authorised = NO;
    [store requestAuthorizationToShareTypes:[NSSet setWithObject:type]
                                  readTypes:[NSSet setWithObject:type]
                                 completion:^(BOOL success, NSError *error) { authorised = success; }];
    CharonHKWaitFor(&authorised);
    if (!authorised) {
        printf("skipped: the port's store granted no authorisation, so the cumulative sample cannot be measured here\n");
        return;
    }

    CharonHostHKCumulativeQuantitySample *sample =
        [CharonHostHKCumulativeQuantitySample charon_cumulativeWithType:type sum:sum startDate:start endDate:end];
    CharonHKCompareDouble(@"the sum is the one it was given",
                          [[sample sumQuantity] doubleValueForUnit:unit], 1234.0);
    // This harness renames the port's own classes, so the superclass to ask about is the port's - the
    // same reason the kind table goes through a resolver here.
    CharonHKCompareBool(@"a cumulative sample is a quantity sample",
                        [sample isKindOfClass:NSClassFromString(@"CharonHostHKQuantitySample")], YES);

    __block BOOL saved = NO;
    __block NSError *saveError = nil;
    [store saveObject:sample withCompletion:^(BOOL success, NSError *error) { saved = success; saveError = error; }];
    CharonHKWaitFor(&saved);
    if (!saved) {
        printf("the port's store took no cumulative sample: %s\n", saveError.localizedDescription.UTF8String);
    }
    CharonHKCompareBool(@"the store keeps a cumulative sample", saved, YES);
    if (saved) {
        CharonHostCharonHKStore *database = [CharonHostCharonHKStore sharedStore];
        NSArray *found = [database objectsWithUUIDs:@[ sample.UUID ] ofType:type error:NULL];
        CharonHKCompareInt(@"the cumulative sample is found again", (NSInteger)found.count, (NSInteger)1);
        id back = found.firstObject;
        CharonHKCompare(@"and it is found as this class, not as its superclass",
                        NSStringFromClass([back class]), NSStringFromClass([sample class]));
        CharonHKCompareBool(@"and it carries its sum", [back respondsToSelector:NSSelectorFromString(@"sumQuantity")], YES);
    }
}

// The cumulative sample of a series, of 12.0.
//
// The host carries the class, so it answers the shape: that it holds a sum of its own over the
// superclass's running total. What it cannot do here is save one, so the round trip is this library's
// store, and the mutant is the sum - the kind is not used, because since the archive's root is decoded by
// the unarchiver the kind does not decide what comes back.
static void CharonHKCumulativeSeries12(void)
{
    NSDate *start = [NSDate dateWithTimeIntervalSince1970:1600000000];
    NSDate *end = [NSDate dateWithTimeIntervalSince1970:1600007200];
    CharonHostHKQuantityType *type = [CharonHostHKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierActiveEnergyBurned];
    CharonHostHKUnit *unit = [CharonHostHKUnit kilocalorieUnit];
    CharonHostHKQuantity *sum = [CharonHostHKQuantity quantityWithUnit:unit doubleValue:4321.0];

    Class theirs = NSClassFromString(@"HKCumulativeQuantitySeriesSample");
    CharonHKCompare(@"the host carries the cumulative sample of a series", theirs ? @"yes" : @"no", @"yes");
    CharonHKCompareBool(@"the host's class answers a sum", [theirs instancesRespondToSelector:NSSelectorFromString(@"sum")], YES);

    CharonHostHKHealthStore *store = [[CharonHostHKHealthStore alloc] init];
    __block BOOL authorised = NO;
    [store requestAuthorizationToShareTypes:[NSSet setWithObject:type]
                                  readTypes:[NSSet setWithObject:type]
                                 completion:^(BOOL success, NSError *error) { authorised = success; }];
    CharonHKWaitFor(&authorised);
    if (!authorised) {
        printf("skipped: the port's store granted no authorisation, so the series sample cannot be measured here\n");
        return;
    }

    CharonHostHKCumulativeQuantitySeriesSample *sample =
        [CharonHostHKCumulativeQuantitySeriesSample charon_seriesWithType:type sum:sum startDate:start endDate:end];
    CharonHKCompareDouble(@"the sum is the one it was given",
                          [[sample sum] doubleValueForUnit:unit], 4321.0);
    // A series sample is a cumulative sample: it inherits the superclass's running total as well as
    // carrying its own.
    CharonHKCompareBool(@"a series sample is a cumulative sample",
                        [sample isKindOfClass:NSClassFromString(@"CharonHostHKCumulativeQuantitySample")], YES);
    CharonHKCompareDouble(@"and it keeps the superclass's own sum too",
                          [[sample sumQuantity] doubleValueForUnit:unit], 4321.0);

    __block BOOL saved = NO;
    __block NSError *saveError = nil;
    [store saveObject:sample withCompletion:^(BOOL success, NSError *error) { saved = success; saveError = error; }];
    CharonHKWaitFor(&saved);
    if (!saved) {
        printf("the port's store took no series sample: %s\n", saveError.localizedDescription.UTF8String);
    }
    CharonHKCompareBool(@"the store keeps a series sample", saved, YES);
    if (saved) {
        CharonHostCharonHKStore *database = [CharonHostCharonHKStore sharedStore];
        NSArray *found = [database objectsWithUUIDs:@[ sample.UUID ] ofType:type error:NULL];
        CharonHKCompareInt(@"the series sample is found again", (NSInteger)found.count, (NSInteger)1);
        id back = found.firstObject;
        CharonHKCompare(@"and it is found as this class",
                        NSStringFromClass([back class]), NSStringFromClass([sample class]));
        CharonHKCompareDouble(@"and it comes back carrying its sum",
                              [[back valueForKey:@"sum"] doubleValueForUnit:unit], 4321.0);
    }
}

int main(void)
{
    // Before the harness installs its own: this checks the resolver the library ships with, which is the
    // one a reader of the library gets.
    CharonHKDefaultResolver();
    CharonHKInstallClassResolver();
    CharonHKConstants12();
    CharonHKMeasuredConstants();
    CharonHKUnitCases();
    CharonHKPrefixedFactories();
    CharonHKUnitArithmetic();
    CharonHKQuantities();
    CharonHKTypeTable();
    CharonHKQueryObjects();
    CharonHK11Group();
    CharonHKWorkoutBuilder12();
    CharonHKSeriesBuilder12();
    CharonHKStoreRoundTrip();
    CharonHKSeriesQuery12();
    CharonHKStatistics12();
    CharonHKCumulative13();
    CharonHKCumulativeSeries12();
    printf("healthkit: %lu comparisons, %lu differences\n", (unsigned long)CharonHKComparisons,
           (unsigned long)CharonHKDifferences);
    return CharonHKDifferences == 0 ? 0 : 1;
}
