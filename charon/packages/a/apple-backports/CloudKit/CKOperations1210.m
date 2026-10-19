#import "CharonCloudKit.h"
#import "CharonCKConstants.h"
#import "CharonCKSubscription.h"


#pragma mark - CKFetchDatabaseChangesOperation

@implementation CKFetchDatabaseChangesOperation

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self charon_setUp];
        _resultsLimit = CKQueryOperationMaximumResults;
    }
    return self;
}

- (instancetype)initWithPreviousServerChangeToken:(CKServerChangeToken *)previousServerChangeToken
{
    self = [self init];
    if (self) {
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
    NSMutableDictionary *body = [NSMutableDictionary dictionary];
    if (self.previousServerChangeToken) {
        NSData *previous = CharonCKSystemFieldsSnapshotToken(self.previousServerChangeToken);
        if (previous.length) {
            body[@"resultsLimit"] = @(self.resultsLimit ?: 0);
            body[@"continuationMarker"] = [previous base64EncodedStringWithOptions:0];
        }
    }
    if (self.fetchAllChanges) {
        body[@"fetchAllChanges"] = @YES;
    }
    __unsafe_unretained CKFetchDatabaseChangesOperation *weakSelf = self;
    [self runMethod:@"POST" path:@"changes" body:body completion:^(id answer, NSError *error) {
        CKFetchDatabaseChangesOperation *strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        if (error) {
            if (strongSelf.fetchDatabaseChangesCompletionBlock) {
                strongSelf.fetchDatabaseChangesCompletionBlock(nil, NO, error);
            }
            return;
        }
        for (NSString *name in answer[@"changedZones"]) {
            CKRecordZoneID *zoneID = [[CKRecordZoneID alloc] initWithZoneName:name ownerName:CKOwnerDefaultName];
            if (strongSelf.recordZoneWithIDChangedBlock) {
                strongSelf.recordZoneWithIDChangedBlock(zoneID);
            }
        }
        for (NSString *name in answer[@"deletedZones"]) {
            CKRecordZoneID *zoneID = [[CKRecordZoneID alloc] initWithZoneName:name ownerName:CKOwnerDefaultName];
            if (strongSelf.recordZoneWithIDWasDeletedBlock) {
                strongSelf.recordZoneWithIDWasDeletedBlock(zoneID);
            }
        }
        for (NSString *name in answer[@"purgedZones"]) {
            CKRecordZoneID *zoneID = [[CKRecordZoneID alloc] initWithZoneName:name ownerName:CKOwnerDefaultName];
            if (strongSelf.recordZoneWithIDWasPurgedBlock) {
                strongSelf.recordZoneWithIDWasPurgedBlock(zoneID);
            }
        }
        NSString *marker = [answer[@"continuationMarker"] isKindOfClass:[NSString class]]
            ? answer[@"continuationMarker"] : nil;
        NSData *token = marker.length ? [[NSData alloc] initWithBase64EncodedString:marker
                                                                      options:NSDataBase64DecodingIgnoreUnknownCharacters] : nil;
        BOOL more = [answer[@"moreComing"] boolValue];
        if (strongSelf.fetchDatabaseChangesCompletionBlock) {
            strongSelf.fetchDatabaseChangesCompletionBlock(CharonCKServerTokenFromData(token), more, nil);
        }
    }];
}

@end

@implementation CKFetchRecordZoneChangesOptions

+ (instancetype)options
{
    return [[self alloc] init];
}

+ (instancetype)new
{
    return [[self alloc] init];
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _resultsLimit = CKQueryOperationMaximumResults;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    CKFetchRecordZoneChangesOptions *copy = [[[self class] allocWithZone:zone] init];
    copy.previousServerChangeToken = _previousServerChangeToken;
    copy.resultsLimit = _resultsLimit;
    copy.desiredKeys = _desiredKeys;
    return copy;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p; previousServerChangeToken=%@, resultsLimit=%lu, desiredKeys=%@>",
            NSStringFromClass([self class]), self, _previousServerChangeToken,
            (unsigned long)_resultsLimit, _desiredKeys];
}

@end

#pragma mark - The per-zone fetch document

static void CharonCKTakeZoneChanging(id entry, NSString **token, NSUInteger *limit, NSArray **keys)
{
    if ([entry isKindOfClass:[CKFetchRecordZoneChangesConfiguration class]]) {
        CKFetchRecordZoneChangesConfiguration *configuration = (CKFetchRecordZoneChangesConfiguration *)entry;
        *token = [configuration.previousServerChangeToken.data base64EncodedStringWithOptions:0];
        *limit = configuration.resultsLimit;
        *keys = configuration.desiredKeys;
        return;
    }
    if ([entry isKindOfClass:[CKFetchRecordZoneChangesOptions class]]) {
        CKFetchRecordZoneChangesOptions *options = (CKFetchRecordZoneChangesOptions *)entry;
        *token = [options.previousServerChangeToken.data base64EncodedStringWithOptions:0];
        *limit = options.resultsLimit;
        *keys = options.desiredKeys;
    }
}

#pragma mark - CKFetchRecordZoneChangesOperation

@implementation CKFetchRecordZoneChangesOperation

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self charon_setUp];
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

