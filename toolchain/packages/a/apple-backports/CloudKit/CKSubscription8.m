#import <Foundation/Foundation.h>
#import <CloudKit/CloudKit.h>

#import "RevenantCKSubscription.h"

#import "RevenantCKValue.h"

@implementation CKSubscription

- (instancetype)initWithSubscriptionID:(CKSubscriptionID)subscriptionID
{
    self = [super init];
    if (self) {
        _subscriptionID = [subscriptionID copy];
    }
    return self;
}

+ (instancetype)new
{
    [NSException raise:NSInvalidArgumentException
                format:@"You must instantiate one of the CKSubscription subclasses", nil];
    return nil;
}

- (instancetype)init
{
    [NSException raise:NSInvalidArgumentException
                format:@"You must instantiate one of the CKSubscription subclasses", nil];
    return nil;
}

+ (CKSubscriptionType)subscriptionType
{
    return CKNotificationTypeRecordZone;
}

- (CKSubscriptionType)subscriptionType
{
    return [[self class] subscriptionType];
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_subscriptionID forKey:@"subscriptionID"];
    [coder encodeObject:_notificationInfo forKey:@"notificationInfo"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [self initWithSubscriptionID:[coder decodeObjectOfClass:[NSString class] forKey:@"subscriptionID"]];
    if (self) {
        _notificationInfo = [coder decodeObjectOfClass:[CKNotificationInfo class] forKey:@"notificationInfo"];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    CKSubscription *copy = [[CKSubscription allocWithZone:zone] initWithSubscriptionID:_subscriptionID];
    copy.notificationInfo = _notificationInfo;
    return copy;
}

- (BOOL)isEqual:(id)other
{
    if (other == self) {
        return YES;
    }
    if (![other isKindOfClass:[CKSubscription class]]) {
        return NO;
    }
    CKSubscription *subscription = other;
    if (![_subscriptionID isEqualToString:subscription.subscriptionID]) {
        return NO;
    }
    return _notificationInfo == subscription.notificationInfo || [_notificationInfo isEqual:subscription.notificationInfo];
}

- (NSUInteger)hash
{
    return _subscriptionID.hash;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p; subscriptionID=%@, notificationInfo=%@>",
            NSStringFromClass([self class]), self, _subscriptionID, _notificationInfo];
}

@end

#pragma mark - CKNotificationInfo

@implementation CKNotificationInfo

