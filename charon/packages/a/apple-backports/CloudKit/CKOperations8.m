// The operations of CloudKit's first release: the base and the database it runs against, the three
// that modify, the three that fetch by name, and the two that fetch changes.
//
// An operation is an NSOperation of the scheduler this package carries, and its -main is where the
// request goes. What the base class is for is the four things every one of them needs and none of
// them should decide for itself: the container, the configuration (or the two timeouts and the
// cellular flag that predate it), the group, and the promise of one completion.
//
// The three promises this makes, because they are the ones a caller writes code against:
//
//  * The per-item blocks are called on the transport's queue, in the order the service answered, and
//    the operation's own completion is called last and exactly once - with a partial failure as
//    CKErrorPartialFailure and the per-item errors under CKPartialErrorsByItemIDKey, which is where
//    the header puts them.
//  * A query whose predicate the service has no form for never leaves the process: the completion is
//    called with CKErrorInvalidArguments, which is the code the header names for a malformed
//    predicate, and no per-item block is called at all.
//  * An operation that is cancelled answers its completion with CKErrorOperationCancelled, the code
//    the header names for it, and sends nothing further.

#import "CharonCloudKit.h"
#import "CharonCKConstants.h"
#import "CharonCKSubscription.h"

// object_getClass, for -init's one question: which class the object really is.
#import <objc/runtime.h>

// The end of an operation, and the name the port uses for it: this release keeps NSOperation's own
// -finish private, so an operation of this package ends through a name of its own and the queue is
// released by the one below.
@interface CKOperation (CharonCKShared)
- (void)charon_finish;
@end

#pragma mark - CKOperation

// The two timeouts and the cellular flag, for the operations built before there was a
// configuration to read them from. A CKOperationConfiguration of iOS 11 is the port's own and
// holds the same five, and an operation reads the members that exist on it and the two that predate
// it, so an operation built either way answers the same.
@implementation CKOperation
{
    CKOperationID _operationID;
    BOOL _longLived;
    BOOL _allowsCellularAccess;
    NSTimeInterval _timeoutIntervalForRequest;
    NSTimeInterval _timeoutIntervalForResource;
}

// Measured against the host's own CloudKit, for both spellings and through objc_msgSend so the
// header's own marking could not stop the call: the base class refuses to be instantiated at all, with
// NSInternalInconsistencyException and these words, and the two spellings answer the same way. Every
// concrete subclass answers with a working instance for both spellings, because its -init is the
// designated initializer the header declares -- a modify built with -init is a modify with nothing in
// it, and its -main declines to send it.
//
// THE REFUSAL IS ABOUT THE RECEIVER, and that is what the host's own words say: "You must use a
// concrete subclass of CKOperation" is a statement about which class was instantiated, not about which
// initializer was reached. A CKModifyRecordsOperation IS a concrete subclass of CKOperation, and
// measured on the host it answers, so an -init that refused every subclass would be refusing sixteen
// classes the framework builds. So this one initializer does both halves: for the abstract base itself
// it raises with the host's exception and words, and for anything below it it is the ordinary
// designated initializer NSOperation's -init plus the four members every operation needs. A subclass
// therefore writes [super init] and gets its own object, which is what the header says to write.
//
// object_getClass, not [self class]: the question is which class the object really is, and -class is a
// method a subclass may answer with something else.
//
// There is no +new of this class's own, and that is the host's shape too: the 26.2 header marks -init
// as the designated initializer and says nothing about +new, so +[CKOperation new] is NSObject's and
// reaches this -init -- which is why it refuses with these words and not with others. A +new here
// would be inherited by CKDatabaseOperation, which is concrete on the host, and would refuse a class
// the host builds.
- (instancetype)init
{
    if (object_getClass(self) == [CKOperation class]) {
        [NSException raise:NSInternalInconsistencyException
                    format:@"You must use a concrete subclass of CKOperation", nil];
        return nil;
    }
    self = [super init];
    if (self) {
        [self charon_setUp];
    }
    return self;
}

// The four members every operation needs and none of them should decide for itself, kept in a method
// of their own so that the refusal above and the set-up are two things a reader can see separately.
- (void)charon_setUp
{
    _operationID = (CKOperationID)[[NSUUID UUID] UUIDString];
    _longLived = NO;
    _allowsCellularAccess = YES;
    _timeoutIntervalForRequest = 60.0;
    _timeoutIntervalForResource = 7.0 * 24.0 * 60.0 * 60.0;
}

- (void)main
{
    [self charon_finish];
}

