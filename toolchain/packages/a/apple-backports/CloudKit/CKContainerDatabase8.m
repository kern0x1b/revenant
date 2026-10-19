#import "RevenantCloudKit.h"
#import "RevenantCKConstants.h"
#import "RevenantCKSubscription.h"

@interface CKDatabase ()
@property (nonatomic, strong) CKContainer *ck_container;
@end

@implementation CKDatabase

@synthesize ck_container = _ck_container;

- (instancetype)initWithContainer:(CKContainer *)container scope:(CKDatabaseScope)scope
{
    self = [super init];
    if (self) {
        _ck_container = container;
        _databaseScope = scope;
    }
    return self;
}

@end

#pragma mark - CKContainer

@implementation CKContainer
{
    NSMutableDictionary *_databases;
}

- (instancetype)initWithIdentifier:(NSString *)identifier
{
    self = [super init];
    if (self) {
        _containerIdentifier = [identifier copy];
        _databases = [NSMutableDictionary dictionary];
    }
    return self;
}

+ (CKContainer *)defaultContainer
{
    NSString *identifier = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CKContainerIdentifier"];
    if (![identifier isKindOfClass:[NSString class]] || !identifier.length) {
        identifier = [[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CloudKitContainerIdentifier"] copy];
    }
    return [[self alloc] initWithIdentifier:identifier];
}

+ (CKContainer *)containerWithIdentifier:(NSString *)containerIdentifier
{
    return [[self alloc] initWithIdentifier:containerIdentifier];
}

+ (instancetype)new
{
    return [self defaultContainer];
}

- (CKDatabase *)databaseWithScope:(CKDatabaseScope)scope
{
    NSNumber *key = @(scope);
    CKDatabase *database = _databases[key];
    if (database) {
        return database;
    }
    database = [[CKDatabase alloc] initWithContainer:self scope:scope];
    _databases[key] = database;
    NSString *environment = [[RevenantCKTransport shared] environmentForContainer:self];
    [[RevenantCKTransport shared] setContainer:self forDatabase:database environment:environment];
    return database;
}

- (CKDatabase *)privateCloudDatabase
{
    return [self databaseWithScope:CKDatabaseScopePrivate];
}

- (CKDatabase *)publicCloudDatabase
{
    return [self databaseWithScope:CKDatabaseScopePublic];
}

- (CKDatabase *)sharedCloudDatabase
{
    return [self databaseWithScope:CKDatabaseScopeShared];
}

- (CKDatabase *)databaseWithDatabaseScope:(CKDatabaseScope)databaseScope
{
    return [self databaseWithScope:databaseScope];
}

- (void)addOperation:(CKOperation *)operation
{
    [RevenantCKOPScheduler add:operation];
}

- (NSString *)environment
{
    return [[RevenantCKTransport shared] environmentForContainer:self];
}

- (CKRecordID *)currentUserRecordID
{
    NSString *name = [[RevenantCKCredentials shared] userRecordIDForContainer:self.containerIdentifier];
    if (!name.length) {
        name = CKOwnerDefaultName;
    }
    return [[CKRecordID alloc] initWithRecordName:name
                                          zoneID:[[CKRecordZoneID alloc] initWithZoneName:CKRecordZoneDefaultName
                                                                                    ownerName:CKOwnerDefaultName]];
}

#pragma mark The account

- (void)accountStatusWithCompletionHandler:(void (^)(CKAccountStatus accountStatus, NSError *error))completionHandler
{
    CKAccountStatus status = CKAccountStatusNoAccount;
    if (!self.containerIdentifier.length) {
        completionHandler(status, RevenantCKBadContainer(nil));
        return;
    }
    completionHandler(status, nil);
}

- (void)fetchUserRecordIDWithCompletionHandler:(void (^)(CKRecordID *recordID, NSError *error))completionHandler
{
    NSString *name = [[RevenantCKCredentials shared] userRecordIDForContainer:self.containerIdentifier];
    if (!name.length) {
        name = CKOwnerDefaultName;
    }
    completionHandler([[CKRecordID alloc] initWithRecordName:name
                                                     zoneID:[[CKRecordZoneID alloc] initWithZoneName:CKRecordZoneDefaultName
                                                                                               ownerName:CKOwnerDefaultName]], nil);
}

- (void)statusForApplicationPermission:(CKApplicationPermissions)applicationPermission
                    completionHandler:(void (^)(CKApplicationPermissionStatus status, NSError *error))completionHandler
{
    completionHandler(CKApplicationPermissionStatusInitialState, nil);
}

- (void)requestApplicationPermission:(CKApplicationPermissions)applicationPermission
                    completionHandler:(void (^)(CKApplicationPermissionStatus status, NSError *error))completionHandler
{
    if (!self.containerIdentifier.length) {
        completionHandler(CKApplicationPermissionStatusInitialState, RevenantCKBadContainer(nil));
        return;
    }
    completionHandler(CKApplicationPermissionStatusCouldNotComplete, RevenantCKNotAuthenticated());
}

@end

#pragma mark - CKDatabase

@interface CKDatabase (RevenantCKPrivate)
- (nullable CKContainer *)ck_container;
@end

@implementation CKDatabase (RevenantCKRequests)

+ (instancetype)new
{
    [NSException raise:NSInternalInconsistencyException
                format:@"Use +[CKContainer privateCloudDatabase] or +[CKContainer publicCloudDatabase] instead of creating your own",
                nil];
    return nil;
}

- (instancetype)init
{
    [NSException raise:NSInternalInconsistencyException
                format:@"Use +[CKContainer privateCloudDatabase] or +[CKContainer publicCloudDatabase] instead of creating your own",
                nil];
    return nil;
}

- (void)addOperation:(CKDatabaseOperation *)operation
{
    operation.database = self;
    [RevenantCKOPScheduler add:operation];
}

- (void)perform:(NSString *)method path:(NSString *)path body:(NSDictionary *)body
     completion:(void (^)(id body, NSError *error))completion
{
    RevenantCKTransport *transport = [RevenantCKTransport shared];
    NSString *root = [transport databaseRootForContainer:self.ck_container.containerIdentifier
                                                database:self
                                             environment:[transport environmentForContainer:self.ck_container]];
    [[RevenantCKTransport shared] performContainer:self.ck_container
                                        database:self
                                     environment:[transport environmentForContainer:self.ck_container]
                                          method:method
                                            path:[NSString stringWithFormat:@"%@/%@", root, path]
                                            body:body
                                      completion:completion];
}

- (void)fetchRecordWithID:(CKRecordID *)recordID
       completionHandler:(void (^)(CKRecord *record, NSError *error))completionHandler
{
    [self perform:@"POST" path:@"records/lookup" body:@{@"recordIDs": @[RevenantCKRecordIDDocument(recordID)]}
       completion:^(id body, NSError *error) {
        if (error) {
            completionHandler(nil, error);
            return;
        }
        NSArray *records = [body[@"records"] isKindOfClass:[NSArray class]] ? body[@"records"] : nil;
        CKRecord *record = records.count ? RevenantCKRecordFromResult(records[0], nil) : nil;
        completionHandler(record, record ? nil : RevenantCKError(CKErrorUnknownItem, @"The record does not exist", nil));
    }];
}

- (void)saveRecord:(CKRecord *)record
 completionHandler:(void (^)(CKRecord *record, NSError *error))completionHandler
{
    NSMutableDictionary *document = [NSMutableDictionary dictionary];
    document[@"recordName"] = record.recordID.recordName;
    document[@"recordType"] = record.recordType;
    document[@"zoneID"] = RevenantCKZoneIDDocument(record.recordID.zoneID);
    document[@"fields"] = RevenantCKFieldsToJSON(RevenantCKFieldsSnapshot(record));
    NSDictionary *system = RevenantCKSystemFieldsSnapshot(record);
    if (system[@"recordChangeTag"]) {
        [document addEntriesFromDictionary:system];
    }
    NSString *operationType = record.recordChangeTag ? @"update" : @"create";
    [self perform:@"POST" path:@"records/modify"
            body:@{@"records": @[@{@"operationType": operationType, @"record": document}]}
       completion:^(id body, NSError *error) {
        if (error) {
            completionHandler(nil, error);
            return;
        }
        NSArray *records = [body[@"records"] isKindOfClass:[NSArray class]] ? body[@"records"] : nil;
        CKRecord *saved = records.count ? RevenantCKRecordFromResult(records[0], nil) : nil;
        completionHandler(saved, saved ? nil : RevenantCKError(CKErrorInternalError, @"The save answered nothing", nil));
    }];
}

- (void)deleteRecordWithID:(CKRecordID *)recordID
         completionHandler:(void (^)(CKRecordID *recordID, NSError *error))completionHandler
{
    [self perform:@"POST" path:@"records/modify"
            body:@{@"records": @[@{@"operationType": @"forceDelete",
                                   @"recordID": RevenantCKRecordIDDocument(recordID)}]}
       completion:^(id body, NSError *error) {
        if (error) {
            completionHandler(nil, error);
            return;
        }
        NSArray *records = [body[@"records"] isKindOfClass:[NSArray class]] ? body[@"records"] : nil;
        completionHandler(recordID, nil);
        (void)records;
    }];
}

- (void)fetchAllRecordZonesWithCompletionHandler:(void (^)(NSArray<CKRecordZone *> *zones, NSError *error))completionHandler
{
    [self perform:@"POST" path:@"zones/list" body:nil completion:^(id body, NSError *error) {
        if (error) {
            completionHandler(nil, error);
            return;
        }
        NSMutableArray *zones = [NSMutableArray array];
        for (NSDictionary *document in body[@"zones"]) {
            CKRecordZone *zone = RevenantCKZoneWithDocument(document);
            if (zone) {
                [zones addObject:zone];
            }
        }
        completionHandler(zones, nil);
    }];
}

- (void)fetchRecordZoneWithID:(CKRecordZoneID *)zoneID
            completionHandler:(void (^)(CKRecordZone *zone, NSError *error))completionHandler
{
    [self perform:@"POST" path:@"zones/lookup" body:@{@"zoneIDs": @[RevenantCKZoneIDDocument(zoneID)]}
       completion:^(id body, NSError *error) {
        if (error) {
            completionHandler(nil, error);
            return;
        }
        NSArray *zones = [body[@"zones"] isKindOfClass:[NSArray class]] ? body[@"zones"] : nil;
        CKRecordZone *zone = zones.count ? RevenantCKZoneWithDocument(zones[0]) : nil;
        completionHandler(zone, zone ? nil : RevenantCKError(CKErrorZoneNotFound, @"The zone does not exist", nil));
    }];
}

- (void)saveRecordZone:(CKRecordZone *)zone
     completionHandler:(void (^)(CKRecordZone *zone, NSError *error))completionHandler
{
    [self perform:@"POST" path:@"zones/modify"
            body:@{@"zones": @[@{@"zoneID": RevenantCKZoneIDDocument(zone.zoneID), @"atomic": @((int)1)}]}
       completion:^(id body, NSError *error) {
        if (error) {
            completionHandler(nil, error);
            return;
        }
        NSArray *zones = [body[@"zones"] isKindOfClass:[NSArray class]] ? body[@"zones"] : nil;
        completionHandler(zones.count ? RevenantCKZoneWithDocument(zones[0]) : zone, nil);
    }];
}

- (void)deleteRecordZoneWithID:(CKRecordZoneID *)zoneID
             completionHandler:(void (^)(CKRecordZoneID *zoneID, NSError *error))completionHandler
{
    [self perform:@"POST" path:@"zones/modify" body:@{@"zoneIDs": @[RevenantCKZoneIDDocument(zoneID)]}
       completion:^(id body, NSError *error) {
        completionHandler(error ? nil : zoneID, error);
    }];
}

- (void)performQuery:(CKQuery *)query inZoneWithID:(CKRecordZoneID *)zoneID
   completionHandler:(void (^)(NSArray<CKRecord *> *results, NSError *error))completionHandler
{
    NSError *refused = nil;
    NSDictionary *document = RevenantCKQueryDocument(query, zoneID.zoneName, nil, 0, &refused);
    if (!document) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            completionHandler(nil, refused);
        });
        return;
    }
    [self perform:@"POST" path:@"records/query" body:document completion:^(id body, NSError *error) {
        if (error) {
            completionHandler(nil, error);
            return;
        }
        completionHandler(RevenantCKRecordsFromResults(body[@"records"], nil), nil);
    }];
}

