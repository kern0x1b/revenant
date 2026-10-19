// HKHealthStore: what an application asks of the health data, and the store that answers it.
//
// Every answer here comes out of CharonHKStore, the SQLite database under Application Support that
// stands in for the healthd of the releases that have one. What this release does not have is said
// once, in the log, and is said in the registry and in facts/HealthKit:
//
//   - The authorization sheet is a SpringBoard surface. This release has no health application, so
//     there is no sheet to put up, and a request records what it was asked for and calls its
//     completion with success. The store then enforces it: a save of a type the process may not share
//     fails with HKErrorAuthorizationDenied, and a query that finds a type it may not read answers
//     the same error and returns nothing.
//   - Background delivery is woken by the healthd. Nothing here wakes the process, so a registration
//     is kept and read back, and nothing more is claimed for it.
//   - The user sets their own biological sex, blood type and date of birth in the Health application.
//     This release has none, and iOS 8's public API of HKHealthStore has no way to set them either,
//     so the three characteristic readers answer HKErrorNoData and the store's table stays empty
//     until a later release's -updateBiologicalSex: and its neighbours are carried.
//
// The members of iOS 9 and later of this class - the source readers, the per-source ordering, the
// characteristic setters, -deleteObjects:ofType:predicate:withCompletion:, -preferredUnitsForQuantityTypes:
// and -getRequestStatusForAuthorizationToShareTypes:readTypes:completion: - are in the group of their
// own release, and the watchOS-only workout-session methods are unavailable on iOS, as the header
// marks them.

#import <HealthKit/HealthKit.h>

#import "CharonHKStore.h"
#import "../CharonSayOnce.h"

@implementation HKHealthStore {
    NSMutableSet<NSValue *> *_running;
}

+ (BOOL)supportsSecureCoding
{
    return NO;
}

// The release's own answer on a device that has the hardware and runs it, the iPhone 4S and the iPad
// 2, both of which do: YES. The data of this port is the process's own database, so there is no
// store of Apple's that could be unavailable.
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
        if (![[CharonHKStore sharedStore] openWithError:&error])
            charon_hk_say_once(@"health-store-open", [NSString stringWithFormat:@"HealthKit: %@", error.localizedDescription]);
    }
    return self;
}

#pragma mark - Authorization

- (HKAuthorizationStatus)authorizationStatusForType:(HKObjectType *)type
{
    if (![type isKindOfClass:[HKObjectType class]])
        return HKAuthorizationStatusNotDetermined;
    return [[CharonHKStore sharedStore] authorizationStatusForType:type];
}

- (void)requestAuthorizationToShareTypes:(nullable NSSet<HKSampleType *> *)typesToShare
                              readTypes:(nullable NSSet<HKObjectType *> *)typesToRead
                             completion:(void (^)(BOOL success, NSError *_Nullable error))completion
{
    if (!completion)
        return;
    NSError *error = nil;
    BOOL ok = [[CharonHKStore sharedStore] recordAuthorizationToShare:typesToShare read:typesToRead error:&error];
    if (!ok)
        charon_hk_say_once(@"authorization-failed", [NSString stringWithFormat:@"HealthKit: %@", error.localizedDescription]);
    // success says whether the request was recorded, not whether a user granted anything: there was
    // no user to ask. The completion is called on a background queue, as the header says it is.
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
    // Every object is written in one transaction, so a save of several either keeps all of them or
    // none of them, which is what the release promises.
    BOOL ok = [[CharonHKStore sharedStore] saveObjects:objects ?: @[] error:&error];
    [self charon_complete:completion ok:ok error:error];
}

- (void)deleteObject:(HKObject *)object withCompletion:(void (^)(BOOL success, NSError *_Nullable error))completion
{
    [self deleteObjects:object ? @[object] : @[] withCompletion:completion];
}

- (void)charon_complete:(void (^)(BOOL, NSError *))completion ok:(BOOL)ok error:(NSError *)error
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
    if (![query conformsToProtocol:@protocol(CharonHKRunnableQuery)]) {
        [NSException raise:NSInvalidArgumentException
                    format:@"%@ is not a query this store can execute.", NSStringFromClass([query class])];
        return;
    }
    // Each HKQuery instance may only be executed once, and executing one that has been executed is
    // the exception the header says it is.
    if ([(id<CharonHKRunnableQuery>)query charon_hasBeenExecuted]) {
        [NSException raise:NSInvalidArgumentException
                    format:@"Each HKQuery instance may only be executed once, and this one has been executed already."];
        return;
    }
    [(id<CharonHKRunnableQuery>)query charon_setHasBeenExecuted:YES];
    [(id<CharonHKRunnableQuery>)query charon_run];
    @synchronized(_running) {
        [_running addObject:[NSValue valueWithNonretainedObject:query]];
    }
}

