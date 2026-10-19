#import "RevenantCloudKit.h"
#import "RevenantCKConstants.h"
#import "RevenantCKSubscription.h"

#import <objc/runtime.h>

NSDictionary *RevenantCKSubscriptionDocument(CKSubscription *subscription)
{
    NSMutableDictionary *document = [NSMutableDictionary dictionary];
    document[@"subscriptionID"] = subscription.subscriptionID;
    NSString *type = nil;
    if ([subscription isKindOfClass:[CKQuerySubscription class]]) {
        type = @"query";
        CKQuerySubscription *query = (CKQuerySubscription *)subscription;
        document[@"recordType"] = query.recordType;
        if (query.zoneID) {
            document[@"zoneID"] = @{@"zoneName": query.zoneID.zoneName,
                                    @"ownerName": query.zoneID.ownerName};
        }
        NSError *refused = nil;
        NSDictionary *filter = RevenantCKQueryDocument([[CKQuery alloc] initWithRecordType:query.recordType
                                                                     predicate:query.predicate ?: [NSPredicate predicateWithValue:YES]],
                                                     query.zoneID.zoneName, nil, 0, &refused);
        if (!filter) {
            return nil;
        }
        document[@"predicate"] = filter;
        if (query.querySubscriptionOptions & CKQuerySubscriptionOptionsFiresOnRecordCreation) {
            document[@"content-available"] = @1;
        }
    } else if ([subscription isKindOfClass:[CKRecordZoneSubscription class]]) {
        type = @"zone";
        CKRecordZoneSubscription *zone = (CKRecordZoneSubscription *)subscription;
        document[@"zoneID"] = @{@"zoneName": zone.zoneID.zoneName, @"ownerName": zone.zoneID.ownerName};
    } else {
        type = @"database";
    }
    document[@"subscriptionType"] = type;
    CKNotificationInfo *info = subscription.notificationInfo;
    if (info) {
        NSMutableDictionary *notification = [NSMutableDictionary dictionary];
        if (info.shouldSendContentAvailable) {
            notification[@"shouldSendContentAvailable"] = @1;
        }
        if (info.shouldSendMutableContent) {
            notification[@"shouldSendMutableContent"] = @1;
        }
        if (info.shouldBadge) {
            notification[@"shouldBadge"] = @1;
        }
        if (info.soundName) {
            notification[@"sound"] = info.soundName;
        }
        if (info.alertBody) {
            notification[@"alertBody"] = info.alertBody;
        }
        if (info.alertLocalizationKey) {
            notification[@"alertLocalizationKey"] = info.alertLocalizationKey;
        }
        if (info.alertLocalizationArgs) {
            notification[@"alertLocalizationArgs"] = info.alertLocalizationArgs;
        }
        if (info.title) {
            notification[@"title"] = info.title;
        }
        if (info.subtitle) {
            notification[@"subtitle"] = info.subtitle;
        }
        if (info.category) {
            notification[@"category"] = info.category;
        }
        if (info.desiredKeys) {
            notification[@"desiredKeys"] = info.desiredKeys;
        }
        if (notification.count) {
            document[@"notificationInfo"] = notification;
        }
    }
    return document;
}

