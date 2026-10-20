#import "RevenantCloudKit.h"
#import "RevenantCKConstants.h"
#import "RevenantCKSubscription.h"

#import <objc/runtime.h>

@interface CKOperation (RevenantCKShared)
- (void)revenant_finish;
@end

#pragma mark - CKOperation

@implementation CKOperation
{
    CKOperationID _operationID;
    BOOL _longLived;
    BOOL _allowsCellularAccess;
    NSTimeInterval _timeoutIntervalForRequest;
    NSTimeInterval _timeoutIntervalForResource;
}

- (instancetype)init
{
    if (object_getClass(self) == [CKOperation class]) {
        [NSException raise:NSInternalInconsistencyException
                    format:@"You must use a concrete subclass of CKOperation", nil];
        return nil;
    }
    self = [super init];
    if (self) {
        [self revenant_setUp];
    }
    return self;
}

- (void)revenant_setUp
{
    _operationID = (CKOperationID)[[NSUUID UUID] UUIDString];
    _longLived = NO;
    _allowsCellularAccess = YES;
    _timeoutIntervalForRequest = 60.0;
    _timeoutIntervalForResource = 7.0 * 24.0 * 60.0 * 60.0;
}

- (void)main
{
    [self revenant_finish];
}

- (void)revenant_finish
{
    [RevenantCKOPScheduler complete:self];
}

- (void)runMethod:(NSString *)method path:(NSString *)path body:(NSDictionary *)body
      completion:(void (^)(id body, NSError *error))completion
{
    if (self.isCancelled) {
        [self revenant_finish];
        return;
    }
    CKContainer *container = self.container;
    if (!container) {
        [self revenant_finish];
        return;
    }
    __unsafe_unretained CKOperation *weakSelf = self;
    [[RevenantCKTransport shared] performContainer:container
                                        database:nil
                                     environment:[[RevenantCKTransport shared] environmentForContainer:container]
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
            [strongSelf revenant_finish];
            return;
        }
        completion(answer, nil);
        [strongSelf revenant_finish];
    }];
}