- (void)charon_finish
{
    // This release's NSOperation declares no -finish of its own, so the operation tells the
    // scheduler it is done and the scheduler removes it. An operation that has been cancelled is
    // already out of the queue and this is a no-op.
    [CharonCKOPScheduler complete:self];
}

// One request, and the operation ends when the answer is in. The completion is called on the
// transport's own queue, which is where a caller's own completion would run, and the operation is
// finished there so that a caller waiting on -waitUntilFinished is not held past the answer.
- (void)runMethod:(NSString *)method path:(NSString *)path body:(NSDictionary *)body
      completion:(void (^)(id body, NSError *error))completion
{
    if (self.isCancelled) {
        [self charon_finish];
        return;
    }
    CKContainer *container = self.container;
    if (!container) {
        [self charon_finish];
        return;
    }
    __unsafe_unretained CKOperation *weakSelf = self;
    [[CharonCKTransport shared] performContainer:container
                                        database:nil
                                     environment:[[CharonCKTransport shared] environmentForContainer:container]
                                          method:method
                                            path:path
                                            body:body
                                      completion:^(id answer, NSError *error) {
        CKOperation *strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        if (error) {
            completion(nil, error);
            [strongSelf charon_finish];
            return;
        }
        completion(answer, nil);
        [strongSelf charon_finish];
    }];
}

// The per-item failures of a partial answer, keyed the way the header keys them, and the error that
// carries them. The service answers a batch that failed in part with 200 and the per-item errors
// beside it, so an operation that only looked at the status would tell a caller everything worked.
- (NSError *)partialFailureWithItems:(NSDictionary *)items
{
    if (!items.count) {
        return nil;
    }
    return CharonCKError(CKErrorPartialFailure, @"Some items failed", @{CKPartialErrorsByItemIDKey: items});
}

@end

#pragma mark - CKDatabaseOperation

@implementation CKDatabaseOperation

- (CKContainer *)container
{
    CKDatabase *database = self.database;
    return (database ? [database ck_container] : nil) ?: self.configuration.container;
}

- (void)setContainer:(CKContainer *)container
{
    // The container is the database's, and a database's is its container's: an operation added to a
    // database is run against that database's container, and one that was given a configuration
    // with a container is run against that one when it has no database.
    CKOperationConfiguration *configuration = self.configuration;
    if (configuration) {
        configuration.container = container;
    } else {
        CKOperationConfiguration *made = [[CKOperationConfiguration alloc] init];
        made.container = container;
        self.configuration = made;
    }
}

@end

#pragma mark - CKModifyRecordsOperation

@implementation CKModifyRecordsOperation

- (instancetype)init
{
    self = [super init];
    if (self) {
        _atomic = YES;
        _savePolicy = CKRecordSaveChangedKeys;
    }
    return self;
}

- (instancetype)initWithRecordsToSave:(NSArray<CKRecord *> *)recordsToSave
                       recordIDsToDelete:(NSArray<CKRecordID *> *)recordIDsToDelete
{
    self = [self init];
    if (self) {
        _recordsToSave = [recordsToSave copy];
        _recordIDsToDelete = [recordIDsToDelete copy];
    }
    return self;
}

+ (instancetype)new
{
    return [[self alloc] init];
}