CKSubscription *RevenantCKSubscriptionWithDocument(NSDictionary *document)
{
    if (![document isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    NSString *identifier = document[@"subscriptionID"];
    if (![identifier isKindOfClass:[NSString class]] || !identifier.length) {
        return nil;
    }
    NSString *type = document[@"subscriptionType"];
    NSDictionary *zone = [document[@"zoneID"] isKindOfClass:[NSDictionary class]] ? document[@"zoneID"] : nil;
    CKSubscription *subscription = nil;
    if ([type isEqualToString:@"query"]) {
        CKRecordZoneID *zoneID = zone ? [[CKRecordZoneID alloc] initWithZoneName:zone[@"zoneName"]
                                                                       ownerName:zone[@"ownerName"] ?: CKOwnerDefaultName] : nil;
        NSPredicate *predicate = [NSPredicate predicateWithValue:YES];
        CKQuerySubscription *query = [[CKQuerySubscription alloc] initWithRecordType:document[@"recordType"] ?: @"*"
                                                                          predicate:predicate
                                                                     subscriptionID:identifier
                                                                           options:document[@"content-available"]
                                                                               ? CKQuerySubscriptionOptionsFiresOnRecordCreation : 0];
        if (zoneID) {
            (void)zoneID;
        }
        subscription = query;
    } else if ([type isEqualToString:@"zone"]) {
        CKRecordZoneID *zoneID = [[CKRecordZoneID alloc] initWithZoneName:zone[@"zoneName"] ?: CKRecordZoneDefaultName
                                                                 ownerName:zone[@"ownerName"] ?: CKOwnerDefaultName];
        subscription = [[CKRecordZoneSubscription alloc] initWithZoneID:zoneID subscriptionID:identifier];
    } else {
        subscription = [[CKDatabaseSubscription alloc] initWithSubscriptionID:identifier];
    }
    NSDictionary *info = [document[@"notificationInfo"] isKindOfClass:[NSDictionary class]]
        ? document[@"notificationInfo"] : nil;
    if (info) {
        CKNotificationInfo *notification = [[CKNotificationInfo alloc] init];
        notification.shouldSendContentAvailable = [info[@"shouldSendContentAvailable"] boolValue];
        notification.shouldSendMutableContent = [info[@"shouldSendMutableContent"] boolValue];
        notification.shouldBadge = [info[@"shouldBadge"] boolValue];
        notification.soundName = info[@"sound"];
        notification.alertBody = info[@"alertBody"];
        notification.alertLocalizationKey = info[@"alertLocalizationKey"];
        notification.alertLocalizationArgs = info[@"alertLocalizationArgs"];
        notification.title = info[@"title"];
        notification.subtitle = info[@"subtitle"];
        notification.category = info[@"category"];
        notification.desiredKeys = info[@"desiredKeys"];
        subscription.notificationInfo = notification;
    }
    return subscription;
}

NSDictionary *RevenantCKFieldsSnapshot(CKRecord *record)
{
    NSMutableDictionary *fields = [NSMutableDictionary dictionary];
    for (NSString *key in record.allKeys) {
        if ([key hasPrefix:@"___"]) {
            continue;
        }
        id value = [record objectForKey:key];
        if (value) {
            fields[key] = value;
        }
    }
    return fields;
}

NSDictionary *RevenantCKSystemFieldsSnapshot(CKRecord *record)
{
    NSMutableDictionary *fields = [NSMutableDictionary dictionary];
    if (record.recordChangeTag) {
        fields[CKRecordRecordIDKey] = record.recordID;
        fields[@"recordChangeTag"] = record.recordChangeTag;
    }
    if (record.creationDate) {
        fields[CKRecordCreationDateKey] = record.creationDate;
    }
    if (record.modificationDate) {
        fields[CKRecordModificationDateKey] = record.modificationDate;
    }
    if (record.creatorUserRecordID) {
        fields[CKRecordCreatorUserRecordIDKey] = record.creatorUserRecordID;
    }
    if (record.lastModifiedUserRecordID) {
        fields[CKRecordLastModifiedUserRecordIDKey] = record.lastModifiedUserRecordID;
    }
    return fields;
}

NSData *RevenantCKSystemFieldsSnapshotToken(CKServerChangeToken *token)
{
    return token.data;
}

CKServerChangeToken *RevenantCKServerTokenFromData(NSData *data)
{
    return data.length ? [CKServerChangeToken tokenWithData:data] : nil;
}

@interface RevenantCKOPSchedulerEntry : NSObject
@property (nonatomic, strong) NSOperation *operation;
@end

@implementation RevenantCKOPSchedulerEntry

@synthesize operation = _operation;

@end

@implementation RevenantCKOPScheduler

static NSOperationQueue *RevenantCKQueue(void)
{
    static NSOperationQueue *queue;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        queue = [[NSOperationQueue alloc] init];
        queue.maxConcurrentOperationCount = 4;
        [queue setSuspended:NO];
    });
    return queue;
}