- (void)stopQuery:(HKQuery *)query
{
    @synchronized(_running) {
        [_running removeObject:[NSValue valueWithNonretainedObject:query]];
    }
    if ([query conformsToProtocol:@protocol(CharonHKRunnableQuery)])
        [(id<CharonHKRunnableQuery>)query charon_stop];
}

#pragma mark - Background delivery

- (void)enableBackgroundDeliveryForType:(HKObjectType *)type
                              frequency:(HKUpdateFrequency)frequency
                           withCompletion:(void (^)(BOOL success, NSError *_Nullable error))completion
{
    NSError *error = nil;
    BOOL ok = [[CharonHKStore sharedStore] setBackgroundDelivery:YES forType:type frequency:frequency error:&error];
    if (ok)
        charon_hk_say_once(@"background-delivery",
                           @"HealthKit: background delivery is registered and kept, but this release has no health daemon to wake the "
                           @"application for it, so nothing is delivered. A query left running, or an observer query, is the way to be "
                           @"told of a change on this release.");
    [self charon_complete:completion ok:ok error:error];
}

- (void)disableBackgroundDeliveryForType:(HKObjectType *)type withCompletion:(void (^)(BOOL success, NSError *_Nullable error))completion
{
    NSError *error = nil;
    BOOL ok = [[CharonHKStore sharedStore] setBackgroundDelivery:NO forType:type frequency:0 error:&error];
    [self charon_complete:completion ok:ok error:error];
}

- (void)disableAllBackgroundDeliveryWithCompletion:(void (^)(BOOL success, NSError *_Nullable error))completion
{
    NSError *error = nil;
    BOOL ok = [[CharonHKStore sharedStore] disableAllBackgroundDeliveryWithError:&error];
    [self charon_complete:completion ok:ok error:error];
}

#pragma mark - The characteristics of the user

- (nullable NSDate *)dateOfBirthWithError:(NSError *__autoreleasing *)error
{
    NSDate *stored = [[CharonHKStore sharedStore] characteristicForIdentifier:HKCharacteristicTypeIdentifierDateOfBirth];
    if (!stored && error)
        *error = CharonHKError(HKErrorNoData,
                               @"No date of birth is recorded. The user enters it in the Health application on a release that has one, "
                               @"and iOS 8.0's public API of HKHealthStore has no way to write it either.",
                               nil);
    return stored;
}

- (nullable HKBiologicalSexObject *)biologicalSexWithError:(NSError *__autoreleasing *)error
{
    if (![[CharonHKStore sharedStore] mayReadType:[HKObjectType characteristicTypeForIdentifier:HKCharacteristicTypeIdentifierBiologicalSex]]) {
        if (error)
            *error = CharonHKError(HKErrorAuthorizationDenied, @"Reading the biological sex has not been authorized.", nil);
        return nil;
    }
    NSNumber *stored = [[CharonHKStore sharedStore] characteristicForIdentifier:HKCharacteristicTypeIdentifierBiologicalSex];
    if (!stored) {
        if (error)
            *error = CharonHKError(HKErrorNoData,
                                   @"No biological sex is recorded. The user enters it in the Health application on a release that has "
                                   @"one, and iOS 8.0's public API of HKHealthStore has no way to write it either.",
                                   nil);
        return nil;
    }
    return [HKBiologicalSexObject charon_biologicalSexObject:(HKBiologicalSex)stored.integerValue];
}

- (nullable HKBloodTypeObject *)bloodTypeWithError:(NSError *__autoreleasing *)error
{
    if (![[CharonHKStore sharedStore] mayReadType:[HKObjectType characteristicTypeForIdentifier:HKCharacteristicTypeIdentifierBloodType]]) {
        if (error)
            *error = CharonHKError(HKErrorAuthorizationDenied, @"Reading the blood type has not been authorized.", nil);
        return nil;
    }
    NSNumber *stored = [[CharonHKStore sharedStore] characteristicForIdentifier:HKCharacteristicTypeIdentifierBloodType];
    if (!stored) {
        if (error)
            *error = CharonHKError(HKErrorNoData,
                                   @"No blood type is recorded. The user enters it in the Health application on a release that has one, "
                                   @"and iOS 8.0's public API of HKHealthStore has no way to write it either.",
                                   nil);
        return nil;
    }
    return [HKBloodTypeObject charon_bloodTypeObject:(HKBloodType)stored.integerValue];
}

#pragma mark - Workouts

- (void)addSamples:(NSArray<HKSample *> *)samples
         toWorkout:(HKWorkout *)workout
        completion:(void (^)(BOOL success, NSError *_Nullable error))completion
{
    if (![workout isKindOfClass:[HKWorkout class]] || !samples.count) {
        [self charon_complete:completion
                          ok:NO
                       error:CharonHKError(HKErrorInvalidArgument, @"A workout and at least one sample are both needed.", nil)];
        return;
    }
    NSError *error = nil;
    BOOL ok = [[CharonHKStore sharedStore] addSamples:samples toWorkout:workout error:&error];
    [self charon_complete:completion ok:ok error:error];
}

@end