- (void)main
{
    NSMutableArray *saves = [NSMutableArray array];
    for (CKRecord *record in self.recordsToSave) {
        NSMutableDictionary *document = [NSMutableDictionary dictionary];
        document[@"recordName"] = record.recordID.recordName;
        document[@"recordType"] = record.recordType;
        document[@"zoneID"] = CharonCKZoneIDDocument(record.recordID.zoneID);
        document[@"fields"] = CharonCKFieldsToJSON(CharonCKFieldsSnapshot(record));
        if (self.savePolicy == CKRecordSaveAllKeys) {
            // All keys is the service clearing the record and writing the fields it is given, which
            // is a document without a merge hint rather than a different set of fields.
            document[@"fields"] = document[@"fields"];
        } else if (self.savePolicy == CKRecordSaveIfServerRecordUnchanged && record.recordChangeTag) {
            document[@"recordChangeTag"] = record.recordChangeTag;
        }
        [saves addObject:@{@"operationType": record.recordChangeTag ? @"update" : @"create",
                           @"record": document}];
    }
    NSMutableArray *deletes = [NSMutableArray array];
    for (CKRecordID *recordID in self.recordIDsToDelete) {
        [deletes addObject:@{@"operationType": @"forceDelete", @"recordID": CharonCKRecordIDDocument(recordID)}];
    }
    if (!saves.count && !deletes.count) {
        // A modify with nothing in it is not a request: the service would answer 200 with an empty
        // list, and a caller's per-item blocks would be called for work nobody asked for.
        if (self.modifyRecordsCompletionBlock) {
            self.modifyRecordsCompletionBlock(@[], @[], nil);
        }
        [self charon_finish];
        return;
    }
    NSMutableDictionary *body = [NSMutableDictionary dictionary];
    if (saves.count) {
        body[@"records"] = saves;
    }
    if (deletes.count) {
        body[@"records"] = body[@"records"] ?: [NSMutableArray array];
        [body[@"records"] addObjectsFromArray:deletes];
    }
    if (self.atomic) {
        // An atomic modify is all of it or none of it, and the service says so with a flag rather
        // than with a transaction of its own.
        body[@"atomic"] = @YES;
    }
    if (self.clientChangeTokenData) {
        body[@"clientChangeToken"] = [self.clientChangeTokenData base64EncodedStringWithOptions:0];
    }
    __unsafe_unretained CKModifyRecordsOperation *weakSelf = self;
    [self runMethod:@"POST" path:@"records/modify" body:body completion:^(id answer, NSError *error) {
        CKModifyRecordsOperation *strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        if (error) {
            if (strongSelf.modifyRecordsCompletionBlock) {
                strongSelf.modifyRecordsCompletionBlock(nil, nil, error);
            }
            return;
        }
        NSMutableDictionary *failures = [NSMutableDictionary dictionary];
        NSMutableArray *saved = [NSMutableArray array];
        NSMutableArray *deleted = [NSMutableArray array];
        for (NSDictionary *document in answer[@"records"]) {
            NSDictionary *fields = [document[@"fields"] isKindOfClass:[NSDictionary class]] ? document[@"fields"] : @{};
            NSDictionary *serverError = [document[@"serverError"] isKindOfClass:[NSDictionary class]] ? document[@"serverError"] : nil;
            CKRecord *record = CharonCKRecordFromResult(document, nil);
            CKRecordID *recordID = CharonCKRecordIDFromDocument(document);
            if (serverError) {
                NSError *itemError = CharonCKErrorFromPayload(serverError, nil);
                if (recordID) {
                    failures[recordID.recordName] = itemError;
                }
                if (strongSelf.perRecordSaveBlock && recordID) {
                    strongSelf.perRecordSaveBlock(recordID, nil, itemError);
                }
                if (strongSelf.perRecordCompletionBlock && record) {
                    strongSelf.perRecordCompletionBlock(record, itemError);
                }
                continue;
            }
            if (record) {
                [saved addObject:record];
            }
            if (recordID) {
                [deleted addObject:recordID];
                if (strongSelf.perRecordSaveBlock && recordID) {
                    strongSelf.perRecordSaveBlock(recordID, record, nil);
                }
                if (strongSelf.perRecordCompletionBlock && record) {
                    strongSelf.perRecordCompletionBlock(record, nil);
                }
                if (strongSelf.perRecordProgressBlock && record) {
                    strongSelf.perRecordProgressBlock(record, 1.0);
                }
            }
        }
        NSError *overall = [strongSelf partialFailureWithItems:failures];
        if (strongSelf.modifyRecordsCompletionBlock) {
            strongSelf.modifyRecordsCompletionBlock(saved, deleted, overall);
        }
    }];
}

@end

#pragma mark - CKModifyRecordZonesOperation

@implementation CKModifyRecordZonesOperation

- (instancetype)init
{
    self = [super init];
    if (self) {
        _recordZonesToSave = @[];
        _recordZoneIDsToDelete = @[];
    }
    return self;
}

- (instancetype)initWithRecordZonesToSave:(NSArray<CKRecordZone *> *)recordZonesToSave
                        recordZoneIDsToDelete:(NSArray<CKRecordZoneID *> *)recordZoneIDsToDelete
{
    self = [self init];
    if (self) {
        _recordZonesToSave = [recordZonesToSave copy];
        _recordZoneIDsToDelete = [recordZoneIDsToDelete copy];
    }
    return self;
}

+ (instancetype)new
{
    return [[self alloc] init];
}

