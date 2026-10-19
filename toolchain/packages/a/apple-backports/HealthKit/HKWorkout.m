#import <HealthKit/HealthKit.h>

#import "CharonHKStore.h"

@interface HKWorkoutEvent (CharonIOS100Internal)
- (instancetype)charon_initWithType:(HKWorkoutEventType)type date:(NSDate *)date;
@end

@implementation HKWorkoutEvent {
    HKWorkoutEventType _type;
    NSDate *_date;
    NSDictionary *_charonMetadata;
    NSDateInterval *_charonDateInterval;
}
CHARON_HEALTHKIT_UNCREATABLE_INIT

@dynamic dateInterval;
@dynamic metadata;


+ (BOOL)supportsSecureCoding
{
    return YES;
}

+ (instancetype)workoutEventWithType:(HKWorkoutEventType)type date:(NSDate *)date
{
    HKWorkoutEvent *event = [[HKWorkoutEvent alloc] charon_initWithType:type date:date];
    return event;
}

- (instancetype)charon_initWithType:(HKWorkoutEventType)type date:(NSDate *)date
{
    HKWorkoutEvent *fresh = [super init];
    if (fresh) {
        fresh->_type = type;
        fresh->_date = [date copy];
    }
    return fresh;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        _type = (HKWorkoutEventType)[coder decodeIntegerForKey:@"type"];
        _date = [[coder decodeObjectOfClass:[NSDate class] forKey:@"date"] copy];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeInteger:(NSInteger)_type forKey:@"type"];
    [coder encodeObject:_date forKey:@"date"];
}

- (id)copyWithZone:(NSZone *)zone
{
    return [HKWorkoutEvent workoutEventWithType:_type date:_date];
}

- (HKWorkoutEventType)type
{
    return _type;
}

- (NSDate *)date
{
    return _date;
}

- (nullable NSDictionary *)charon_storedMetadata
{
    return _charonMetadata;
}

- (void)charon_setMetadata:(nullable NSDictionary *)metadata
{
    _charonMetadata = [metadata copy];
}

- (nullable NSDateInterval *)charon_storedDateInterval
{
    return _charonDateInterval;
}

- (void)charon_setDateInterval:(nullable NSDateInterval *)dateInterval
{
    _charonDateInterval = [dateInterval copy];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"HKWorkoutEvent %ld at %@", (long)_type, _date];
}

@end

#pragma mark - HKWorkout

@implementation HKWorkout {
    HKWorkoutActivityType _workoutActivityType;
    HKQuantity *_totalEnergyBurned;
    HKQuantity *_totalDistance;
    NSArray<HKWorkoutEvent *> *_workoutEvents;
    NSTimeInterval _duration;
    HKQuantity *_charonStrokeCount;
    HKQuantity *_charonFlightsClimbed;
}

@dynamic totalSwimmingStrokeCount;
@dynamic totalFlightsClimbed;
@dynamic allStatistics;
@dynamic workoutActivities;


+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    HKWorkout *workout = [super initWithCoder:coder];
    if (workout) {
        workout->_duration = [coder decodeDoubleForKey:@"duration"];
        workout->_workoutActivityType = (HKWorkoutActivityType)[coder decodeIntegerForKey:@"workoutActivityType"];
        workout->_workoutEvents = [[coder decodeObjectOfClass:[NSArray class] forKey:@"workoutEvents"] copy] ?: @[];
        workout->_totalEnergyBurned = [[coder decodeObjectOfClass:[HKQuantity class] forKey:@"totalEnergyBurned"] copy];
        workout->_totalDistance = [[coder decodeObjectOfClass:[HKQuantity class] forKey:@"totalDistance"] copy];
        workout->_charonStrokeCount = [[coder decodeObjectOfClass:[HKQuantity class] forKey:@"totalSwimmingStrokeCount"] copy];
        workout->_charonFlightsClimbed = [[coder decodeObjectOfClass:[HKQuantity class] forKey:@"totalFlightsClimbed"] copy];
    }
    return workout;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    [coder encodeDouble:_duration forKey:@"duration"];
    [coder encodeInteger:(NSInteger)_workoutActivityType forKey:@"workoutActivityType"];
    [coder encodeObject:_workoutEvents forKey:@"workoutEvents"];
    [coder encodeObject:_totalEnergyBurned forKey:@"totalEnergyBurned"];
    [coder encodeObject:_totalDistance forKey:@"totalDistance"];
    [coder encodeObject:_charonStrokeCount forKey:@"totalSwimmingStrokeCount"];
    [coder encodeObject:_charonFlightsClimbed forKey:@"totalFlightsClimbed"];
}