+ (void)add:(NSOperation *)operation
{
    if (!operation) {
        return;
    }
    [RevenantCKQueue() addOperation:operation];
}

+ (void)complete:(NSOperation *)operation
{
    objc_setAssociatedObject(operation, "RevenantCKFinished", @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [operation setValue:@YES forKey:@"finished"];
}

+ (void)cancelAll
{
    [RevenantCKQueue() cancelAllOperations];
}

@end

CKUserIdentity *RevenantCKUserIdentityWithDocument(NSDictionary *document)
{
    if (![document isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    CKUserIdentity *identity = [[CKUserIdentity alloc] revenant_identity];
    CKRecordID *recordID = RevenantCKRecordIDFromDocument(document[@"userRecordID"]);
    if (recordID) {
        identity.userRecordID = recordID;
    }
    identity.hasiCloudAccount = [document[@"hasiCloudAccount"] boolValue];
    if ([document[@"lookupInfo"] isKindOfClass:[NSDictionary class]]) {
        identity.lookupInfo = RevenantCKLookupInfoWithDocument(document[@"lookupInfo"]);
    }
    if ([document[@"contactIdentifiers"] isKindOfClass:[NSArray class]]) {
        identity.contactIdentifiers = document[@"contactIdentifiers"];
    }
    return identity;
}

CKUserIdentityLookupInfo *RevenantCKLookupInfoWithDocument(NSDictionary *document)
{
    if (![document isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    if ([document[@"email"] isKindOfClass:[NSString class]]) {
        return [[CKUserIdentityLookupInfo alloc] initWithEmailAddress:document[@"email"]];
    }
    if ([document[@"phoneNumber"] isKindOfClass:[NSString class]]) {
        return [[CKUserIdentityLookupInfo alloc] initWithPhoneNumber:document[@"phoneNumber"]];
    }
    CKRecordID *recordID = RevenantCKRecordIDFromDocument(document[@"userRecordID"]);
    return recordID ? [[CKUserIdentityLookupInfo alloc] initWithUserRecordID:recordID] : nil;
}

CKShareParticipant *RevenantCKShareParticipantWithDocument(NSDictionary *document)
{
    if (![document isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    CKShareParticipant *participant = [[CKShareParticipant alloc] initWithType:CKShareParticipantTypeOwner];
    participant.userIdentity = RevenantCKUserIdentityWithDocument(document[@"userIdentity"]);
    if ([document[@"participantID"] isKindOfClass:[NSString class]]) {
        participant.participantID = document[@"participantID"];
    }
    return participant;
}

CKShareMetadata *RevenantCKShareMetadataWithDocument(NSDictionary *document, CKContainer *container)
{
    if (![document isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    NSString *url = [document[@"shareURL"] isKindOfClass:[NSString class]] ? document[@"shareURL"] : nil;
    CKRecordID *root = RevenantCKRecordIDFromDocument(document[@"rootRecordID"]);
    if (!url || !root) {
        return nil;
    }
    CKShareMetadata *metadata = [[CKShareMetadata alloc] initWithRootRecordID:root
                                                         containerIdentifier:container.containerIdentifier
                                                                    shareURL:[NSURL URLWithString:url]
                                                             participantType:CKShareParticipantTypeOwner
                                                                  permission:CKShareParticipantPermissionReadWrite];
    metadata.ownerIdentity = RevenantCKUserIdentityWithDocument(document[@"ownerIdentity"]);
    if ([document[@"hierarchicalRootRecordID"] isKindOfClass:[NSDictionary class]]) {
        metadata.hierarchicalRootRecordID = RevenantCKRecordIDFromDocument(document[@"hierarchicalRootRecordID"]);
    }
    return metadata;
}