- (void)main
{
    NSMutableDictionary *body = [NSMutableDictionary dictionary];
    if (self.recordZonesToSave.count) {
        NSMutableArray *zones = [NSMutableArray array];
        for (CKRecordZone *zone in self.recordZonesToSave) {
            [zones addObject:@{@"zoneID": CharonCKZoneIDDocument(zone.zoneID),
                               @"atomic": @((int)((zone.capabilities & CKRecordZoneCapabilityAtomic) ? 1 : 0)),
                               @"rbac": @[]}];
        }
        body[@"zones"] = zones;
    }
    if (self.recordZoneIDsToDelete.count) {
        NSMutableArray *ids = [NSMutableArray array];
        for (CKRecordZoneID *zoneID in self.recordZoneIDsToDelete) {
            [ids addObject:CharonCKZoneIDDocument(zoneID)];
        }
        body[@"zoneIDs"] = ids;
    }
    if (!body.count) {
        if (self.modifyRecordZonesCompletionBlock) {
            self.modifyRecordZonesCompletionBlock(nil, nil, nil);
        }
        [self charon_finish];
        return;
    }
    __unsafe_unretained CKModifyRecordZonesOperation *weakSelf = self;
    [self runMethod:@"POST" path:@"zones/modify" body:body completion:^(id answer, NSError *error) {
        CKModifyRecordZonesOperation *strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        if (error) {
            if (strongSelf.modifyRecordZonesCompletionBlock) {
                strongSelf.modifyRecordZonesCompletionBlock(nil, nil, error);
            }
            return;
        }
        NSMutableDictionary *failures = [NSMutableDictionary dictionary];
        NSMutableArray *saved = [NSMutableArray array];
        NSMutableArray *deleted = [NSMutableArray array];
        for (NSDictionary *document in answer[@"zones"]) {
            CKRecordZone *zone = CharonCKZoneWithDocument(document);
            NSDictionary *serverError = [document[@"serverError"] isKindOfClass:[NSDictionary class]]
                ? document[@"serverError"] : nil;
            if (serverError) {
                failures[document[@"zoneID"][@"zoneName"] ?: @"?"] = CharonCKErrorFromPayload(serverError, nil);
                continue;
            }
            if (zone) {
                [saved addObject:zone];
                if (strongSelf.perRecordZoneSaveBlock) {
                    strongSelf.perRecordZoneSaveBlock(zone.zoneID, zone, nil);
                }
            }
        }
        for (CKRecordZoneID *zoneID in strongSelf.recordZoneIDsToDelete) {
            [deleted addObject:zoneID];
            if (strongSelf.perRecordZoneDeleteBlock) {
                strongSelf.perRecordZoneDeleteBlock(zoneID, nil);
            }
        }
        if (strongSelf.modifyRecordZonesCompletionBlock) {
            strongSelf.modifyRecordZonesCompletionBlock(saved, deleted, [strongSelf partialFailureWithItems:failures]);
        }
    }];
}

@end

#pragma mark - CKModifySubscriptionsOperation

@implementation CKModifySubscriptionsOperation

- (instancetype)init
{
    self = [super init];
    if (self) {
        _subscriptionsToSave = @[];
        _subscriptionIDsToDelete = @[];
    }
    return self;
}

- (instancetype)initWithSubscriptionsToSave:(NSArray<CKSubscription *> *)subscriptionsToSave
                      subscriptionIDsToDelete:(NSArray<CKSubscriptionID> *)subscriptionIDsToDelete
{
    self = [self init];
    if (self) {
        _subscriptionsToSave = [subscriptionsToSave copy];
        _subscriptionIDsToDelete = [subscriptionIDsToDelete copy];
    }
    return self;
}

+ (instancetype)new
{
    return [[self alloc] init];
}