- (instancetype)initWithRecordZoneIDs:(NSArray<CKRecordZoneID *> *)recordZoneIDs
    configurationsByRecordZoneID:(NSDictionary<CKRecordZoneID *, CKFetchRecordZoneChangesConfiguration *> *)configurationsByRecordZoneID
{
    self = [self initWithRecordZoneIDs:recordZoneIDs];
    if (self) {
        _configurationsByRecordZoneID = [configurationsByRecordZoneID copy];
    }
    return self;
}

- (instancetype)initWithRecordZoneIDs:(NSArray<CKRecordZoneID *> *)recordZoneIDs
              optionsByRecordZoneID:(NSDictionary *)optionsByRecordZoneID
{
    self = [self initWithRecordZoneIDs:recordZoneIDs];
    if (self) {
        [self setOptionsByRecordZoneID:optionsByRecordZoneID];
    }
    return self;
}

+ (instancetype)new
{
    return [[self alloc] init];
}

- (void)main
{
    if (!self.recordZoneIDs.count) {
        if (self.fetchRecordZoneChangesCompletionBlock) {
            self.fetchRecordZoneChangesCompletionBlock(CharonCKError(CKErrorInvalidArguments, @"No zone", nil));
        }
        [self charon_finish];
        return;
    }
    NSMutableDictionary *body = [NSMutableDictionary dictionary];
    NSMutableArray *zones = [NSMutableArray array];
    for (CKRecordZoneID *zoneID in self.recordZoneIDs) {
        NSString *token = nil;
        NSUInteger limit = 0;
        NSArray *keys = nil;
        CharonCKTakeZoneChanging(self.configurationsByRecordZoneID[zoneID]
                                     ?: self.optionsByRecordZoneID[zoneID], &token, &limit, &keys);
        NSMutableDictionary *half = [NSMutableDictionary dictionary];
        half[@"zoneID"] = CharonCKZoneIDDocument(zoneID);
        if (token.length) {
            half[@"resultsLimit"] = @(limit);
            [half setObject:token forKey:@"continuationMarker"];
        }
        if (keys.count) {
            half[@"desiredKeys"] = keys;
        }
        [zones addObject:half];
    }
    body[@"zones"] = zones;
    if (self.fetchAllChanges) {
        body[@"fetchAllChanges"] = @YES;
    }
    __unsafe_unretained CKFetchRecordZoneChangesOperation *weakSelf = self;
    [self runMethod:@"POST" path:@"changes" body:body completion:^(id answer, NSError *error) {
        CKFetchRecordZoneChangesOperation *strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        if (error) {
            if (strongSelf.fetchRecordZoneChangesCompletionBlock) {
                strongSelf.fetchRecordZoneChangesCompletionBlock(error);
            }
            return;
        }
        NSMutableDictionary *failures = [NSMutableDictionary dictionary];
        for (NSDictionary *document in answer[@"zones"]) {
            CKRecordZoneID *zoneID = CharonCKZoneIDFromDocument(document[@"zoneID"]);
            NSError *zoneError = [document[@"serverError"] isKindOfClass:[NSDictionary class]]
                ? CharonCKErrorFromPayload(document[@"serverError"], nil) : nil;
            if (zoneID && zoneError) {
                failures[zoneID.zoneName] = zoneError;
            }
            for (NSDictionary *record in document[@"records"]) {
                CKRecord *changed = CharonCKRecordFromResult(record, nil);
                CKRecordID *recordID = CharonCKRecordIDFromDocument(record);
                if (changed && strongSelf.recordChangedBlock) {
                    strongSelf.recordChangedBlock(changed);
                }
                if (recordID && strongSelf.recordWasChangedBlock) {
                    strongSelf.recordWasChangedBlock(recordID, changed, nil);
                }
            }
            for (NSDictionary *deleted in document[@"deletedRecordIDs"]) {
                CKRecordID *recordID = CharonCKRecordIDFromDocument(deleted);
                NSString *type = [deleted[@"recordType"] isKindOfClass:[NSString class]] ? deleted[@"recordType"] : @"*";
                if (recordID && strongSelf.recordWithIDWasDeletedBlock) {
                    strongSelf.recordWithIDWasDeletedBlock(recordID, type);
                }
            }
            NSString *marker = [document[@"continuationMarker"] isKindOfClass:[NSString class]]
                ? document[@"continuationMarker"] : nil;
            NSData *token = marker.length ? [[NSData alloc] initWithBase64EncodedString:marker
                                                                      options:NSDataBase64DecodingIgnoreUnknownCharacters] : nil;
            if (zoneID && strongSelf.recordZoneChangeTokensUpdatedBlock) {
                strongSelf.recordZoneChangeTokensUpdatedBlock(zoneID, CharonCKServerTokenFromData(token),
                                                              document[@"clientChangeToken"]);
            }
            if (zoneID && strongSelf.recordZoneFetchCompletionBlock) {
                strongSelf.recordZoneFetchCompletionBlock(zoneID, CharonCKServerTokenFromData(token),
                                                         document[@"clientChangeToken"],
                                                         [document[@"moreComing"] boolValue], zoneError);
            }
        }
        NSError *overall = [strongSelf partialFailureWithItems:failures];
        if (strongSelf.fetchRecordZoneChangesCompletionBlock) {
            strongSelf.fetchRecordZoneChangesCompletionBlock(overall);
        }
    }];
}

@end
