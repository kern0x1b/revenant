// The container and the database: the two classes an application starts from.
//
// A CKContainer is a name and three databases, plus the requests that are about the account rather
// than about a database. A CKDatabase is a scope and the fourteen convenience methods the header
// gives it, each of which is one request and one answer over the transport:
// facts/CloudKit/WebServices.md names the endpoints.
//
// The two classes the header marks unavailable are refused with the host's own exception and the
// host's own words, measured: `[CKDatabase new]` raises `NSInternalInconsistencyException` with
// "Use +[CKContainer privateCloudDatabase] or +[CKContainer publicCloudDatabase] instead of creating
// your own", and a database's `-init` is the same refusal, which is what NSObject answers for a
// class method sent the wrong way round.
//
// A database is only ever made by a container and neither names the other, so a container tells the
// transport which one a database is and which environment it is reached in, once, and every request
// below is built from that.

#import "CharonCloudKit.h"
#import "CharonCKConstants.h"
#import "CharonCKSubscription.h"

// The two things a database needs that its own header does not name: the container it belongs to and
// the fact that it was made by one. A database is only ever made by a container, and the service's
// path is under a container, so the container is the port's own state here.
@interface CKDatabase ()
// The container a database belongs to. Neither the header's CKDatabase nor its CKContainer names
// the other, and the service's path is under a container, so this is the port's own state and the
// one thing the transport and the operations both read to find out where a request goes.
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
    // CloudKit's own default is the first container the Info.plist names, under the key its own
    // tooling writes. A process with no container at all has no identifier, and every request it
    // makes answers CKErrorBadContainer rather than raising: see facts/CloudKit/WebServices.md.
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
    // Measured: the host answers +[CKContainer new] with a container, and its own header marks
    // neither -init nor +new unavailable, so this port does the same and hands back the default one.
    return [self defaultContainer];
}

// A database is made once per container and per scope, because the transport is told which
// container a database belongs to and a database that had no container could not make a request.
- (CKDatabase *)databaseWithScope:(CKDatabaseScope)scope
{
    NSNumber *key = @(scope);
    CKDatabase *database = _databases[key];
    if (database) {
        return database;
    }
    database = [[CKDatabase alloc] initWithContainer:self scope:scope];
    _databases[key] = database;
    NSString *environment = [[CharonCKTransport shared] environmentForContainer:self];
    [[CharonCKTransport shared] setContainer:self forDatabase:database environment:environment];
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
    [CharonCKOPScheduler add:operation];
}

- (NSString *)environment
{
    return [[CharonCKTransport shared] environmentForContainer:self];
}

- (CKRecordID *)currentUserRecordID
{
    NSString *name = [[CharonCKCredentials shared] userRecordIDForContainer:self.containerIdentifier];
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
    // Whether the device has an iCloud account is the release's own question, and this release has
    // no account service to ask: `CKAccountStatusNoAccount` is what a device that has none answers
    // and what a device whose account cannot be reached from a process with no container answers too.
    // A container that is provisioned is the only case where anything else could be said, and it
    // cannot be decided without the service.
    CKAccountStatus status = CKAccountStatusNoAccount;
    if (!self.containerIdentifier.length) {
        completionHandler(status, CharonCKBadContainer(nil));
        return;
    }
    completionHandler(status, nil);
}

- (void)fetchUserRecordIDWithCompletionHandler:(void (^)(CKRecordID *recordID, NSError *error))completionHandler
{
    // The record of the signed-in user is the only user record CloudKit has for this container, and
    // the credentials remember the one they saw, so this is answered without a request: the user
    // record of a container is found under the name `_defaultOwner` in the default zone.
    NSString *name = [[CharonCKCredentials shared] userRecordIDForContainer:self.containerIdentifier];
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
    // User discoverability is a property of the account as the service sees it, and this port has no
    // service and no account, so the answer is the header's own initial state: a permission that has
    // never been asked for. It is not a refusal, and it is not a grant.
    completionHandler(CKApplicationPermissionStatusInitialState, nil);
}