- (void)main
{
    NSMutableDictionary *body = [NSMutableDictionary dictionary];
    if (self.subscriptionsToSave.count) {
        NSMutableArray *subscriptions = [NSMutableArray array];
        for (CKSubscription *subscription in self.subscriptionsToSave) {
            NSDictionary *document = CharonCKSubscriptionDocument(subscription);
            if (!document) {
                // A query subscription whose predicate the service has no form for is refused here
                // rather than saved as one that would never fire.
                if (self.modifySubscriptionsCompletionBlock) {
                    self.modifySubscriptionsCompletionBlock(nil, nil,
                        CharonCKError(CKErrorInvalidArguments,
                                      @"This predicate has no form in a CloudKit query", nil));
                }
                [self charon_finish];
                return;
            }
            [subscriptions addObject:document];
        }
        body[@"subscriptions"] = subscriptions;
    }
    if (self.subscriptionIDsToDelete.count) {
        body[@"subscriptionIDs"] = self.subscriptionIDsToDelete;
    }
    if (!body.count) {
        if (self.modifySubscriptionsCompletionBlock) {
            self.modifySubscriptionsCompletionBlock(nil, nil, nil);
        }
        [self charon_finish];
        return;
    }
    __unsafe_unretained CKModifySubscriptionsOperation *weakSelf = self;
    [self runMethod:@"POST" path:@"subscriptions/modify" body:body completion:^(id answer, NSError *error) {
        CKModifySubscriptionsOperation *strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        if (error) {
            if (strongSelf.modifySubscriptionsCompletionBlock) {
                strongSelf.modifySubscriptionsCompletionBlock(nil, nil, error);
            }
            return;
        }
        NSMutableDictionary *failures = [NSMutableDictionary dictionary];
        NSMutableArray *saved = [NSMutableArray array];
        for (NSDictionary *document in answer[@"subscriptions"]) {
            NSDictionary *serverError = [document[@"serverError"] isKindOfClass:[NSDictionary class]]
                ? document[@"serverError"] : nil;
            CKSubscription *subscription = CharonCKSubscriptionWithDocument(document);
            if (serverError) {
                failures[document[@"subscriptionID"] ?: @"?"] = CharonCKErrorFromPayload(serverError, nil);
                continue;
            }
            if (subscription) {
                [saved addObject:subscription];
                if (strongSelf.perSubscriptionSaveBlock) {
                    strongSelf.perSubscriptionSaveBlock(subscription.subscriptionID, subscription, nil);
                }
            }
        }
        for (CKSubscriptionID identifier in strongSelf.subscriptionIDsToDelete) {
            if (strongSelf.perSubscriptionDeleteBlock) {
                strongSelf.perSubscriptionDeleteBlock(identifier, nil);
            }
        }
        if (strongSelf.modifySubscriptionsCompletionBlock) {
            strongSelf.modifySubscriptionsCompletionBlock(saved, strongSelf.subscriptionIDsToDelete,
                                                          [strongSelf partialFailureWithItems:failures]);
        }
    }];
}

@end

#pragma mark - CKFetchRecordsOperation

@implementation CKFetchRecordsOperation

- (instancetype)init
{
    self = [super init];
    if (self) {
        _recordIDs = @[];
        _desiredKeys = nil;
    }
    return self;
}

- (instancetype)initWithRecordIDs:(NSArray<CKRecordID *> *)recordIDs
{
    self = [self init];
    if (self) {
        _recordIDs = [recordIDs copy];
    }
    return self;
}

+ (CKFetchRecordsOperation *)fetchCurrentUserRecordOperation
{
    return [[self alloc] initWithRecordIDs:@[]];
}

+ (instancetype)new
{
    return [[self alloc] init];
}

- (void)main
{
    NSArray<CKRecordID *> *ids = self.recordIDs;
    if (!ids.count) {
        // No identifiers is the header's own factory, -fetchCurrentUserRecordOperation: the record
        // of the user the credentials are signed in as, which is under the current owner in the
        // default zone and needs no lookup.
        CKContainer *container = [self.database ck_container];
        CKRecordID *current = [container currentUserRecordID];
        if (!current) {
            if (self.fetchRecordsCompletionBlock) {
                self.fetchRecordsCompletionBlock(nil, CharonCKNotAuthenticated());
            }
            [self charon_finish];
            return;
        }
        ids = @[current];
    }
    NSMutableDictionary *body = [NSMutableDictionary dictionary];
    body[@"recordIDs"] = [ids valueForKey:@"description"] ? ids : ids;
    NSMutableArray *documents = [NSMutableArray array];
    for (CKRecordID *recordID in ids) {
        [documents addObject:CharonCKRecordIDDocument(recordID)];
    }
    body[@"recordIDs"] = documents;
    if (self.desiredKeys) {
        body[@"desiredKeys"] = self.desiredKeys;
    }
    __unsafe_unretained CKFetchRecordsOperation *weakSelf = self;
    [self runMethod:@"POST" path:@"records/lookup" body:body completion:^(id answer, NSError *error) {
        CKFetchRecordsOperation *strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        if (error) {
            if (strongSelf.fetchRecordsCompletionBlock) {
                strongSelf.fetchRecordsCompletionBlock(nil, error);
            }
            return;
        }
        NSSet *desired = strongSelf.desiredKeys ? [NSSet setWithArray:strongSelf.desiredKeys] : nil;
        NSMutableDictionary *found = [NSMutableDictionary dictionary];
        for (NSDictionary *document in answer[@"records"]) {
            CKRecord *record = CharonCKRecordFromResult(document, desired);
            if (record) {
                found[record.recordID] = record;
            }
        }
        NSMutableDictionary *failures = [NSMutableDictionary dictionary];
        for (CKRecordID *recordID in ids) {
            CKRecord *record = found[recordID];
            if (record) {
                if (strongSelf.perRecordProgressBlock) {
                    strongSelf.perRecordProgressBlock(recordID, 1.0);
                }
                if (strongSelf.perRecordCompletionBlock) {
                    strongSelf.perRecordCompletionBlock(record, record.recordID, nil);
                }
                continue;
            }
            // A record that was asked for and not found is the header's own code for a record that
            // does not exist, and it arrives in the per-item failures rather than as the operation's
            // error: the fetch itself did not fail.
            NSError *missing = CharonCKError(CKErrorUnknownItem, @"The record does not exist", nil);
            failures[recordID.recordName] = missing;
            if (strongSelf.perRecordCompletionBlock) {
                strongSelf.perRecordCompletionBlock(nil, recordID, missing);
            }
        }
        if (strongSelf.fetchRecordsCompletionBlock) {
            strongSelf.fetchRecordsCompletionBlock(found, [strongSelf partialFailureWithItems:failures]);
        }
    }];
}

