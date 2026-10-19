// What iOS 10 added to CloudKit's value surface: the three subscription subclasses, the notification
// and the three notifications it comes in, the identity of a user, the participant a share carries,
// the metadata a share URL resolves to, and the options a share says who may be added.
//
// All of these are values, and all of them are held to the host's own answers the way the first
// release's classes are. What each of them is *for* - the requests that resolve a share URL, discover
// an identity, or save a subscription - is the transport and is a later delivery; a class that names
// something is here because a caller can name it, build it, keep it and read it back.

#import <Foundation/Foundation.h>
#import <CloudKit/CloudKit.h>

#import "CharonCKSubscription.h"
#import "CharonCKValue.h"

#pragma mark - CKQuerySubscription

@implementation CKQuerySubscription

- (instancetype)initWithRecordType:(CKRecordType)recordType
                          predicate:(NSPredicate *)predicate
                           options:(CKQuerySubscriptionOptions)options
{
    return [self initWithRecordType:recordType
                          predicate:predicate
                     subscriptionID:CharonCKNewSubscriptionID()
                           options:options];
}

- (instancetype)initWithRecordType:(CKRecordType)recordType
                          predicate:(NSPredicate *)predicate
                     subscriptionID:(CKSubscriptionID)subscriptionID
                           options:(CKQuerySubscriptionOptions)options
{
    self = [super initWithSubscriptionID:subscriptionID];
    if (self) {
        _recordType = [recordType copy];
        _predicate = [predicate copy];
        _querySubscriptionOptions = options;
    }
    return self;
}