- (NSError *)partialFailureWithItems:(NSDictionary *)items
{
    if (!items.count) {
        return nil;
    }
    return RevenantCKError(CKErrorPartialFailure, @"Some items failed", @{CKPartialErrorsByItemIDKey: items});
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
        document[@"zoneID"] = RevenantCKZoneIDDocument(record.recordID.zoneID);
        document[@"fields"] = RevenantCKFieldsToJSON(RevenantCKFieldsSnapshot(record));
        if (self.savePolicy == CKRecordSaveAllKeys) {
            document[@"fields"] = document[@"fields"];
        } else if (self.savePolicy == CKRecordSaveIfServerRecordUnchanged && record.recordChangeTag) {
            document[@"recordChangeTag"] = record.recordChangeTag;
        }
        [saves addObject:@{@"operationType": record.recordChangeTag ? @"update" : @"create",
                           @"record": document}];
    }
    NSMutableArray *deletes = [NSMutableArray array];
    for (CKRecordID *recordID in self.recordIDsToDelete) {
        [deletes addObject:@{@"operationType": @"forceDelete", @"recordID": RevenantCKRecordIDDocument(recordID)}];
    }
    if (!saves.count && !deletes.count) {
        if (self.modifyRecordsCompletionBlock) {
            self.modifyRecordsCompletionBlock(@[], @[], nil);
        }
        [self revenant_finish];
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
            CKRecord *record = RevenantCKRecordFromResult(document, nil);
            CKRecordID *recordID = RevenantCKRecordIDFromDocument(document);
            if (serverError) {
                NSError *itemError = RevenantCKErrorFromPayload(serverError, nil);
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
            [zones addObject:@{@"zoneID": RevenantCKZoneIDDocument(zone.zoneID),
                               @"atomic": @((int)((zone.capabilities & CKRecordZoneCapabilityAtomic) ? 1 : 0)),
                               @"rbac": @[]}];
        }
        body[@"zones"] = zones;
    }
    if (self.recordZoneIDsToDelete.count) {
        NSMutableArray *ids = [NSMutableArray array];
        for (CKRecordZoneID *zoneID in self.recordZoneIDsToDelete) {
            [ids addObject:RevenantCKZoneIDDocument(zoneID)];
        }
        body[@"zoneIDs"] = ids;
    }
    if (!body.count) {
        if (self.modifyRecordZonesCompletionBlock) {
            self.modifyRecordZonesCompletionBlock(nil, nil, nil);
        }
        [self revenant_finish];
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
            CKRecordZone *zone = RevenantCKZoneWithDocument(document);
            NSDictionary *serverError = [document[@"serverError"] isKindOfClass:[NSDictionary class]]
                ? document[@"serverError"] : nil;
            if (serverError) {
                failures[document[@"zoneID"][@"zoneName"] ?: @"?"] = RevenantCKErrorFromPayload(serverError, nil);
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
            NSDictionary *document = RevenantCKSubscriptionDocument(subscription);
            if (!document) {
                if (self.modifySubscriptionsCompletionBlock) {
                    self.modifySubscriptionsCompletionBlock(nil, nil,
                        RevenantCKError(CKErrorInvalidArguments,
                                      @"This predicate has no form in a CloudKit query", nil));
                }
                [self revenant_finish];
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
        [self revenant_finish];
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
            CKSubscription *subscription = RevenantCKSubscriptionWithDocument(document);
            if (serverError) {
                failures[document[@"subscriptionID"] ?: @"?"] = RevenantCKErrorFromPayload(serverError, nil);
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
        CKContainer *container = [self.database ck_container];
        CKRecordID *current = [container currentUserRecordID];
        if (!current) {
            if (self.fetchRecordsCompletionBlock) {
                self.fetchRecordsCompletionBlock(nil, RevenantCKNotAuthenticated());
            }
            [self revenant_finish];
            return;
        }
        ids = @[current];
    }
    NSMutableDictionary *body = [NSMutableDictionary dictionary];
    body[@"recordIDs"] = [ids valueForKey:@"description"] ? ids : ids;
    NSMutableArray *documents = [NSMutableArray array];
    for (CKRecordID *recordID in ids) {
        [documents addObject:RevenantCKRecordIDDocument(recordID)];
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
            CKRecord *record = RevenantCKRecordFromResult(document, desired);
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
            NSError *missing = RevenantCKError(CKErrorUnknownItem, @"The record does not exist", nil);
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
            [documents addObject:RevenantCKZoneIDDocument(zoneID)];
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
            CKRecordZone *zone = RevenantCKZoneWithDocument(document);
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
            CKSubscription *subscription = RevenantCKSubscriptionWithDocument(document);
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
            self.queryCompletionBlock(nil, RevenantCKError(CKErrorInvalidArguments, @"No query and no cursor", nil));
        }
        [self revenant_finish];
        return;
    }
    NSError *refused = nil;
    NSDictionary *document = nil;
    if (query) {
        document = RevenantCKQueryDocument(query, self.zoneID.zoneName, self.desiredKeys, self.resultsLimit, &refused);
        if (!document) {
            if (self.queryCompletionBlock) {
                self.queryCompletionBlock(nil, refused);
            }
            [self revenant_finish];
            return;
        }
    } else {
        NSMutableDictionary *continuing = [NSMutableDictionary dictionary];
        continuing[@"zoneID"] = RevenantCKZoneIDDocument(self.zoneID);
        if (self.desiredKeys) {
            continuing[@"desiredKeys"] = self.desiredKeys;
        }
        if (self.resultsLimit) {
            continuing[@"resultsLimit"] = @(self.resultsLimit);
        }
        document = continuing;
    }
    if (cursor && [document isKindOfClass:[NSMutableDictionary class]]) {
        [(NSMutableDictionary *)document setObject:[RevenantCKTokenFromCursor(cursor) base64EncodedStringWithOptions:0]
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
            CKRecord *record = RevenantCKRecordFromResult(document, desired);
            CKRecordID *recordID = RevenantCKRecordIDFromDocument(document);
            if (serverError) {
                NSError *itemError = RevenantCKErrorFromPayload(serverError, nil);
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
        CKQueryCursor *next = RevenantCKCursorFromToken(token);
        if (strongSelf.queryCompletionBlock) {
            strongSelf.queryCompletionBlock(next, [strongSelf partialFailureWithItems:failures]);
        }
    }];
}

@end

#pragma mark - CKFetchRecordChangesOperation

@implementation CKFetchRecordChangesOperation
{
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

- (void)main
{
    if (!self.recordZoneID) {
        if (self.fetchRecordChangesCompletionBlock) {
            self.fetchRecordChangesCompletionBlock(nil, nil, RevenantCKError(CKErrorInvalidArguments, @"No zone", nil));
        }
        [self revenant_finish];
        return;
    }
    NSMutableDictionary *body = [NSMutableDictionary dictionary];
    if (self.previousServerChangeToken) {
        body[@"resultsLimit"] = @(self.resultsLimit ?: 0);
        NSData *previous = RevenantCKSystemFieldsSnapshotToken(self.previousServerChangeToken);
        if (previous.length) {
            body[@"continuationMarker"] = [previous base64EncodedStringWithOptions:0];
        }
    }
    if (self.desiredKeys) {
        body[@"desiredKeys"] = self.desiredKeys;
    }
    __unsafe_unretained CKFetchRecordChangesOperation *weakSelf = self;
    [self runMethod:@"POST"
               path:[NSString stringWithFormat:@"%@/changes", RevenantCKZonePath(self.recordZoneID)]
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
            CKRecord *record = RevenantCKRecordFromResult(document, desired);
            if (record && strongSelf.recordChangedBlock) {
                strongSelf.recordChangedBlock(record);
            }
        }
        for (NSDictionary *document in answer[@"deletedRecordIDs"]) {
            CKRecordID *recordID = RevenantCKRecordIDFromDocument(document);
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
            strongSelf.fetchRecordChangesCompletionBlock(token ? RevenantCKServerTokenFromData(token) : nil,
                                                          answer[@"clientChangeToken"],
                                                          nil);
        }
        
    }];
}

@end