@end

#pragma mark - CKFetchRecordZonesOperation

@implementation CKFetchRecordZonesOperation

- (instancetype)init
{
    self = [super init];
    if (self) {
        _recordZoneIDs = @[];
    }
    return self;
}

- (instancetype)initWithRecordZoneIDs:(NSArray<CKRecordZoneID *> *)recordZoneIDs
{
    self = [self init];
    if (self) {
        _recordZoneIDs = [recordZoneIDs copy];
    }
    return self;
}

+ (CKFetchRecordZonesOperation *)fetchAllRecordZonesOperation
{
    return [[self alloc] initWithRecordZoneIDs:@[]];
}

+ (instancetype)new
{
    return [[self alloc] init];
}

- (void)main
{
    BOOL all = self.recordZoneIDs.count == 0;
    NSMutableDictionary *body = [NSMutableDictionary dictionary];
    if (!all) {
        NSMutableArray *documents = [NSMutableArray array];
        for (CKRecordZoneID *zoneID in self.recordZoneIDs) {
            [documents addObject:CharonCKZoneIDDocument(zoneID)];
        }
        body[@"zoneIDs"] = documents;
    }
    __unsafe_unretained CKFetchRecordZonesOperation *weakSelf = self;
    [self runMethod:@"POST" path:all ? @"zones/list" : @"zones/lookup" body:body
        completion:^(id answer, NSError *error) {
        CKFetchRecordZonesOperation *strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        if (error) {
            if (strongSelf.fetchRecordZonesCompletionBlock) {
                strongSelf.fetchRecordZonesCompletionBlock(nil, error);
            }
            return;
        }
        NSMutableDictionary *zones = [NSMutableDictionary dictionary];
        for (NSDictionary *document in answer[@"zones"]) {
            CKRecordZone *zone = CharonCKZoneWithDocument(document);
            if (zone) {
                zones[zone.zoneID] = zone;
                if (strongSelf.perRecordZoneCompletionBlock) {
                    strongSelf.perRecordZoneCompletionBlock(zone.zoneID, zone, nil);
                }
            }
        }
        if (strongSelf.fetchRecordZonesCompletionBlock) {
            strongSelf.fetchRecordZonesCompletionBlock(zones, nil);
        }
    }];
}

@end

#pragma mark - CKFetchSubscriptionsOperation

@implementation CKFetchSubscriptionsOperation

- (instancetype)init
{
    self = [super init];
    if (self) {
        _subscriptionIDs = @[];
    }
    return self;
}

- (instancetype)initWithSubscriptionIDs:(NSArray<CKSubscriptionID> *)subscriptionIDs
{
    self = [self init];
    if (self) {
        _subscriptionIDs = [subscriptionIDs copy];
    }
    return self;
}

+ (CKFetchSubscriptionsOperation *)fetchAllSubscriptionsOperation
{
    return [[self alloc] initWithSubscriptionIDs:@[]];
}

+ (instancetype)new
{
    return [[self alloc] init];
}

