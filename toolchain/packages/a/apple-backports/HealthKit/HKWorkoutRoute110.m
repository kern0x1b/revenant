#import <HealthKit/HealthKit.h>

#import "RevenantHKStore.h"

#pragma mark - HKSeriesType

@implementation HKSeriesType
@end

@implementation HKObjectType (RevenantIOS110)

+ (nullable HKSeriesType *)seriesTypeForIdentifier:(NSString *)identifier
{
    if (![identifier isKindOfClass:[NSString class]] || ![identifier isEqualToString:HKWorkoutRouteTypeIdentifier])
        return nil;
    static HKSeriesType *type;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        type = [HKSeriesType revenant_typeWithIdentifier:HKWorkoutRouteTypeIdentifier];
    });
    return type;
}

@end

@implementation HKSeriesType (RevenantIOS110)

+ (HKSeriesType *)workoutRouteType
{
    return (HKSeriesType *)[HKObjectType seriesTypeForIdentifier:HKWorkoutRouteTypeIdentifier];
}

@end

#pragma mark - HKUnit

@implementation HKUnit (RevenantIOS110)

+ (instancetype)internationalUnit
{
    return [self revenant_namedUnit:@"IU"];
}

+ (instancetype)smallCalorieUnit
{
    return [self revenant_namedUnit:@"cal"];
}

+ (instancetype)largeCalorieUnit
{
    return [self revenant_namedUnit:@"Cal"];
}

@end

#pragma mark - HKSourceRevision

@implementation HKSourceRevision (RevenantIOS110)

- (instancetype)initWithSource:(HKSource *)source
                       version:(nullable NSString *)version
                   productType:(nullable NSString *)productType
          operatingSystemVersion:(NSOperatingSystemVersion)operatingSystemVersion
{
    HKSourceRevision *revision = [self revenant_initWithSource:source version:version];
    if (revision)
        [revision revenant_setProductType:productType operatingSystemVersion:operatingSystemVersion];
    return revision;
}

- (nullable NSString *)productType
{
    return [self revenant_storedProductType];
}

- (NSOperatingSystemVersion)operatingSystemVersion
{
    return [self revenant_storedOperatingSystemVersion];
}

@end

#pragma mark - HKDeletedObject

@implementation HKDeletedObject (RevenantIOS110)

- (nullable NSDictionary<NSString *, id> *)metadata
{
    return [self revenant_deletedMetadata];
}

@end

#pragma mark - HKWorkoutEvent

@implementation HKWorkoutEvent (RevenantIOS110)

+ (instancetype)workoutEventWithType:(HKWorkoutEventType)type
                       dateInterval:(NSDateInterval *)dateInterval
                            metadata:(nullable NSDictionary<NSString *, id> *)metadata
{
    if (![dateInterval isKindOfClass:[NSDateInterval class]]) {
        [NSException raise:NSInvalidArgumentException format:@"A workout event over a period needs the period it covers."];
        return nil;
    }
    HKWorkoutEvent *event = [[self alloc] revenant_initWithType:type date:dateInterval.startDate];
    [event revenant_setDateInterval:dateInterval];
    [event revenant_setMetadata:metadata];
    return event;
}

- (NSDateInterval *)dateInterval
{
    return [self revenant_storedDateInterval];
}

@end

#pragma mark - HKWorkout

@implementation HKWorkout (RevenantIOS110)

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
    HKWorkout *workout = [[HKWorkout alloc] revenant_initWithType:[HKObjectType workoutType]
                                                       metadata:metadata
                                                      startDate:startDate
                                                        endDate:endDate
                                                       duration:[endDate timeIntervalSinceDate:startDate]];
    if (workout) {
        [workout revenant_setWorkoutActivityType:activityType];
        [workout revenant_setTotalEnergyBurned:totalEnergyBurned totalDistance:totalDistance];
        [workout revenant_setTotalFlightsClimbed:totalFlightsClimbed];
        [workout revenant_setWorkoutEvents:workoutEvents];
        [workout revenant_setDevice:device];
    }
    return workout;
}

- (nullable HKQuantity *)totalFlightsClimbed
{
    return [self revenant_storedTotalFlightsClimbed];
}

@end

#pragma mark - HKQuery

@implementation HKQuery (RevenantIOS110)

+ (NSPredicate *)predicateForWorkoutsWithOperatorType:(NSPredicateOperatorType)type
                                totalFlightsClimbed:(HKQuantity *)flightsClimbed
{
    if (![flightsClimbed isKindOfClass:[HKQuantity class]])
        return nil;
    return [NSPredicate predicateWithFormat:@"%K %@ %@", HKPredicateKeyPathWorkoutTotalFlightsClimbed,
                                         [HKQuery revenant_predicateOperatorSpellingFor:type], flightsClimbed];
}

@end
