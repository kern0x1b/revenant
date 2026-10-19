// HKWorkoutBuilder of iOS 12.0: the workout built out of samples, events and metadata added over a
// period, rather than handed to a factory whole.
//
// One object per release: this file is of 12.0 alone.
//
// The builder is a state machine the header describes and the host's own answers are the measure of:
// collection is begun with a start date, samples, events and metadata are added while it is begun, the
// period is ended with an end date, and the workout is either finished - which saves it through the
// store it was made with - or discarded. Anything added before the collection is begun, or finished
// before it is ended, is the host's own refusal, and the completion says so rather than the port
// inventing a value.
//
// -workoutActivities, -allStatistics, -addWorkoutActivity:completion: and the two
// -updateActivityWithUUID:... are of 16.0 and are @dynamic, so their selectors are not in the library
// at all and -respondsToSelector: answers NO for them, rather than an accessor that would answer nil
// and look like a version of the class this library has. -init is NS_UNAVAILABLE in the header and no
// initialiser is emitted for it.

#import <HealthKit/HealthKit.h>

#import "CharonHKStore.h"

// The store's own save, so that a finished workout reaches the same SQLite file every other object of
// this library does, and the header's promise that the store is retained until the workout is saved or
// discarded is kept by holding it here.
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
    // Whether -beginCollectionWithStartDate: has been called and -endCollectionWithEndDate: has not.
    // The header says the first is required before anything is added, and the host refuses anything
    // added outside the period, so the flag is what the refusals are read from.
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
    // A period that ends before it began is the host's own refusal, and the header's dates are the two
    // it is given rather than the two it guesses: nothing is swapped and no length is invented.
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
    // The header calls this the time elapsed since the workout began, so a builder that has not begun
    // one has elapsed none of it and answers zero rather than the interval from a nil date.
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
    // The header says the metadata of a workout is the metadata added to it, so an entry added twice
    // answers the value added last, which is what a dictionary assignment is and what the host's own
    // accumulation does.
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
    // The header's state machine is begin, add, end, finish - and -endCollectionWithEndDate: is what
    // closes the period, so at the finish _collecting is already NO for a builder that was used the way
    // the header says. This gate used to ask for _collecting, which made a workout impossible to finish:
    // the one case the header describes, a period begun and ended, was the one case refused. What the
    // finish needs is a period that has been ended, which is the next check.
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
    // The 11.0 factory that takes the device and the flights climbed is the release's own form for a
    // builder's workout, and the builder is where a device comes from, so the two are set on the
    // workout the factory made rather than guessed at.
    [workout charon_setWorkoutActivityType:activityType];
    [workout charon_setTotalEnergyBurned:[self charon_totalOfType:HKQuantityTypeIdentifierActiveEnergyBurned]
                            totalDistance:[self charon_totalOfType:HKQuantityTypeIdentifierDistanceWalkingRunning]];
    if (_device)
        [workout charon_setDevice:_device];

    // The header's own promise: the store the builder was made with is the store the workout is saved
    // through, and the completion is the header's - a workout and no error, or nothing and an error.
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
    // The header says a discarded workout is not saved, so what has been collected is dropped and the
    // builder is finished: a second -finishWorkoutWithCompletion: is the host's own refusal.
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
    // The header's own member here is the cumulative sum, which is the option a statistics object of a
    // workout is built with, and the same builder the statistics query of this library uses.
    return [HKStatistics charon_statisticsForSamples:ofType options:HKStatisticsOptionCumulativeSum];
}

#pragma mark - what the refusals and the totals are

// Whether anything may be added now, and the host's own refusal when it may not.
//
// The code of a refusal about the builder's own state is zero, and that is a statement rather than a
// gap: no SDK header of 16.4 or 26.2 declares a code for these, and the host could not be asked on this
// machine, which answers every call that touches health data with com.apple.healthkit 1, "Health data
// is unavailable on this device", and returns before the state of the builder is ever consulted. A code
// written here would be this library's own invention wearing Apple's name, so the wording carries the
// refusal and the code says only that none is claimed. The one refusal the host did answer is
// -charon_emptySamplesError, with the code and the text it answered.
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

// The one refusal whose code and wording the host itself was measured answering, on this machine, for
// an empty array of samples: com.apple.healthkit 3, "HKWorkout: HKSample data cannot be nil or empty."
// An empty or nil array is refused rather than accepted and ignored, because that is what the host does
// with it and a caller that adds nothing is asking for nothing.
- (NSError *)charon_emptySamplesError
{
    return [NSError errorWithDomain:HKErrorDomain code:3 userInfo:@{
        NSLocalizedDescriptionKey: @"HKWorkout: HKSample data cannot be nil or empty."
    }];
}

// The total a workout carries for a type: the sum of the samples of that type added to it, in the base
// unit of its dimension, which is what the factory of 8.0 takes and what the header's own workout
// answers for the totals.
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
