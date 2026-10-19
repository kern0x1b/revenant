// The iOS 9.0 form of HKAnchoredObjectQuery, and the six members of HKHealthStore of that release.
// Each is a file of its own: one object carries the API of one release.
//
// What arrived in 9.0 is that an anchored query can keep running - the update handler is what it is
// told with, and the results handler's form of the same release reports the deletions as
// HKDeletedObject instances rather than as a count - and, of the store, the two bulk deletes, the
// host's own device, the Fitzpatrick skin type, the extension's authorization, the earliest date a
// sample may have, and the energy split.

#import <HealthKit/HealthKit.h>

#import "CharonHKStore.h"

#pragma mark - HKAnchoredObjectQuery

@implementation HKAnchoredObjectQuery (CharonIOS9)

- (nullable void (^)(HKAnchoredObjectQuery *, NSArray<HKSample *> *_Nullable, NSArray<HKDeletedObject *> *_Nullable,
                      HKQueryAnchor *_Nullable, NSError *_Nullable))updateHandler
{
    return self.charon_updateHandler;
}

- (void)setUpdateHandler:(void (^)(HKAnchoredObjectQuery *, NSArray<HKSample *> *_Nullable,
                                             NSArray<HKDeletedObject *> *_Nullable, HKQueryAnchor *_Nullable,
                                             NSError *_Nullable))updateHandler
{
    // The header forbids changing the property once the query has run, and allows setting it only
    // be set where the query has no limit. Both are what it says.
    if (self.charon_hasBeenExecuted) {
        [NSException raise:NSInvalidArgumentException
                    format:@"The updateHandler of an HKAnchoredObjectQuery may not be modified once the query has been executed."];
        return;
    }
    if (self.charon_limit != HKObjectQueryNoLimit && updateHandler) {
        [NSException raise:NSInvalidArgumentException
                    format:@"An HKAnchoredObjectQuery with a limit of %lu has no updateHandler: a limited query answers once and stops.",
                           (unsigned long)self.charon_limit];
        return;
    }
    self.charon_updateHandler = updateHandler;
}

- (instancetype)initWithType:(HKSampleType *)type
                   predicate:(nullable NSPredicate *)predicate
                      anchor:(nullable HKQueryAnchor *)anchor
                       limit:(NSUInteger)limit
             resultsHandler:(void (^)(HKAnchoredObjectQuery *query, NSArray<HKSample *> *_Nullable sampleObjects,
                                      NSArray<HKDeletedObject *> *_Nullable deletedObjects, HKQueryAnchor *_Nullable newAnchor,
                                      NSError *_Nullable error))handler
{
    HKAnchoredObjectQuery *query = [self initWithType:type
                                            predicate:predicate
                                               anchor:(NSUInteger)(anchor ? anchor.charon_sequence : 0)
                                                limit:limit
                                     completionHandler:nil];
    if (!query)
        return nil;
    [query charon_setResultsHandler:handler];
    // The header says the query stops itself after the results handler when there is no update handler,
    // and keeps running and calling the update handler when there is one. That is the difference
    // between this form and the one of iOS 8.0.
    query.charon_stopsAfterResults = YES;
    return query;
}

@end

#pragma mark - HKHealthStore

@implementation HKHealthStore (CharonIOS9)

- (void)deleteObjects:(NSArray<HKObject *> *)objects withCompletion:(void (^)(BOOL success, NSError *_Nullable error))completion
{
    NSError *error = nil;
    BOOL ok = [[CharonHKStore sharedStore] deleteObjects:objects ?: @[] error:&error];
    [self charon_complete:completion ok:ok error:error];
}

- (void)deleteObjectsOfType:(HKObjectType *)objectType
                  predicate:(NSPredicate *)predicate
               withCompletion:(void (^)(BOOL success, NSUInteger deletedObjectCount, NSError *_Nullable error))completion
{
    NSError *error = nil;
    // A delete of a type the process may not read answers the store's error and removes nothing, and
    // the count is then the number of objects removed, which is none.
    NSUInteger deleted = [[CharonHKStore sharedStore] deleteObjectsOfType:objectType predicate:predicate error:&error];
    if (!completion)
        return;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        completion(!error, deleted, error);
    });
}

