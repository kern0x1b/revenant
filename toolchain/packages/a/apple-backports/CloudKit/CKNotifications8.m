#import <Foundation/Foundation.h>
#import <CloudKit/CloudKit.h>

#import "RevenantCKValue.h"

#pragma mark - CKNotificationID

@implementation CKNotificationID
{
    NSString *_name;
    id _object;
}

- (instancetype)initWithNotificationName:(NSString *)notificationName object:(id)object
{
    self = [super init];
    if (self) {
        _name = [notificationName copy];
        _object = object;
    }
    return self;
}

+ (instancetype)notificationIDWithNotificationName:(NSString *)notificationName object:(id)object
{
    return [[self alloc] initWithNotificationName:notificationName object:object];
}

+ (instancetype)new
{
    return [[self alloc] initWithNotificationName:nil object:nil];
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_name forKey:@"notificationName"];
    [coder encodeObject:_object forKey:@"object"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    return [self initWithNotificationName:[coder decodeObjectOfClass:[NSString class] forKey:@"notificationName"]
                                    object:nil];
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[CKNotificationID allocWithZone:zone] initWithNotificationName:_name object:_object];
}

- (BOOL)isEqual:(id)other
{
    if (other == self) {
        return YES;
    }
    if (![other isKindOfClass:[CKNotificationID class]]) {
        return NO;
    }
    return RevenantCKSameObject(_name, ((CKNotificationID *)other)->_name);
}

- (NSUInteger)hash
{
    return _name.hash;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<CKNotificationID: %p; name=%@, object=%@>", self, _name, _object];
}

@end

#pragma mark - CKNotification

@interface CKNotification ()
@property (nonatomic, copy, nullable) NSString *alertBody;
@property (nonatomic, copy, nullable) NSString *alertLocalizationKey;
@property (nonatomic, copy, nullable) NSArray<NSString *> *alertLocalizationArgs;
@property (nonatomic, copy, nullable) NSString *alertActionLocalizationKey;
@property (nonatomic, copy, nullable) NSString *alertLaunchImage;
@property (nonatomic, copy, nullable) NSNumber *badge;
@property (nonatomic, copy, nullable) NSString *soundName;
@property (nonatomic, copy, nullable) NSString *category;
@property (nonatomic, copy, nullable) NSString *title;
@property (nonatomic, copy, nullable) NSString *titleLocalizationKey;
@property (nonatomic, copy, nullable) NSArray<NSString *> *titleLocalizationArgs;
@property (nonatomic, copy, nullable) NSString *subtitle;
@property (nonatomic, copy, nullable) NSString *subtitleLocalizationKey;
@property (nonatomic, copy, nullable) NSArray<NSString *> *subtitleLocalizationArgs;
@property (nonatomic, copy, nullable) CKNotificationID *notificationID;
@end
@interface CKNotification ()
@end

@implementation CKNotification

{
    CKRecordID *_subscriptionOwnerUserRecordID;
    NSString *_recordChangeTag;
    NSDate *_creationDate;
    NSDate *_modificationDate;
    CKRecordID *_creatorUserRecordID;
    CKRecordID *_lastModifiedUserRecordID;
    BOOL _isPruned;
}


@synthesize alertBody = _alertBody;
@synthesize alertLocalizationKey = _alertLocalizationKey;
@synthesize alertLocalizationArgs = _alertLocalizationArgs;
@synthesize alertActionLocalizationKey = _alertActionLocalizationKey;
@synthesize alertLaunchImage = _alertLaunchImage;
@synthesize badge = _badge;
@synthesize soundName = _soundName;
@synthesize category = _category;
@synthesize title = _title;
@synthesize titleLocalizationKey = _titleLocalizationKey;
@synthesize titleLocalizationArgs = _titleLocalizationArgs;
@synthesize subtitle = _subtitle;
@synthesize subtitleLocalizationKey = _subtitleLocalizationKey;
@synthesize subtitleLocalizationArgs = _subtitleLocalizationArgs;
@synthesize notificationID = _notificationID;
+ (instancetype)notificationFromRemoteNotificationDictionary:(NSDictionary *)userInfo
{
    CKNotification *notification = [[self alloc] initWithUserInfo:userInfo];
    return notification;
}

