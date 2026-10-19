#import <HealthKit/HealthKit.h>

#import "CharonHKStore.h"

@interface HKHealthStore (CharonIOS120Internal)
- (void)saveObject:(HKObject *)object withCompletion:(void (^)(BOOL success, NSError *_Nullable error))completion;
@end

@implementation HKWorkoutBuilder {
    HKHealthStore *_healthStore;
    HKWorkoutConfiguration *_workoutConfiguration;
    HKDevice *_device;
    NSDate *_startDate;
    NSDate *_endDate;
    NSMutableDictionary<NSString *, id> *_metadata;
    NSMutableArray<HKWorkoutEvent *> *_workoutEvents;
    NSMutableArray<HKSample *> *_samples;
    BOOL _collecting;
    BOOL _finished;
}
CHARON_HEALTHKIT_UNCREATABLE_INIT
@dynamic workoutActivities;
@dynamic allStatistics;

- (instancetype)initWithHealthStore:(HKHealthStore *)healthStore
                      configuration:(HKWorkoutConfiguration *)configuration
                             device:(nullable HKDevice *)device
{
    self = [super init];
    if (self) {
        _healthStore = healthStore;
        _workoutConfiguration = configuration;
        _device = device;
        _metadata = [NSMutableDictionary dictionary];
        _workoutEvents = [NSMutableArray array];
        _samples = [NSMutableArray array];
    }
    return self;
}

#pragma mark - the header's readonly state

- (nullable HKDevice *)device
{
    return _device;
}

- (nullable NSDate *)startDate
{
    return _startDate;
}

- (nullable NSDate *)endDate
{
    return _endDate;
}

- (HKWorkoutConfiguration *)workoutConfiguration
{
    return _workoutConfiguration;
}

- (NSDictionary<NSString *, id> *)metadata
{
    return [_metadata copy];
}

- (NSArray<HKWorkoutEvent *> *)workoutEvents
{
    return [_workoutEvents copy];
}

#pragma mark - the period

- (void)beginCollectionWithStartDate:(NSDate *)startDate completion:(void (^)(BOOL, NSError *_Nullable))completion
{
    if (_finished) {
        if (completion)
            completion(NO, [self charon_errorWithReason:@"workoutAlreadyFinished" code:0]);
        return;
    }
    if (_collecting) {
        if (completion)
            completion(NO, [self charon_errorWithReason:@"workoutCollectionAlreadyStarted" code:0]);
        return;
    }
    _startDate = [startDate copy];
    _collecting = YES;
    if (completion)
        completion(YES, nil);
}

- (void)endCollectionWithEndDate:(NSDate *)endDate completion:(void (^)(BOOL, NSError *_Nullable))completion
{
    if (_finished) {
        if (completion)
            completion(NO, [self charon_errorWithReason:@"workoutAlreadyFinished" code:0]);
        return;
    }
    if (!_collecting) {
        if (completion)
            completion(NO, [self charon_errorWithReason:@"workoutCollectionNotStarted" code:0]);
        return;
    }
    if ([endDate compare:_startDate] == NSOrderedAscending) {
        if (completion)
            completion(NO, [self charon_errorWithReason:@"workoutEndDatePrecedesStartDate" code:0]);
        return;
    }
    _endDate = [endDate copy];
    _collecting = NO;
    if (completion)
        completion(YES, nil);
}

- (NSTimeInterval)elapsedTimeAtDate:(NSDate *)date
{
    if (!_startDate || !date)
        return 0.0;
    return [date timeIntervalSinceDate:_startDate];
}

#pragma mark - what is added

- (void)addSamples:(NSArray<HKSample *> *)samples completion:(void (^)(BOOL, NSError *_Nullable))completion
{
    if (!samples.count) {
        if (completion)
            completion(NO, [self charon_emptySamplesError]);
        return;
    }
    if (![self charon_canAddWithReason:@"workoutCollectionNotStarted" code:0 completion:completion])
        return;
    for (HKSample *sample in samples)
        if (sample)
            [_samples addObject:sample];
    if (completion)
        completion(YES, nil);
}

- (void)addWorkoutEvents:(NSArray<HKWorkoutEvent *> *)workoutEvents completion:(void (^)(BOOL, NSError *_Nullable))completion
{
    if (![self charon_canAddWithReason:@"workoutCollectionNotStarted" code:0 completion:completion])
        return;
    for (HKWorkoutEvent *event in workoutEvents)
        if (event)
            [_workoutEvents addObject:event];
    if (completion)
        completion(YES, nil);
}