- (void)fetchSubscriptionWithID:(CKSubscriptionID)subscriptionID
             completionHandler:(void (^)(CKSubscription *subscription, NSError *error))completionHandler
{
    [self perform:@"POST" path:@"subscriptions/lookup" body:@{@"subscriptionIDs": @[subscriptionID]}
       completion:^(id body, NSError *error) {
        if (error) {
            completionHandler(nil, error);
            return;
        }
        NSArray *found = [body[@"subscriptions"] isKindOfClass:[NSArray class]] ? body[@"subscriptions"] : nil;
        completionHandler(found.count ? RevenantCKSubscriptionWithDocument(found[0]) : nil,
                          found.count ? nil : RevenantCKError(CKErrorUnknownItem, @"The subscription does not exist", nil));
    }];
}

- (void)fetchAllSubscriptionsWithCompletionHandler:(void (^)(NSArray<CKSubscription *> *subscriptions, NSError *error))completionHandler
{
    [self perform:@"POST" path:@"subscriptions/list" body:nil completion:^(id body, NSError *error) {
        if (error) {
            completionHandler(nil, error);
            return;
        }
        NSMutableArray *found = [NSMutableArray array];
        for (NSDictionary *document in body[@"subscriptions"]) {
            CKSubscription *subscription = RevenantCKSubscriptionWithDocument(document);
            if (subscription) {
                [found addObject:subscription];
            }
        }
        completionHandler(found, nil);
    }];
}