- (instancetype)charon_initWithType:(HKObjectType *)type
                           metadata:(nullable NSDictionary *)metadata
                          startDate:(NSDate *)startDate
                            endDate:(NSDate *)endDate
                           duration:(NSTimeInterval)duration
{
    HKWorkout *workout = [super charon_initWithType:(HKSampleType *)type
                                          metadata:metadata
                                         startDate:startDate
                                           endDate:endDate];
    if (workout)
        workout->_duration = duration;
    return workout;
}

+ (instancetype)workoutWithActivityType:(HKWorkoutActivityType)activityType
                              startDate:(NSDate *)startDate
                                endDate:(NSDate *)endDate
{
    HKWorkout *workout = [[HKWorkout alloc] charon_initWithType:[HKObjectType workoutType]
                                                       metadata:nil
                                                      startDate:startDate
                                                        endDate:endDate
                                                       duration:[endDate timeIntervalSinceDate:startDate]];
    if (workout)
        workout->_workoutActivityType = activityType;
    return workout;
}

+ (instancetype)workoutWithActivityType:(HKWorkoutActivityType)activityType
                              startDate:(NSDate *)startDate
                                endDate:(NSDate *)endDate
                               duration:(NSTimeInterval)duration
                        totalEnergyBurned:(nullable HKQuantity *)totalEnergyBurned
                          totalDistance:(nullable HKQuantity *)totalDistance
                               metadata:(nullable NSDictionary *)metadata
{
    HKWorkout *workout = [[HKWorkout alloc] charon_initWithType:[HKObjectType workoutType]
                                                       metadata:metadata
                                                      startDate:startDate
                                                        endDate:[startDate dateByAddingTimeInterval:duration]
                                                       duration:duration];
    if (workout) {
        workout->_workoutActivityType = activityType;
        workout->_totalEnergyBurned = (HKQuantity *)[totalEnergyBurned copy];
        workout->_totalDistance = (HKQuantity *)[totalDistance copy];
    }
    return workout;
}

+ (instancetype)workoutWithActivityType:(HKWorkoutActivityType)activityType
                              startDate:(NSDate *)startDate
                                endDate:(NSDate *)endDate
                         workoutEvents:(NSArray<HKWorkoutEvent *> *)workoutEvents
                    totalEnergyBurned:(nullable HKQuantity *)totalEnergyBurned
                      totalDistance:(nullable HKQuantity *)totalDistance
                             metadata:(nullable NSDictionary *)metadata
{
    HKWorkout *workout = [[HKWorkout alloc] charon_initWithType:[HKObjectType workoutType]
                                                       metadata:metadata
                                                      startDate:startDate
                                                        endDate:endDate
                                                       duration:[endDate timeIntervalSinceDate:startDate]];
    if (workout) {
        workout->_workoutActivityType = activityType;
        workout->_workoutEvents = [workoutEvents copy] ?: @[];
        workout->_totalEnergyBurned = (HKQuantity *)[totalEnergyBurned copy];
        workout->_totalDistance = (HKQuantity *)[totalDistance copy];
    }
    return workout;
}

- (HKWorkoutActivityType)workoutActivityType
{
    return _workoutActivityType;
}

- (void)charon_setWorkoutActivityType:(HKWorkoutActivityType)activityType
{
    _workoutActivityType = activityType;
}

- (void)charon_setWorkoutEvents:(NSArray<HKWorkoutEvent *> *)workoutEvents
{
    _workoutEvents = [workoutEvents copy] ?: @[];
}

- (nullable HKQuantity *)charon_totalSwimmingStrokeCount
{
    return _charonStrokeCount;
}

- (void)charon_setTotalSwimmingStrokeCount:(nullable HKQuantity *)count
{
    _charonStrokeCount = (HKQuantity *)[count copy];
}

- (nullable HKQuantity *)charon_storedTotalFlightsClimbed
{
    return _charonFlightsClimbed;
}

- (void)charon_setTotalFlightsClimbed:(nullable HKQuantity *)flights
{
    _charonFlightsClimbed = (HKQuantity *)[flights copy];
}

- (void)charon_setTotalEnergyBurned:(nullable HKQuantity *)energy totalDistance:(nullable HKQuantity *)distance
{
    _totalEnergyBurned = (HKQuantity *)[energy copy];
    _totalDistance = (HKQuantity *)[distance copy];
}

- (NSTimeInterval)duration
{
    return _duration;
}

- (nullable HKQuantity *)totalEnergyBurned
{
    return _totalEnergyBurned;
}

- (nullable HKQuantity *)totalDistance
{
    return _totalDistance;
}

- (NSArray<HKWorkoutEvent *> *)workoutEvents
{
    return _workoutEvents;
}

- (NSInteger)charon_storeKind
{
    return 3;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"HKWorkout %ld from %@ to %@", (long)_workoutActivityType, self.startDate, self.endDate];
}

@end

@interface HKWorkout (CharonHKStorable) <CharonHKStorable>
@end

@implementation HKWorkout (CharonHKStorable)
@end