+ (instancetype)notificationInfo
{
    return [[self alloc] init];
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeBool:_shouldSendContentAvailable forKey:@"shouldSendContentAvailable"];
    [coder encodeBool:_shouldSendMutableContent forKey:@"shouldSendMutableContent"];
    [coder encodeBool:_shouldBadge forKey:@"shouldBadge"];
    [coder encodeObject:_desiredKeys forKey:@"desiredKeys"];
    [coder encodeObject:_soundName forKey:@"soundName"];
    [coder encodeObject:_alertBody forKey:@"alertBody"];
    [coder encodeObject:_alertLocalizationKey forKey:@"alertLocalizationKey"];
    [coder encodeObject:_alertLocalizationArgs forKey:@"alertLocalizationArgs"];
    [coder encodeObject:_alertActionLocalizationKey forKey:@"alertActionLocalizationKey"];
    [coder encodeObject:_alertLaunchImage forKey:@"alertLaunchImage"];
    [coder encodeObject:_category forKey:@"category"];
    [coder encodeObject:_title forKey:@"title"];
    [coder encodeObject:_titleLocalizationKey forKey:@"titleLocalizationKey"];
    [coder encodeObject:_titleLocalizationArgs forKey:@"titleLocalizationArgs"];
    [coder encodeObject:_subtitle forKey:@"subtitle"];
    [coder encodeObject:_subtitleLocalizationKey forKey:@"subtitleLocalizationKey"];
    [coder encodeObject:_subtitleLocalizationArgs forKey:@"subtitleLocalizationArgs"];
    [coder encodeObject:_collapseIDKey forKey:@"collapseIDKey"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        _shouldSendContentAvailable = [coder decodeBoolForKey:@"shouldSendContentAvailable"];
        _shouldSendMutableContent = [coder decodeBoolForKey:@"shouldSendMutableContent"];
        _shouldBadge = [coder decodeBoolForKey:@"shouldBadge"];
        _desiredKeys = [[coder decodeObjectOfClass:[NSArray class] forKey:@"desiredKeys"] copy];
        _soundName = [[coder decodeObjectOfClass:[NSString class] forKey:@"soundName"] copy];
        _alertBody = [[coder decodeObjectOfClass:[NSString class] forKey:@"alertBody"] copy];
        _alertLocalizationKey = [[coder decodeObjectOfClass:[NSString class] forKey:@"alertLocalizationKey"] copy];
        _alertLocalizationArgs = [[coder decodeObjectOfClass:[NSArray class] forKey:@"alertLocalizationArgs"] copy];
        _alertActionLocalizationKey = [[coder decodeObjectOfClass:[NSString class] forKey:@"alertActionLocalizationKey"] copy];
        _alertLaunchImage = [[coder decodeObjectOfClass:[NSString class] forKey:@"alertLaunchImage"] copy];
        _category = [[coder decodeObjectOfClass:[NSString class] forKey:@"category"] copy];
        _title = [[coder decodeObjectOfClass:[NSString class] forKey:@"title"] copy];
        _titleLocalizationKey = [[coder decodeObjectOfClass:[NSString class] forKey:@"titleLocalizationKey"] copy];
        _titleLocalizationArgs = [[coder decodeObjectOfClass:[NSArray class] forKey:@"titleLocalizationArgs"] copy];
        _subtitle = [[coder decodeObjectOfClass:[NSString class] forKey:@"subtitle"] copy];
        _subtitleLocalizationKey = [[coder decodeObjectOfClass:[NSString class] forKey:@"subtitleLocalizationKey"] copy];
        _subtitleLocalizationArgs = [[coder decodeObjectOfClass:[NSArray class] forKey:@"subtitleLocalizationArgs"] copy];
        _collapseIDKey = [[coder decodeObjectOfClass:[NSString class] forKey:@"collapseIDKey"] copy];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    CKNotificationInfo *copy = [[CKNotificationInfo allocWithZone:zone] init];
    copy.shouldSendContentAvailable = _shouldSendContentAvailable;
    copy.shouldSendMutableContent = _shouldSendMutableContent;
    copy.shouldBadge = _shouldBadge;
    copy.desiredKeys = _desiredKeys;
    copy.soundName = _soundName;
    copy.alertBody = _alertBody;
    copy.alertLocalizationKey = _alertLocalizationKey;
    copy.alertLocalizationArgs = _alertLocalizationArgs;
    copy.alertActionLocalizationKey = _alertActionLocalizationKey;
    copy.alertLaunchImage = _alertLaunchImage;
    copy.category = _category;
    copy.title = _title;
    copy.titleLocalizationKey = _titleLocalizationKey;
    copy.titleLocalizationArgs = _titleLocalizationArgs;
    copy.subtitle = _subtitle;
    copy.subtitleLocalizationKey = _subtitleLocalizationKey;
    copy.subtitleLocalizationArgs = _subtitleLocalizationArgs;
    copy.collapseIDKey = _collapseIDKey;
    return copy;
}

- (BOOL)isEqual:(id)other
{
    if (other == self) {
        return YES;
    }
    if (![other isKindOfClass:[CKNotificationInfo class]]) {
        return NO;
    }
    CKNotificationInfo *info = other;
    return _shouldSendContentAvailable == info.shouldSendContentAvailable &&
           _shouldSendMutableContent == info.shouldSendMutableContent &&
           _shouldBadge == info.shouldBadge &&
           _collapseIDKey == info.collapseIDKey &&
           RevenantCKSameObjects(_desiredKeys, info.desiredKeys) && RevenantCKSameObjects(_alertLocalizationArgs, info.alertLocalizationArgs) &&
           RevenantCKSameObjects(_titleLocalizationArgs, info.titleLocalizationArgs) &&
           RevenantCKSameObjects(_subtitleLocalizationArgs, info.subtitleLocalizationArgs) &&
           RevenantCKSameObject(_soundName, info.soundName) && RevenantCKSameObject(_alertBody, info.alertBody) &&
           RevenantCKSameObject(_alertLocalizationKey, info.alertLocalizationKey) &&
           RevenantCKSameObject(_alertActionLocalizationKey, info.alertActionLocalizationKey) &&
           RevenantCKSameObject(_alertLaunchImage, info.alertLaunchImage) && RevenantCKSameObject(_category, info.category) &&
           RevenantCKSameObject(_title, info.title) && RevenantCKSameObject(_titleLocalizationKey, info.titleLocalizationKey) &&
           RevenantCKSameObject(_subtitle, info.subtitle) && RevenantCKSameObject(_subtitleLocalizationKey, info.subtitleLocalizationKey);
}

- (NSUInteger)hash
{
    return _soundName.hash ^ _alertBody.hash ^ _title.hash ^ _subtitle.hash;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<CKNotificationInfo: %p; shouldSendContentAvailable=%d, shouldBadge=%d, soundName=%@, alertBody=%@, category=%@>",
            self, _shouldSendContentAvailable, _shouldBadge, _soundName, _alertBody, _category];
}

@end