- (instancetype)initWithSubscriptionID:(CKSubscriptionID)subscriptionID
{
    self = [super initWithSubscriptionID:subscriptionID];
    if (self) {
        _querySubscriptionOptions = 0;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        _recordType = [[coder decodeObjectOfClass:[NSString class] forKey:@"recordType"] copy];
        _predicate = [coder decodeObjectOfClass:[NSPredicate class] forKey:@"predicate"];
        _querySubscriptionOptions = (CKQuerySubscriptionOptions)[coder decodeIntegerForKey:@"options"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    [coder encodeObject:_recordType forKey:@"recordType"];
    [coder encodeObject:_predicate forKey:@"predicate"];
    [coder encodeInteger:(NSInteger)_querySubscriptionOptions forKey:@"options"];
}

+ (CKSubscriptionType)subscriptionType
{
    return CKNotificationTypeQuery;
}

- (CKRecordZoneID *)zoneID
{
    return [[CKRecordZoneID alloc] initWithZoneName:CKRecordZoneDefaultName ownerName:CKOwnerDefaultName];
}

- (id)copyWithZone:(NSZone *)zone
{
    CKQuerySubscription *copy = [[CKQuerySubscription allocWithZone:zone] initWithRecordType:_recordType
                                                                                 predicate:_predicate
                                                                            subscriptionID:self.subscriptionID
                                                                                  options:_querySubscriptionOptions];
    copy.notificationInfo = self.notificationInfo;
    return copy;
}

- (BOOL)isEqual:(id)other
{
    if (![super isEqual:other]) {
        return NO;
    }
    CKQuerySubscription *subscription = other;
    return [_recordType isEqualToString:subscription.recordType] && [_predicate isEqual:subscription.predicate] &&
           _querySubscriptionOptions == subscription.querySubscriptionOptions;
}

- (NSUInteger)hash
{
    return [super hash] ^ _recordType.hash;
}

@end

#pragma mark - CKRecordZoneSubscription

@implementation CKRecordZoneSubscription

- (instancetype)initWithZoneID:(CKRecordZoneID *)zoneID
{
    return [self initWithZoneID:zoneID subscriptionID:CharonCKNewSubscriptionID()];
}

- (instancetype)initWithZoneID:(CKRecordZoneID *)zoneID subscriptionID:(CKSubscriptionID)subscriptionID
{
    self = [super initWithSubscriptionID:subscriptionID];
    if (self) {
        _zoneID = [zoneID copy];
    }
    return self;
}

- (instancetype)initWithSubscriptionID:(CKSubscriptionID)subscriptionID
{
    self = [super initWithSubscriptionID:subscriptionID];
    if (self) {
        _zoneID = [[CKRecordZoneID alloc] initWithZoneName:CKRecordZoneDefaultName ownerName:CKOwnerDefaultName];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        _zoneID = [coder decodeObjectOfClass:[CKRecordZoneID class] forKey:@"zoneID"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    [coder encodeObject:_zoneID forKey:@"zoneID"];
}

+ (CKSubscriptionType)subscriptionType
{
    return (CKSubscriptionType)CKNotificationTypeRecordZone;
}

- (CKRecordType)recordType
{
    return @"*";
}

- (id)copyWithZone:(NSZone *)zone
{
    CKRecordZoneSubscription *copy = [[CKRecordZoneSubscription allocWithZone:zone] initWithZoneID:_zoneID
                                                                                    subscriptionID:self.subscriptionID];
    copy.notificationInfo = self.notificationInfo;
    return copy;
}

- (BOOL)isEqual:(id)other
{
    if (![super isEqual:other]) {
        return NO;
    }
    return [_zoneID isEqual:((CKRecordZoneSubscription *)other).zoneID];
}

- (NSUInteger)hash
{
    return [super hash] ^ _zoneID.hash;
}

@end

#pragma mark - CKDatabaseSubscription

@implementation CKDatabaseSubscription

- (instancetype)initWithSubscriptionID:(CKSubscriptionID)subscriptionID
{
    return [super initWithSubscriptionID:subscriptionID ?: CharonCKNewSubscriptionID()];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    return [super initWithCoder:coder];
}

+ (CKSubscriptionType)subscriptionType
{
    return CKNotificationTypeDatabase;
}

- (CKRecordType)recordType
{
    return @"*";
}

- (id)copyWithZone:(NSZone *)zone
{
    CKDatabaseSubscription *copy = [[CKDatabaseSubscription allocWithZone:zone] initWithSubscriptionID:self.subscriptionID];
    copy.notificationInfo = self.notificationInfo;
    return copy;
}

@end

#pragma mark - CKDatabaseNotification

@implementation CKDatabaseNotification
{
    CKDatabaseScope _databaseScope;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<CKDatabaseNotification: %p; databaseScope=%ld, notificationID=%@, subscriptionID=%@>",
            self, (long)_databaseScope, self.notificationID, self.subscriptionID];
}

@end

#pragma mark - CKUserIdentityLookupInfo

@implementation CKUserIdentityLookupInfo

- (instancetype)initWithEmailAddress:(NSString *)emailAddress
{
    self = [super init];
    if (self) {
        _emailAddress = [emailAddress copy];
    }
    return self;
}

- (instancetype)initWithPhoneNumber:(NSString *)phoneNumber
{
    self = [super init];
    if (self) {
        _phoneNumber = [phoneNumber copy];
    }
    return self;
}

- (instancetype)initWithUserRecordID:(CKRecordID *)userRecordID
{
    self = [super init];
    if (self) {
        _userRecordID = [userRecordID copy];
    }
    return self;
}

+ (NSArray<CKUserIdentityLookupInfo *> *)lookupInfosWithEmails:(NSArray<NSString *> *)emails
{
    NSMutableArray *found = [NSMutableArray arrayWithCapacity:emails.count];
    for (NSString *email in emails) {
        [found addObject:[[self alloc] initWithEmailAddress:email]];
    }
    return found;
}

+ (NSArray<CKUserIdentityLookupInfo *> *)lookupInfosWithPhoneNumbers:(NSArray<NSString *> *)phoneNumbers
{
    NSMutableArray *found = [NSMutableArray arrayWithCapacity:phoneNumbers.count];
    for (NSString *phoneNumber in phoneNumbers) {
        [found addObject:[[self alloc] initWithPhoneNumber:phoneNumber]];
    }
    return found;
}

+ (NSArray<CKUserIdentityLookupInfo *> *)lookupInfosWithRecordIDs:(NSArray<CKRecordID *> *)recordIDs
{
    NSMutableArray *found = [NSMutableArray arrayWithCapacity:recordIDs.count];
    for (CKRecordID *recordID in recordIDs) {
        [found addObject:[[self alloc] initWithUserRecordID:recordID]];
    }
    return found;
}

- (NSString *)description
{
    if (_emailAddress) {
        return [NSString stringWithFormat:@"<CKUserIdentityLookupInfo: %p; emailAddress=%@>", self, _emailAddress];
    }
    if (_phoneNumber) {
        return [NSString stringWithFormat:@"<CKUserIdentityLookupInfo: %p; phoneNumber=%@>", self, _phoneNumber];
    }
    return [NSString stringWithFormat:@"<CKUserIdentityLookupInfo: %p; userRecordID=%@>", self, _userRecordID];
}

@end

#pragma mark - CKShareMetadata

@implementation CKShareMetadata


+ (instancetype)new
{
    [NSException raise:NSInvalidArgumentException
                format:@"Do not instantiate CKShare.Metadata, obtain them from CKFetchShareMetadataOperation or platform-specific scene / app delegate callbacks.",
                nil];
    return nil;
}

- (instancetype)init
{
    [NSException raise:NSInvalidArgumentException
                format:@"Do not instantiate CKShare.Metadata, obtain them from CKFetchShareMetadataOperation or platform-specific scene / app delegate callbacks.",
                nil];
    return nil;
}

+ (instancetype)metadataWithShareURL:(NSURL *)shareURL rootRecordID:(CKRecordID *)rootRecordID
                        participantType:(CKShareParticipantType)participantType
                          permission:(CKShareParticipantPermission)permission
{
    return [[self alloc] initWithRootRecordID:rootRecordID
                            containerIdentifier:nil
                                       shareURL:shareURL
                                participantType:participantType
                                     permission:permission];
}

- (instancetype)initWithRootRecordID:(CKRecordID *)rootRecordID
                  containerIdentifier:(NSString *)containerIdentifier
                             shareURL:(NSURL *)shareURL
                      participantType:(CKShareParticipantType)participantType
                           permission:(CKShareParticipantPermission)permission
{
    self = [super init];
    if (self) {
        _rootRecordID = [rootRecordID copy];
        _containerIdentifier = [containerIdentifier copy];
        self.shareURL = [shareURL copy];
        _participantType = participantType;
        _participantPermission = permission;
    }
    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<CKShareMetadata: %p; rootRecordID=%@, shareURL=%@, containerIdentifier=%@, ownerIdentity=%@, participantType=%ld, participantPermission=%ld, participantStatus=%ld, participantRole=%ld>",
            self, _rootRecordID, self.shareURL, self.containerIdentifier, self.ownerIdentity, (long)_participantType,
            (long)_participantPermission, (long)_participantStatus, (long)_participantRole];
}

@end