// The earliest date a sample may have. The header says that on some platforms only samples whose end
// dates come after the earliestPermittedSampleDate value may be saved or retrieved, and
// it names no date; the release's own value is a fixed date of that release's own. This port's store
// refuses no date at all, so the earliest date it permits is the earliest a date can be, and that is
// what is answered here: distantPast, which no NSDate precedes. A caller that reads it and refuses
// earlier samples itself is refusing samples this port would have kept, which is the one direction in
// which the difference shows.
- (NSDate *)earliestPermittedSampleDate
{
    return [NSDate distantPast];
}

- (nullable HKFitzpatrickSkinTypeObject *)fitzpatrickSkinTypeWithError:(NSError *__autoreleasing *)error
{
    if (![[CharonHKStore sharedStore]
            mayReadType:[HKObjectType characteristicTypeForIdentifier:HKCharacteristicTypeIdentifierFitzpatrickSkinType]]) {
        if (error)
            *error = CharonHKError(HKErrorAuthorizationDenied, @"Reading the Fitzpatrick skin type has not been authorized.", nil);
        return nil;
    }
    NSNumber *stored = [[CharonHKStore sharedStore]
        characteristicForIdentifier:HKCharacteristicTypeIdentifierFitzpatrickSkinType];
    if (!stored) {
        if (error)
            *error = CharonHKError(HKErrorHealthDataUnavailable,
                                   @"No Fitzpatrick skin type is recorded. The user enters it in the Health application on a "
                                   @"release that has one.",
                                   nil);
        return nil;
    }
    return [HKFitzpatrickSkinTypeObject charon_fitzpatrickSkinTypeObject:(HKFitzpatrickSkinType)stored.integerValue];
}

// What an app extension calls to have its parent application put up the authorization sheet. This
// release has no app extensions - they arrived in iOS 8 - so nothing can call this, and the header
// marks the method unavailable to an extension besides.
//
// The method is here, and it records: the request goes through the store's own
// recordAuthorizationToShare:read:error: with the empty sets, which is the record the parent's own
// -requestAuthorizationToShareTypes:readTypes:completion: makes, so that a later read is refused with
// HKErrorAuthorizationDenied and the sentence above is one the store keeps rather than one the log
// tells. The sheet itself - the part a user would answer - is the same seam as everywhere else in
// this library and is not claimed for.
- (void)handleAuthorizationForExtensionWithCompletion:(void (^)(BOOL success, NSError *_Nullable error))completion
{
    if (!completion)
        return;
    NSError *error = nil;
    BOOL ok = [[CharonHKStore sharedStore] recordAuthorizationToShare:[NSSet set] read:[NSSet set] error:&error];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        completion(ok, ok ? nil : error);
    });
}

// The energy split the release stopped supporting in iOS 11. Computing it needs a basal metabolic rate, which
// takes the user's age, sex, body mass and height, and this store has none of them: the user
// enters the three of those it can hold in the Health application, which this release has none of. The
// call is refused with the release's own error rather than answered with a ratio invented here, and
// the log says once why.
- (void)splitTotalEnergy:(HKQuantity *)totalEnergy
               startDate:(NSDate *)startDate
                 endDate:(NSDate *)endDate
          resultsHandler:(void (^)(HKQuantity *_Nullable restingEnergy, HKQuantity *_Nullable activeEnergy,
                                   NSError *_Nullable error))resultsHandler
{
    if (!resultsHandler)
        return;
    charon_hk_say_once(@"split-total-energy",
                       @"HealthKit: -splitTotalEnergy:startDate:endDate:resultsHandler: is refused. The release's own method needs "
                       @"the user's age, biological sex, body mass and height to compute a resting metabolic rate, and this port's "
                       @"store holds none of them.");
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        resultsHandler(nil, nil, CharonHKError(HKErrorHealthDataUnavailable,
                                               @"The user's metrics are not recorded, so a total energy cannot be split into a resting "
                                               @"and an active part.",
                                               nil));
    });
}

@end