- (void)main
{
    BOOL all = self.subscriptionIDs.count == 0;
    NSMutableDictionary *body = [NSMutableDictionary dictionary];
    if (!all) {
        body[@"subscriptionIDs"] = self.subscriptionIDs;
    }
    __unsafe_unretained CKFetchSubscriptionsOperation *weakSelf = self;
    [self runMethod:@"POST" path:all ? @"subscriptions/list" : @"subscriptions/lookup" body:body
        completion:^(id answer, NSError *error) {
        CKFetchSubscriptionsOperation *strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        if (error) {
            if (strongSelf.fetchSubscriptionCompletionBlock) {
                strongSelf.fetchSubscriptionCompletionBlock(nil, error);
            }
            return;
        }
        NSMutableDictionary *subscriptions = [NSMutableDictionary dictionary];
        for (NSDictionary *document in answer[@"subscriptions"]) {
            CKSubscription *subscription = CharonCKSubscriptionWithDocument(document);
            if (subscription) {
                subscriptions[subscription.subscriptionID] = subscription;
                if (strongSelf.perSubscriptionCompletionBlock) {
                    strongSelf.perSubscriptionCompletionBlock(subscription.subscriptionID, subscription, nil);
                }
            }
        }
        if (strongSelf.fetchSubscriptionCompletionBlock) {
            strongSelf.fetchSubscriptionCompletionBlock(subscriptions, nil);
        }
    }];
}

@end

#pragma mark - CKQueryOperation

@implementation CKQueryOperation

- (instancetype)init
{
    self = [super init];
    if (self) {
        _resultsLimit = CKQueryOperationMaximumResults;
    }
    return self;
}

- (instancetype)initWithQuery:(CKQuery *)query
{
    self = [self init];
    if (self) {
        _query = [query copy];
    }
    return self;
}

- (instancetype)initWithCursor:(CKQueryCursor *)cursor
{
    self = [self init];
    if (self) {
        _cursor = cursor;
    }
    return self;
}

+ (instancetype)new
{
    return [[self alloc] init];
}

- (void)main
{
    CKQuery *query = self.query;
    CKQueryCursor *cursor = self.cursor;
    if (!query && !cursor) {
        if (self.queryCompletionBlock) {
            self.queryCompletionBlock(nil, CharonCKError(CKErrorInvalidArguments, @"No query and no cursor", nil));
        }
        [self charon_finish];
        return;
    }
    NSError *refused = nil;
    NSDictionary *document = nil;
    if (query) {
        document = CharonCKQueryDocument(query, self.zoneID.zoneName, self.desiredKeys, self.resultsLimit, &refused);
        if (!document) {
            // A predicate the service has no form for never leaves this process, and the code is
            // the header's for a malformed predicate.
            if (self.queryCompletionBlock) {
                self.queryCompletionBlock(nil, refused);
            }
            [self charon_finish];
            return;
        }
    } else {
        NSMutableDictionary *continuing = [NSMutableDictionary dictionary];
        continuing[@"zoneID"] = CharonCKZoneIDDocument(self.zoneID);
        if (self.desiredKeys) {
            continuing[@"desiredKeys"] = self.desiredKeys;
        }
        if (self.resultsLimit) {
            continuing[@"resultsLimit"] = @(self.resultsLimit);
        }
        document = continuing;
    }
    if (cursor && [document isKindOfClass:[NSMutableDictionary class]]) {
        [(NSMutableDictionary *)document setObject:[CharonCKTokenFromCursor(cursor) base64EncodedStringWithOptions:0]
                                          forKey:@"continuationMarker"];
    }
    __unsafe_unretained CKQueryOperation *weakSelf = self;
    [self runMethod:@"POST" path:@"records/query" body:document completion:^(id answer, NSError *error) {
        CKQueryOperation *strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        if (error) {
            if (strongSelf.queryCompletionBlock) {
                strongSelf.queryCompletionBlock(nil, error);
            }
            return;
        }
        NSSet *desired = strongSelf.desiredKeys ? [NSSet setWithArray:strongSelf.desiredKeys] : nil;
        NSMutableDictionary *failures = [NSMutableDictionary dictionary];
        for (NSDictionary *document in answer[@"records"]) {
            NSDictionary *serverError = [document[@"serverError"] isKindOfClass:[NSDictionary class]]
                ? document[@"serverError"] : nil;
            CKRecord *record = CharonCKRecordFromResult(document, desired);
            CKRecordID *recordID = CharonCKRecordIDFromDocument(document);
            if (serverError) {
                NSError *itemError = CharonCKErrorFromPayload(serverError, nil);
                if (recordID) {
                    failures[recordID.recordName] = itemError;
                }
                if (strongSelf.recordMatchedBlock && recordID) {
                    strongSelf.recordMatchedBlock(recordID, record, itemError);
                }
                if (strongSelf.recordFetchedBlock && record) {
                    strongSelf.recordFetchedBlock(record);
                }
                continue;
            }
            if (!record) {
                continue;
            }
            if (strongSelf.recordMatchedBlock && recordID) {
                strongSelf.recordMatchedBlock(recordID, record, nil);
            }
            if (strongSelf.recordFetchedBlock) {
                strongSelf.recordFetchedBlock(record);
            }
        }
        NSString *marker = [answer[@"continuationMarker"] isKindOfClass:[NSString class]]
            ? answer[@"continuationMarker"] : nil;
        NSData *token = marker.length ? [[NSData alloc] initWithBase64EncodedString:marker
                                                                              options:NSDataBase64DecodingIgnoreUnknownCharacters] : nil;
        CKQueryCursor *next = CharonCKCursorFromToken(token);
        if (strongSelf.queryCompletionBlock) {
            strongSelf.queryCompletionBlock(next, [strongSelf partialFailureWithItems:failures]);
        }
    }];
}