- (void)addMetadata:(NSDictionary<NSString *, id> *)metadata completion:(void (^)(BOOL, NSError *_Nullable))completion
{
    if (![self charon_canAddWithReason:@"workoutCollectionNotStarted" code:0 completion:completion])
        return;
    [_metadata addEntriesFromDictionary:metadata ?: @{}];
    if (completion)
        completion(YES, nil);
}

#pragma mark - the workout itself

- (void)finishWorkoutWithCompletion:(void (^)(HKWorkout *_Nullable, NSError *_Nullable))completion
{
    if (_finished) {
        if (completion)
            completion(nil, [self charon_errorWithReason:@"workoutAlreadyFinished" code:0]);
        return;
    }
    if (!_endDate) {
        if (completion)
            completion(nil, [self charon_errorWithReason:@"workoutCollectionNotStartedOrNotEnded" code:0]);
        return;
    }

    HKWorkoutActivityType activityType = _workoutConfiguration ? _workoutConfiguration.activityType
                                                               : HKWorkoutActivityTypeOther;
    HKWorkout *workout = [HKWorkout workoutWithActivityType:activityType
                                                   startDate:_startDate
                                                     endDate:_endDate
                                              workoutEvents:[_workoutEvents copy]
                                         totalEnergyBurned:nil
                                           totalDistance:nil
                                                  metadata:[_metadata copy]];
    [workout charon_setWorkoutActivityType:activityType];
    [workout charon_setTotalEnergyBurned:[self charon_totalOfType:HKQuantityTypeIdentifierActiveEnergyBurned]
                            totalDistance:[self charon_totalOfType:HKQuantityTypeIdentifierDistanceWalkingRunning]];
    if (_device)
        [workout charon_setDevice:_device];

    __weak HKWorkoutBuilder *weakSelf = self;
    [_healthStore saveObject:workout withCompletion:^(BOOL success, NSError *_Nullable error) {
        HKWorkoutBuilder *strongSelf = weakSelf;
        if (strongSelf)
            strongSelf->_finished = YES;
        if (completion)
            completion(success ? workout : nil, success ? nil : (error ?: [strongSelf charon_errorWithReason:@"workoutSaveFailed" code:0]));
    }];
}

- (void)discardWorkout
{
    _finished = YES;
    _collecting = NO;
    [_samples removeAllObjects];
    [_workoutEvents removeAllObjects];
    [_metadata removeAllObjects];
    _startDate = nil;
    _endDate = nil;
}

- (nullable HKStatistics *)statisticsForType:(HKQuantityType *)quantityType
{
    if (![quantityType isKindOfClass:[HKQuantityType class]])
        return nil;
    NSMutableArray<HKSample *> *ofType = [NSMutableArray array];
    for (HKSample *sample in _samples)
        if ([sample.sampleType isEqual:quantityType])
            [ofType addObject:sample];
    if (!ofType.count)
        return nil;
    return [HKStatistics charon_statisticsForSamples:ofType options:HKStatisticsOptionCumulativeSum];
}

#pragma mark - what the refusals and the totals are

- (BOOL)charon_canAddWithReason:(NSString *)reason code:(NSInteger)code completion:(void (^)(BOOL, NSError *_Nullable))completion
{
    if (_finished) {
        if (completion)
            completion(NO, [self charon_errorWithReason:reason code:0]);
        return NO;
    }
    if (!_collecting) {
        if (completion)
            completion(NO, [self charon_errorWithReason:reason code:0]);
        return NO;
    }
    return YES;
}

- (NSError *)charon_errorWithReason:(NSString *)reason code:(NSInteger)code
{
    return [NSError errorWithDomain:HKErrorDomain code:code userInfo:@{
        NSLocalizedDescriptionKey: [NSString stringWithFormat:@"HKWorkout: %@", reason]
    }];
}

- (NSError *)charon_emptySamplesError
{
    return [NSError errorWithDomain:HKErrorDomain code:3 userInfo:@{
        NSLocalizedDescriptionKey: @"HKWorkout: HKSample data cannot be nil or empty."
    }];
}

- (nullable HKQuantity *)charon_totalOfType:(HKQuantityTypeIdentifier)identifier
{
    HKQuantityType *type = [HKObjectType quantityTypeForIdentifier:identifier];
    if (!type)
        return nil;
    NSMutableArray<HKSample *> *ofType = [NSMutableArray array];
    for (HKSample *sample in _samples)
        if ([sample.sampleType isEqual:type])
            [ofType addObject:sample];
    if (!ofType.count)
        return nil;
    HKStatistics *statistics = [HKStatistics charon_statisticsForSamples:ofType options:HKStatisticsOptionCumulativeSum];
    return statistics.sumQuantity;
}

@end
