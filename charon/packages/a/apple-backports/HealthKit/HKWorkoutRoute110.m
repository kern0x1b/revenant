// The iOS 11.0 members of the classes of 8.0, 9.0 and 10.0, and the series type of that release.
//
// One object per release: this file is of 11.0 alone, and the workout route's own classes are in
// HKWorkoutRouteQuery110.m beside it, the eighteen exported constants in HKConstants110.m, and the two
// abstract superclasses the corpus omits in HKSeriesBuilder.m with the release they belong to.
//
// A note on HKSourceRevisionAnyOperatingSystem, the one constant of this release whose value is not
// in the header: the SDK header declares it `NSOperatingSystemVersion const`, a struct of three
// integers, and the arm64 shared caches of 11.0 and of 12.0 hold its three words as -2, 0 and 0.
// HKConstants110.m carries them as read, and the header's comment above all three names says they
// match any value of the property.

#import <HealthKit/HealthKit.h>

#import "CharonHKStore.h"

#pragma mark - HKSeriesType

// The type of a series: what a set of samples that belong together is a series of.
@implementation HKSeriesType
@end

@implementation HKObjectType (CharonIOS110)

+ (nullable HKSeriesType *)seriesTypeForIdentifier:(NSString *)identifier
{
    if (![identifier isKindOfClass:[NSString class]] || ![identifier isEqualToString:HKWorkoutRouteTypeIdentifier])
        return nil;
    static HKSeriesType *type;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        type = [HKSeriesType charon_typeWithIdentifier:HKWorkoutRouteTypeIdentifier];
    });
    return type;
}

@end

@implementation HKSeriesType (CharonIOS110)

+ (HKSeriesType *)workoutRouteType
{
    return (HKSeriesType *)[HKObjectType seriesTypeForIdentifier:HKWorkoutRouteTypeIdentifier];
}

@end

#pragma mark - HKUnit

// The three factories of 11.0. The unit strings are the header's own comments beside them: the
// international unit of a pharmacology is `IU` and is a dimension of its own, and the two calories are
// the small and the large one - 4.184 J and 4184 J - which the 8.0 table already carried under those
// names and with those factors.
@implementation HKUnit (CharonIOS110)

+ (instancetype)internationalUnit
{
    return [self charon_namedUnit:@"IU"];
}

+ (instancetype)smallCalorieUnit
{
    return [self charon_namedUnit:@"cal"];
}

+ (instancetype)largeCalorieUnit
{
    return [self charon_namedUnit:@"Cal"];
}

@end

#pragma mark - HKSourceRevision

@implementation HKSourceRevision (CharonIOS110)

// A revision of the source given, with the version, the product and the operating system the source was
// on. The two new members are kept as they are given and read back as they were, and the port's own
// constructor of 9.0 is what sets the two older ones, so the two forms share one path.
- (instancetype)initWithSource:(HKSource *)source
                       version:(nullable NSString *)version
                   productType:(nullable NSString *)productType
          operatingSystemVersion:(NSOperatingSystemVersion)operatingSystemVersion
{
    // This is a category, so [super ...] would reach NSObject: the class's own constructor is called
    // on self, and the two members are set on the object it returns.
    HKSourceRevision *revision = [self charon_initWithSource:source version:version];
    if (revision)
        [revision charon_setProductType:productType operatingSystemVersion:operatingSystemVersion];
    return revision;
}

// The product the source was on - "iPhone" and the like - which the header's two sentinels are there
// to match against, and which this release's own sources carry and the port keeps.
- (nullable NSString *)productType
{
    return [self charon_storedProductType];
}

// The version of the operating system the source was on, as the three integers of the struct the
// header declares.
- (NSOperatingSystemVersion)operatingSystemVersion
{
    return [self charon_storedOperatingSystemVersion];
}

@end

#pragma mark - HKDeletedObject

@implementation HKDeletedObject (CharonIOS110)

// The metadata the object carried when it was deleted, which the store keeps with the identifier it
// deleted, so that a caller can say what has gone and not only that something has.
- (nullable NSDictionary<NSString *, id> *)metadata
{
    return [self charon_deletedMetadata];
}

