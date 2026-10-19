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
    NSUInteger deleted = [[CharonHKStore sharedStore] deleteObjectsOfType:objectType predicate:predicate error:&error];
    if (!completion)
        return;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        completion(!error, deleted, error);
    });
}

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