- (void)requestApplicationPermission:(CKApplicationPermissions)applicationPermission
                    completionHandler:(void (^)(CKApplicationPermissionStatus status, NSError *error))completionHandler
{
    // Asking needs the same service and the same account, and with neither the answer is the header's
    // own: a request that could not be completed. The code is CKErrorNotAuthenticated, the one the
    // header names for a client that is not signed in, and a caller that is told the initial state
    // instead would be told nothing happened.
    if (!self.containerIdentifier.length) {
        completionHandler(CKApplicationPermissionStatusInitialState, CharonCKBadContainer(nil));
        return;
    }
    completionHandler(CKApplicationPermissionStatusCouldNotComplete, CharonCKNotAuthenticated());
}

@end

#pragma mark - CKDatabase

@interface CKDatabase (CharonCKPrivate)
- (nullable CKContainer *)ck_container;
@end

@implementation CKDatabase (CharonCKRequests)

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
    [CharonCKOPScheduler add:operation];
}

// Every request a database makes goes through here, so the container and the environment are taken
// from the one the container told the transport about, and the path is built once.
- (void)perform:(NSString *)method path:(NSString *)path body:(NSDictionary *)body
     completion:(void (^)(id body, NSError *error))completion
{
    CharonCKTransport *transport = [CharonCKTransport shared];
    NSString *root = [transport databaseRootForContainer:self.ck_container.containerIdentifier
                                                database:self
                                             environment:[transport environmentForContainer:self.ck_container]];
    [[CharonCKTransport shared] performContainer:self.ck_container
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
    [self perform:@"POST" path:@"records/lookup" body:@{@"recordIDs": @[CharonCKRecordIDDocument(recordID)]}
       completion:^(id body, NSError *error) {
        if (error) {
            completionHandler(nil, error);
            return;
        }
        NSArray *records = [body[@"records"] isKindOfClass:[NSArray class]] ? body[@"records"] : nil;
        CKRecord *record = records.count ? CharonCKRecordFromResult(records[0], nil) : nil;
        // A lookup that found nothing is CKErrorUnknownItem, the code the header names for a record
        // that does not exist. The service answers 200 with an empty list, and a caller handed nil
        // with no error cannot tell that from a record whose value is nil.
        completionHandler(record, record ? nil : CharonCKError(CKErrorUnknownItem, @"The record does not exist", nil));
    }];
}

- (void)saveRecord:(CKRecord *)record
 completionHandler:(void (^)(CKRecord *record, NSError *error))completionHandler
{
    NSMutableDictionary *document = [NSMutableDictionary dictionary];
    document[@"recordName"] = record.recordID.recordName;
    document[@"recordType"] = record.recordType;
    document[@"zoneID"] = CharonCKZoneIDDocument(record.recordID.zoneID);
    document[@"fields"] = CharonCKFieldsToJSON(CharonCKFieldsSnapshot(record));
    NSDictionary *system = CharonCKSystemFieldsSnapshot(record);
    if (system[@"recordChangeTag"]) {
        [document addEntriesFromDictionary:system];
    }
    // A record that has never been saved is a create and one that has a change tag is an update: the
    // tag is what the service issued, and a port that invented one would overwrite a record it has
    // not read.
    NSString *operationType = record.recordChangeTag ? @"update" : @"create";
    [self perform:@"POST" path:@"records/modify"
            body:@{@"records": @[@{@"operationType": operationType, @"record": document}]}
       completion:^(id body, NSError *error) {
        if (error) {
            completionHandler(nil, error);
            return;
        }
        NSArray *records = [body[@"records"] isKindOfClass:[NSArray class]] ? body[@"records"] : nil;
        CKRecord *saved = records.count ? CharonCKRecordFromResult(records[0], nil) : nil;
        completionHandler(saved, saved ? nil : CharonCKError(CKErrorInternalError, @"The save answered nothing", nil));
    }];
}

- (void)deleteRecordWithID:(CKRecordID *)recordID
         completionHandler:(void (^)(CKRecordID *recordID, NSError *error))completionHandler
{
    [self perform:@"POST" path:@"records/modify"
            body:@{@"records": @[@{@"operationType": @"forceDelete",
                                   @"recordID": CharonCKRecordIDDocument(recordID)}]}
       completion:^(id body, NSError *error) {
        if (error) {
            completionHandler(nil, error);
            return;
        }
        // The answer to a delete is the record it removed, as the header says, and the service sends
        // the document back rather than nothing.
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
            CKRecordZone *zone = CharonCKZoneWithDocument(document);
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
    [self perform:@"POST" path:@"zones/lookup" body:@{@"zoneIDs": @[CharonCKZoneIDDocument(zoneID)]}
       completion:^(id body, NSError *error) {
        if (error) {
            completionHandler(nil, error);
            return;
        }
        NSArray *zones = [body[@"zones"] isKindOfClass:[NSArray class]] ? body[@"zones"] : nil;
        CKRecordZone *zone = zones.count ? CharonCKZoneWithDocument(zones[0]) : nil;
        completionHandler(zone, zone ? nil : CharonCKError(CKErrorZoneNotFound, @"The zone does not exist", nil));
    }];
}

- (void)saveRecordZone:(CKRecordZone *)zone
     completionHandler:(void (^)(CKRecordZone *zone, NSError *error))completionHandler
{
    [self perform:@"POST" path:@"zones/modify"
            body:@{@"zones": @[@{@"zoneID": CharonCKZoneIDDocument(zone.zoneID), @"atomic": @((int)1)}]}
       completion:^(id body, NSError *error) {
        if (error) {
            completionHandler(nil, error);
            return;
        }
        NSArray *zones = [body[@"zones"] isKindOfClass:[NSArray class]] ? body[@"zones"] : nil;
        completionHandler(zones.count ? CharonCKZoneWithDocument(zones[0]) : zone, nil);
    }];
}

- (void)deleteRecordZoneWithID:(CKRecordZoneID *)zoneID
             completionHandler:(void (^)(CKRecordZoneID *zoneID, NSError *error))completionHandler
{
    [self perform:@"POST" path:@"zones/modify" body:@{@"zoneIDs": @[CharonCKZoneIDDocument(zoneID)]}
       completion:^(id body, NSError *error) {
        completionHandler(error ? nil : zoneID, error);
    }];
}

- (void)performQuery:(CKQuery *)query inZoneWithID:(CKRecordZoneID *)zoneID
   completionHandler:(void (^)(NSArray<CKRecord *> *results, NSError *error))completionHandler
{
    NSError *refused = nil;
    NSDictionary *document = CharonCKQueryDocument(query, zoneID.zoneName, nil, 0, &refused);
    if (!document) {
        // A predicate the service has no form for never leaves this process, and the code is the
        // header's for a malformed predicate.
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
        completionHandler(CharonCKRecordsFromResults(body[@"records"], nil), nil);
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
        completionHandler(found.count ? CharonCKSubscriptionWithDocument(found[0]) : nil,
                          found.count ? nil : CharonCKError(CKErrorUnknownItem, @"The subscription does not exist", nil));
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
            CKSubscription *subscription = CharonCKSubscriptionWithDocument(document);
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
    NSDictionary *document = CharonCKSubscriptionDocument(subscription);
    if (!document) {
        // A query subscription whose predicate the service has no form for is refused here rather
        // than saved as one that would never fire.
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            completionHandler(nil, CharonCKError(CKErrorInvalidArguments,
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
        completionHandler(found.count ? CharonCKSubscriptionWithDocument(found[0]) : subscription, nil);
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