@end

#pragma mark - HKWorkoutEvent

@implementation HKWorkoutEvent (CharonIOS110)

// An event over a period rather than at an instant, which is what the routing events of 11.0 are: the
// period the event covers is kept as the release keeps it, and the period's start is the same date the
// one-argument factory takes.
//
// The release also validates the period's duration against the event's type and refuses an hour-long
// pause, where this port accepts one. The bounds are Apple's and in no SDK header, so there is nothing
// to read them out of and nothing is invented here: measured by tests/backports/host/healthkit, which
// names the refusal in its output rather than passing over it.
+ (instancetype)workoutEventWithType:(HKWorkoutEventType)type
                       dateInterval:(NSDateInterval *)dateInterval
                            metadata:(nullable NSDictionary<NSString *, id> *)metadata
{
    if (![dateInterval isKindOfClass:[NSDateInterval class]]) {
        [NSException raise:NSInvalidArgumentException format:@"A workout event over a period needs the period it covers."];
        return nil;
    }
    HKWorkoutEvent *event = [[self alloc] charon_initWithType:type date:dateInterval.startDate];
    [event charon_setDateInterval:dateInterval];
    [event charon_setMetadata:metadata];
    return event;
}

// The period the event covers, as the release keeps it. The header declares it for 11.0 and later, and
// an event made through the one-argument factory of 8.0 is at an instant and has no period, so the
// value is nil for one of those and a period for every event of 11.0.
- (NSDateInterval *)dateInterval
{
    return [self charon_storedDateInterval];
}

@end

#pragma mark - HKWorkout

@implementation HKWorkout (CharonIOS110)

// The release's own factory of 11.0: the form of 10.0 with the flights climbed added. The count is
// kept as it is given and read back, and the duration is the one the two dates say.
+ (instancetype)workoutWithActivityType:(HKWorkoutActivityType)activityType
                              startDate:(NSDate *)startDate
                                endDate:(NSDate *)endDate
                         workoutEvents:(NSArray<HKWorkoutEvent *> *)workoutEvents
                    totalEnergyBurned:(nullable HKQuantity *)totalEnergyBurned
                      totalDistance:(nullable HKQuantity *)totalDistance
                 totalFlightsClimbed:(nullable HKQuantity *)totalFlightsClimbed
                                device:(nullable HKDevice *)device
                              metadata:(nullable NSDictionary *)metadata
{
    HKWorkout *workout = [[HKWorkout alloc] charon_initWithType:[HKObjectType workoutType]
                                                       metadata:metadata
                                                      startDate:startDate
                                                        endDate:endDate
                                                       duration:[endDate timeIntervalSinceDate:startDate]];
    if (workout) {
        [workout charon_setWorkoutActivityType:activityType];
        [workout charon_setTotalEnergyBurned:totalEnergyBurned totalDistance:totalDistance];
        [workout charon_setTotalFlightsClimbed:totalFlightsClimbed];
        [workout charon_setWorkoutEvents:workoutEvents];
        [workout charon_setDevice:device];
    }
    return workout;
}

// The flights climbed, kept as it is given and read back, and nil where none was given.
- (nullable HKQuantity *)totalFlightsClimbed
{
    return [self charon_storedTotalFlightsClimbed];
}

@end

#pragma mark - HKQuery

@implementation HKQuery (CharonIOS110)

// A predicate over the flights climbed, over the key path that names it, which the 11.0 image holds
// as "totalFlightsClimbed".
+ (NSPredicate *)predicateForWorkoutsWithOperatorType:(NSPredicateOperatorType)type
                                totalFlightsClimbed:(HKQuantity *)flightsClimbed
{
    if (![flightsClimbed isKindOfClass:[HKQuantity class]])
        return nil;
    return [NSPredicate predicateWithFormat:@"%K %@ %@", HKPredicateKeyPathWorkoutTotalFlightsClimbed,
                                         [HKQuery charon_predicateOperatorSpellingFor:type], flightsClimbed];
}

@end
