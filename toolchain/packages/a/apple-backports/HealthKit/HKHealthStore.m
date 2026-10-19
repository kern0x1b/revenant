#import <HealthKit/HealthKit.h>

#import "RevenantHKStore.h"
#import "../RevenantSayOnce.h"

@implementation HKHealthStore {
    NSMutableSet<NSValue *> *_running;
}

+ (BOOL)supportsSecureCoding
{
    return NO;
}

+ (BOOL)isHealthDataAvailable
{
    return YES;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _running = [NSMutableSet set];
        NSError *error = nil;
        if (![[RevenantHKStore sharedStore] openWithError:&error])
            revenant_hk_say_once(@"health-store-open", [NSString stringWithFormat:@"HealthKit: %@", error.localizedDescription]);
    }
    return self;
}

#pragma mark - Authorization

- (HKAuthorizationStatus)authorizationStatusForType:(HKObjectType *)type
{
    if (![type isKindOfClass:[HKObjectType class]])
        return HKAuthorizationStatusNotDetermined;
    return [[RevenantHKStore sharedStore] authorizationStatusForType:type];
}

- (void)requestAuthorizationToShareTypes:(nullable NSSet<HKSampleType *> *)typesToShare
                              readTypes:(nullable NSSet<HKObjectType *> *)typesToRead
                             completion:(void (^)(BOOL success, NSError *_Nullable error))completion
{
    if (!completion)
        return;
    NSError *error = nil;
    BOOL ok = [[RevenantHKStore sharedStore] recordAuthorizationToShare:typesToShare read:typesToRead error:&error];
    if (!ok)
        revenant_hk_say_once(@"authorization-failed", [NSString stringWithFormat:@"HealthKit: %@", error.localizedDescription]);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        completion(ok, ok ? nil : error);
    });
}

#pragma mark - Saving and deleting

- (void)saveObject:(HKObject *)object withCompletion:(void (^)(BOOL success, NSError *_Nullable error))completion
{
    [self saveObjects:object ? @[object] : @[] withCompletion:completion];
}

- (void)saveObjects:(NSArray<HKObject *> *)objects withCompletion:(void (^)(BOOL success, NSError *_Nullable error))completion
{
    NSError *error = nil;
    BOOL ok = [[RevenantHKStore sharedStore] saveObjects:objects ?: @[] error:&error];
    [self revenant_complete:completion ok:ok error:error];
}

- (void)deleteObject:(HKObject *)object withCompletion:(void (^)(BOOL success, NSError *_Nullable error))completion
{
    [self deleteObjects:object ? @[object] : @[] withCompletion:completion];
}

- (void)revenant_complete:(void (^)(BOOL, NSError *))completion ok:(BOOL)ok error:(NSError *)error
{
    if (!completion)
        return;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        completion(ok, error);
    });
}

#pragma mark - Queries

- (void)executeQuery:(HKQuery *)query
{
    if (![query conformsToProtocol:@protocol(RevenantHKRunnableQuery)]) {
        [NSException raise:NSInvalidArgumentException
                    format:@"%@ is not a query this store can execute.", NSStringFromClass([query class])];
        return;
    }
    if ([(id<RevenantHKRunnableQuery>)query revenant_hasBeenExecuted]) {
        [NSException raise:NSInvalidArgumentException
                    format:@"Each HKQuery instance may only be executed once, and this one has been executed already."];
        return;
    }
    [(id<RevenantHKRunnableQuery>)query revenant_setHasBeenExecuted:YES];
    [(id<RevenantHKRunnableQuery>)query revenant_run];
    @synchronized(_running) {
        [_running addObject:[NSValue valueWithNonretainedObject:query]];
    }
}

- (void)stopQuery:(HKQuery *)query
{
    @synchronized(_running) {
        [_running removeObject:[NSValue valueWithNonretainedObject:query]];
    }
    if ([query conformsToProtocol:@protocol(RevenantHKRunnableQuery)])
        [(id<RevenantHKRunnableQuery>)query revenant_stop];
}

#pragma mark - Background delivery

- (void)enableBackgroundDeliveryForType:(HKObjectType *)type
                              frequency:(HKUpdateFrequency)frequency
                           withCompletion:(void (^)(BOOL success, NSError *_Nullable error))completion
{
    NSError *error = nil;
    BOOL ok = [[RevenantHKStore sharedStore] setBackgroundDelivery:YES forType:type frequency:frequency error:&error];
    if (ok)
        revenant_hk_say_once(@"background-delivery",
                           @"HealthKit: background delivery is registered and kept, but this release has no health daemon to wake the "
                           @"application for it, so nothing is delivered. A query left running, or an observer query, is the way to be "
                           @"told of a change on this release.");
    [self revenant_complete:completion ok:ok error:error];
}

