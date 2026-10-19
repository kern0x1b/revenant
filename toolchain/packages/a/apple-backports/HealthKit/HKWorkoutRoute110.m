#import <HealthKit/HealthKit.h>

#import "CharonHKStore.h"

#pragma mark - HKSeriesType

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

- (instancetype)initWithSource:(HKSource *)source
                       version:(nullable NSString *)version
                   productType:(nullable NSString *)productType
          operatingSystemVersion:(NSOperatingSystemVersion)operatingSystemVersion
{
    HKSourceRevision *revision = [self charon_initWithSource:source version:version];
    if (revision)
        [revision charon_setProductType:productType operatingSystemVersion:operatingSystemVersion];
    return revision;
}

- (nullable NSString *)productType
{
    return [self charon_storedProductType];
}

- (NSOperatingSystemVersion)operatingSystemVersion
{
    return [self charon_storedOperatingSystemVersion];
}

@end

#pragma mark - HKDeletedObject

@implementation HKDeletedObject (CharonIOS110)

- (nullable NSDictionary<NSString *, id> *)metadata
{
    return [self charon_deletedMetadata];
}

@end

#pragma mark - HKWorkoutEvent

@implementation HKWorkoutEvent (CharonIOS110)

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

- (NSDateInterval *)dateInterval
{
    return [self charon_storedDateInterval];
}

@end

#pragma mark - HKWorkout

@implementation HKWorkout (CharonIOS110)

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

- (nullable HKQuantity *)totalFlightsClimbed
{
    return [self charon_storedTotalFlightsClimbed];
}

@end

#pragma mark - HKQuery

@implementation HKQuery (CharonIOS110)

+ (NSPredicate *)predicateForWorkoutsWithOperatorType:(NSPredicateOperatorType)type
                                totalFlightsClimbed:(HKQuantity *)flightsClimbed
{
    if (![flightsClimbed isKindOfClass:[HKQuantity class]])
        return nil;
    return [NSPredicate predicateWithFormat:@"%K %@ %@", HKPredicateKeyPathWorkoutTotalFlightsClimbed,
                                         [HKQuery charon_predicateOperatorSpellingFor:type], flightsClimbed];
}

@end