- (void)saveSubscription:(CKSubscription *)subscription
       completionHandler:(void (^)(CKSubscription *subscription, NSError *error))completionHandler
{
    NSDictionary *document = RevenantCKSubscriptionDocument(subscription);
    if (!document) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            completionHandler(nil, RevenantCKError(CKErrorInvalidArguments,
                                                  @"This predicate has no form in a CloudKit query", nil));
        });
        return;
    }
    [self perform:@"POST" path:@"subscriptions/modify" body:@{@"subscriptions": @[document]}
       completion:^(id body, NSError *error) {
        if (error) {
            completionHandler(nil, error);
            return;
        }
        NSArray *found = [body[@"subscriptions"] isKindOfClass:[NSArray class]] ? body[@"subscriptions"] : nil;
        completionHandler(found.count ? RevenantCKSubscriptionWithDocument(found[0]) : subscription, nil);
    }];
}

- (void)deleteSubscriptionWithID:(CKSubscriptionID)subscriptionID
               completionHandler:(void (^)(CKSubscriptionID subscriptionID, NSError *error))completionHandler
{
    [self perform:@"POST" path:@"subscriptions/modify" body:@{@"subscriptionIDs": @[subscriptionID]}
       completion:^(id body, NSError *error) {
        completionHandler(error ? nil : subscriptionID, error);
    }];
}

@end