+ (NSString *)RevenantCKIdentifierInUserInfo:(NSDictionary *)userInfo
{
    NSDictionary *notification = [userInfo[@"ck-notification"] isKindOfClass:[NSDictionary class]] ? userInfo[@"ck-notification"] : nil;
    return [notification[@"ck-notification-id"] isKindOfClass:[NSString class]] ? notification[@"ck-notification-id"] : nil;
}

- (instancetype)initWithUserInfo:(NSDictionary *)userInfo
{
    self = [super init];
    if (self) {
        [self readUserInfo:userInfo];
    }
    return self;
}

+ (instancetype)new
{
    [NSException raise:NSInvalidArgumentException format:@"CKNotification is not meant for direct instantiation", nil];
    return nil;
}

- (instancetype)init
{
    [NSException raise:NSInvalidArgumentException format:@"CKNotification is not meant for direct instantiation", nil];
    return nil;
}

+ (CKNotificationType)notificationType
{
    return CKNotificationTypeQuery;
}

- (CKNotificationType)notificationType
{
    return [[self class] notificationType];
}

- (void)readUserInfo:(NSDictionary *)userInfo
{
    if (![userInfo isKindOfClass:[NSDictionary class]]) {
        return;
    }
    NSDictionary *aps = [userInfo[@"aps"] isKindOfClass:[NSDictionary class]] ? userInfo[@"aps"] : nil;
    _containerIdentifier = [userInfo[@"ck-container"] copy];
    NSDictionary *notification = [userInfo[@"ck-notification"] isKindOfClass:[NSDictionary class]] ? userInfo[@"ck-notification"] : nil;
    NSString *identifier = [CKNotification RevenantCKIdentifierInUserInfo:userInfo];
    if (identifier) {
        self.notificationID = [[CKNotificationID alloc] initWithNotificationName:identifier object:nil];
    }
    if (aps) {
        NSDictionary *alert = [aps[@"alert"] isKindOfClass:[NSDictionary class]] ? aps[@"alert"] : nil;
        if (alert) {
            _alertBody = [alert[@"body"] copy];
            _alertLocalizationKey = [alert[@"loc-key"] copy];
            _alertLocalizationArgs = [alert[@"loc-args"] copy];
            _alertActionLocalizationKey = [alert[@"action-loc-key"] copy];
            _title = [alert[@"title"] copy];
            _titleLocalizationKey = [alert[@"title-loc-key"] copy];
            _titleLocalizationArgs = [alert[@"title-loc-args"] copy];
            _subtitle = [alert[@"subtitle"] copy];
            _subtitleLocalizationKey = [alert[@"subtitle-loc-key"] copy];
            _subtitleLocalizationArgs = [alert[@"subtitle-loc-args"] copy];
        }
        _badge = [aps[@"badge"] copy];
        _soundName = [aps[@"sound"] copy];
        _category = [aps[@"category"] copy];
    }
    _subscriptionID = [notification[@"ck-subscription-id"] copy];
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_notificationID forKey:@"notificationID"];
    [coder encodeObject:_containerIdentifier forKey:@"containerIdentifier"];
    [coder encodeObject:_subscriptionID forKey:@"subscriptionID"];
    [coder encodeObject:_subscriptionOwnerUserRecordID forKey:@"subscriptionOwnerUserRecordID"];
    [coder encodeObject:_alertBody forKey:@"alertBody"];
    [coder encodeObject:_alertLocalizationKey forKey:@"alertLocalizationKey"];
    [coder encodeObject:_alertLocalizationArgs forKey:@"alertLocalizationArgs"];
    [coder encodeObject:_alertActionLocalizationKey forKey:@"alertActionLocalizationKey"];
    [coder encodeObject:_alertLaunchImage forKey:@"alertLaunchImage"];
    [coder encodeObject:_badge forKey:@"badge"];
    [coder encodeObject:_soundName forKey:@"soundName"];
    [coder encodeObject:_category forKey:@"category"];
    [coder encodeObject:_title forKey:@"title"];
    [coder encodeObject:_titleLocalizationKey forKey:@"titleLocalizationKey"];
    [coder encodeObject:_titleLocalizationArgs forKey:@"titleLocalizationArgs"];
    [coder encodeObject:_subtitle forKey:@"subtitle"];
    [coder encodeObject:_subtitleLocalizationKey forKey:@"subtitleLocalizationKey"];
    [coder encodeObject:_subtitleLocalizationArgs forKey:@"subtitleLocalizationArgs"];
    [coder encodeBool:_isPruned forKey:@"isPruned"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        self.notificationID = [coder decodeObjectOfClass:[CKNotificationID class] forKey:@"notificationID"];
        _containerIdentifier = [[coder decodeObjectOfClass:[NSString class] forKey:@"containerIdentifier"] copy];
        _subscriptionID = [[coder decodeObjectOfClass:[NSString class] forKey:@"subscriptionID"] copy];
        _subscriptionOwnerUserRecordID = [coder decodeObjectOfClass:[CKRecordID class] forKey:@"subscriptionOwnerUserRecordID"];
        _alertBody = [[coder decodeObjectOfClass:[NSString class] forKey:@"alertBody"] copy];
        _alertLocalizationKey = [[coder decodeObjectOfClass:[NSString class] forKey:@"alertLocalizationKey"] copy];
        _alertLocalizationArgs = [[coder decodeObjectOfClass:[NSArray class] forKey:@"alertLocalizationArgs"] copy];
        _alertActionLocalizationKey = [[coder decodeObjectOfClass:[NSString class] forKey:@"alertActionLocalizationKey"] copy];
        _alertLaunchImage = [[coder decodeObjectOfClass:[NSString class] forKey:@"alertLaunchImage"] copy];
        _badge = [[coder decodeObjectOfClass:[NSNumber class] forKey:@"badge"] copy];
        _soundName = [[coder decodeObjectOfClass:[NSString class] forKey:@"soundName"] copy];
        _category = [[coder decodeObjectOfClass:[NSString class] forKey:@"category"] copy];
        _title = [[coder decodeObjectOfClass:[NSString class] forKey:@"title"] copy];
        _titleLocalizationKey = [[coder decodeObjectOfClass:[NSString class] forKey:@"titleLocalizationKey"] copy];
        _titleLocalizationArgs = [[coder decodeObjectOfClass:[NSArray class] forKey:@"titleLocalizationArgs"] copy];
        _subtitle = [[coder decodeObjectOfClass:[NSString class] forKey:@"subtitle"] copy];
        _subtitleLocalizationKey = [[coder decodeObjectOfClass:[NSString class] forKey:@"subtitleLocalizationKey"] copy];
        _subtitleLocalizationArgs = [[coder decodeObjectOfClass:[NSArray class] forKey:@"subtitleLocalizationArgs"] copy];
        _isPruned = [coder decodeBoolForKey:@"isPruned"];
    }
    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p; notificationID=%@, containerIdentifier=%@, subscriptionID=%@, subscriptionOwnerUserRecordID=%@, badge=%@, soundName=%@, alertBody=%@, category=%@, title=%@, subtitle=%@, isPruned=%d>",
            NSStringFromClass([self class]), self, _notificationID, _containerIdentifier, _subscriptionID,
            _subscriptionOwnerUserRecordID, _badge, _soundName, _alertBody, _category, _title, _subtitle, _isPruned];
}

@end

#pragma mark - CKQueryNotification

@implementation CKQueryNotification

- (instancetype)initWithUserInfo:(NSDictionary *)userInfo
{
    return [super initWithUserInfo:userInfo];
}

- (CKQueryNotificationReason)queryNotificationReason
{
    return CKQueryNotificationReasonRecordCreated;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<CKQueryNotification: %p; databaseScope=%ld, notificationID=%@, recordID=%@, recordFields=%@, queryNotificationReason=%ld>",
            self, (long)_databaseScope, self.notificationID, _recordID, _recordFields, (long)self.queryNotificationReason];
}

@end

#pragma mark - CKRecordZoneNotification

@implementation CKRecordZoneNotification

- (instancetype)initWithUserInfo:(NSDictionary *)userInfo
{
    return [super initWithUserInfo:userInfo];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<CKRecordZoneNotification: %p; databaseScope=%ld, notificationID=%@, recordZoneID=%@>",
            self, (long)_databaseScope, self.notificationID, _recordZoneID];
}

@end