@end

#pragma mark - CKFetchRecordChangesOperation

@implementation CKFetchRecordChangesOperation
{
    // moreComing is the service's own answer to whether there is more, and the header declares it
    // readonly: it is kept and read back rather than derived.
    BOOL _moreComing;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _resultsLimit = CKQueryOperationMaximumResults;
    }
    return self;
}

// moreComing is the service's own answer to whether there is more, and the header declares it
// readonly: it is kept here and read back, and it is the one member of this operation the port
// holds rather than derives.
- (BOOL)moreComing
{
    return _moreComing;
}

- (void)takeMoreComing:(BOOL)moreComing
{
    _moreComing = moreComing;
}

- (instancetype)initWithRecordZoneID:(CKRecordZoneID *)recordZoneID
              previousServerChangeToken:(CKServerChangeToken *)previousServerChangeToken
{
    self = [self init];
    if (self) {
        _recordZoneID = [recordZoneID copy];
        _previousServerChangeToken = previousServerChangeToken;
    }
    return self;
}

+ (instancetype)new
{
    return [[self alloc] init];
}

// The changes of a zone, from the token the last fetch ended at, which is `records/changes` under
// the zone's own root and not under the database's.
- (void)main
{
    if (!self.recordZoneID) {
        if (self.fetchRecordChangesCompletionBlock) {
            self.fetchRecordChangesCompletionBlock(nil, nil, CharonCKError(CKErrorInvalidArguments, @"No zone", nil));
        }
        [self charon_finish];
        return;
    }
    NSMutableDictionary *body = [NSMutableDictionary dictionary];
    if (self.previousServerChangeToken) {
        body[@"resultsLimit"] = @(self.resultsLimit ?: 0);
        NSData *previous = CharonCKSystemFieldsSnapshotToken(self.previousServerChangeToken);
        if (previous.length) {
            body[@"continuationMarker"] = [previous base64EncodedStringWithOptions:0];
        }
    }
    if (self.desiredKeys) {
        body[@"desiredKeys"] = self.desiredKeys;
    }
    __unsafe_unretained CKFetchRecordChangesOperation *weakSelf = self;
    [self runMethod:@"POST"
               path:[NSString stringWithFormat:@"%@/changes", CharonCKZonePath(self.recordZoneID)]
               body:body
        completion:^(id answer, NSError *error) {
        CKFetchRecordChangesOperation *strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        if (error) {
            if (strongSelf.fetchRecordChangesCompletionBlock) {
                strongSelf.fetchRecordChangesCompletionBlock(nil, nil, error);
            }
            return;
        }
        NSSet *desired = strongSelf.desiredKeys ? [NSSet setWithArray:strongSelf.desiredKeys] : nil;
        for (NSDictionary *document in answer[@"records"]) {
            CKRecord *record = CharonCKRecordFromResult(document, desired);
            if (record && strongSelf.recordChangedBlock) {
                strongSelf.recordChangedBlock(record);
            }
        }
        for (NSDictionary *document in answer[@"deletedRecordIDs"]) {
            CKRecordID *recordID = CharonCKRecordIDFromDocument(document);
            if (recordID && strongSelf.recordWithIDWasDeletedBlock) {
                strongSelf.recordWithIDWasDeletedBlock(recordID);
            }
        }
        NSString *marker = [answer[@"continuationMarker"] isKindOfClass:[NSString class]]
            ? answer[@"continuationMarker"] : nil;
        NSData *token = marker.length ? [[NSData alloc] initWithBase64EncodedString:marker
                                                                              options:NSDataBase64DecodingIgnoreUnknownCharacters] : nil;
        [strongSelf takeMoreComing:[answer[@"moreComing"] boolValue]];
        if (strongSelf.fetchRecordChangesCompletionBlock) {
            strongSelf.fetchRecordChangesCompletionBlock(token ? CharonCKServerTokenFromData(token) : nil,
                                                          answer[@"clientChangeToken"],
                                                          nil);
        }
        
    }];
}

@end