- (void)disableBackgroundDeliveryForType:(HKObjectType *)type withCompletion:(void (^)(BOOL success, NSError *_Nullable error))completion
{
    NSError *error = nil;
    BOOL ok = [[RevenantHKStore sharedStore] setBackgroundDelivery:NO forType:type frequency:0 error:&error];
    [self revenant_complete:completion ok:ok error:error];
}

- (void)disableAllBackgroundDeliveryWithCompletion:(void (^)(BOOL success, NSError *_Nullable error))completion
{
    NSError *error = nil;
    BOOL ok = [[RevenantHKStore sharedStore] disableAllBackgroundDeliveryWithError:&error];
    [self revenant_complete:completion ok:ok error:error];
}

#pragma mark - The characteristics of the user

- (nullable NSDate *)dateOfBirthWithError:(NSError *__autoreleasing *)error
{
    NSDate *stored = [[RevenantHKStore sharedStore] characteristicForIdentifier:HKCharacteristicTypeIdentifierDateOfBirth];
    if (!stored && error)
        *error = RevenantHKError(HKErrorNoData,
                               @"No date of birth is recorded. The user enters it in the Health application on a release that has one, "
                               @"and iOS 8.0's public API of HKHealthStore has no way to write it either.",
                               nil);
    return stored;
}

- (nullable HKBiologicalSexObject *)biologicalSexWithError:(NSError *__autoreleasing *)error
{
    if (![[RevenantHKStore sharedStore] mayReadType:[HKObjectType characteristicTypeForIdentifier:HKCharacteristicTypeIdentifierBiologicalSex]]) {
        if (error)
            *error = RevenantHKError(HKErrorAuthorizationDenied, @"Reading the biological sex has not been authorized.", nil);
        return nil;
    }
    NSNumber *stored = [[RevenantHKStore sharedStore] characteristicForIdentifier:HKCharacteristicTypeIdentifierBiologicalSex];
    if (!stored) {
        if (error)
            *error = RevenantHKError(HKErrorNoData,
                                   @"No biological sex is recorded. The user enters it in the Health application on a release that has "
                                   @"one, and iOS 8.0's public API of HKHealthStore has no way to write it either.",
                                   nil);
        return nil;
    }
    return [HKBiologicalSexObject revenant_biologicalSexObject:(HKBiologicalSex)stored.integerValue];
}

- (nullable HKBloodTypeObject *)bloodTypeWithError:(NSError *__autoreleasing *)error
{
    if (![[RevenantHKStore sharedStore] mayReadType:[HKObjectType characteristicTypeForIdentifier:HKCharacteristicTypeIdentifierBloodType]]) {
        if (error)
            *error = RevenantHKError(HKErrorAuthorizationDenied, @"Reading the blood type has not been authorized.", nil);
        return nil;
    }
    NSNumber *stored = [[RevenantHKStore sharedStore] characteristicForIdentifier:HKCharacteristicTypeIdentifierBloodType];
    if (!stored) {
        if (error)
            *error = RevenantHKError(HKErrorNoData,
                                   @"No blood type is recorded. The user enters it in the Health application on a release that has one, "
                                   @"and iOS 8.0's public API of HKHealthStore has no way to write it either.",
                                   nil);
        return nil;
    }
    return [HKBloodTypeObject revenant_bloodTypeObject:(HKBloodType)stored.integerValue];
}

#pragma mark - Workouts

- (void)addSamples:(NSArray<HKSample *> *)samples
         toWorkout:(HKWorkout *)workout
        completion:(void (^)(BOOL success, NSError *_Nullable error))completion
{
    if (![workout isKindOfClass:[HKWorkout class]] || !samples.count) {
        [self revenant_complete:completion
                          ok:NO
                       error:RevenantHKError(HKErrorInvalidArgument, @"A workout and at least one sample are both needed.", nil)];
        return;
    }
    NSError *error = nil;
    BOOL ok = [[RevenantHKStore sharedStore] addSamples:samples toWorkout:workout error:&error];
    [self revenant_complete:completion ok:ok error:error];
}

@end
