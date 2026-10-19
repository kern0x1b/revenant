#import "CharonUserNotifications.h"

@implementation UNNotificationRequest {
@private
    NSString *_identifier;
    UNNotificationContent *_content;
    UNNotificationTrigger *_trigger;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

+ (instancetype)requestWithIdentifier:(NSString *)identifier content:(UNNotificationContent *)content
                              trigger:(UNNotificationTrigger *)trigger
{
    return [[self alloc] initCharonWithIdentifier:identifier content:content trigger:trigger];
}

- (instancetype)initCharonWithIdentifier:(NSString *)identifier content:(UNNotificationContent *)content
                                  trigger:(UNNotificationTrigger *)trigger
{
    NSAssert(identifier != nil, @"Invalid parameter not satisfying: %@", @"identifier != nil");
    if ((self = [super init])) {
        _identifier = [identifier copy];
        _content = [content copy];
        _trigger = [trigger copy];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    // A location trigger joins the two by name rather than by symbol: Apple's own header marks
    // UNLocationNotificationTrigger unavailable on macOS and Mac Catalyst, so a source that named it
    // would not compile for the host differential - and on the release the port deploys on, the
    // class this finds is the port's own.
    NSMutableSet *triggers = [NSMutableSet setWithObjects:[UNTimeIntervalNotificationTrigger class],
                                                        [UNCalendarNotificationTrigger class], nil];
    Class location = NSClassFromString(@"UNLocationNotificationTrigger");
    if (location)
        [triggers addObject:location];
    return [self initCharonWithIdentifier:[coder decodeObjectOfClass:[NSString class] forKey:@"identifier"] ?: @""
                                   content:[coder decodeObjectOfClass:[UNNotificationContent class] forKey:@"content"]
                                   trigger:[coder decodeObjectOfClasses:triggers forKey:@"trigger"]];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_identifier forKey:@"identifier"];
    [coder encodeObject:_content forKey:@"content"];
    [coder encodeObject:_trigger forKey:@"trigger"];
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (NSString *)identifier
{
    return _identifier;
}

- (UNNotificationContent *)content
{
    return _content;
}

- (UNNotificationTrigger *)trigger
{
    return _trigger;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    if (![object isKindOfClass:[UNNotificationRequest class]])
        return NO;
    UNNotificationRequest *other = object;
    return [_identifier isEqual:other.identifier] && (_content == other.content || [_content isEqual:other.content])
        && (_trigger == other.trigger || [_trigger isEqual:other.trigger]);
}

- (NSUInteger)hash
{
    return _identifier.hash ^ _content.hash ^ _trigger.hash;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p; identifier: %@, content: %@, trigger: %@>", [self class], self,
                                      _identifier, _content, _trigger];
}

@end

@implementation UNNotification {
@private
    UNNotificationRequest *_request;
    NSDate *_date;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

+ (instancetype)notificationWithRequest:(UNNotificationRequest *)request date:(NSDate *)date
{
    return [[self alloc] initCharonWithRequest:request date:date];
}

- (instancetype)initCharonWithRequest:(UNNotificationRequest *)request date:(NSDate *)date
{
    if ((self = [super init])) {
        _request = [request copy];
        _date = [date copy];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    return [self initCharonWithRequest:[coder decodeObjectOfClass:[UNNotificationRequest class] forKey:@"request"]
                                   date:[coder decodeObjectOfClass:[NSDate class] forKey:@"date"]];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_request forKey:@"request"];
    [coder encodeObject:_date forKey:@"date"];
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (UNNotificationRequest *)request
{
    return _request;
}

- (NSDate *)date
{
    return _date;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    return [object isKindOfClass:[UNNotification class]] && [_request isEqual:[object request]]
        && (_date == [object date] || [_date isEqual:[object date]]);
}

- (NSUInteger)hash
{
    return _request.hash ^ _date.hash;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p; date: %@, request: %@>", [self class], self, _date, _request];
}

@end

@implementation UNNotificationResponse {
@private
    UNNotification *_notification;
    NSString *_actionIdentifier;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

+ (instancetype)responseWithNotification:(UNNotification *)notification actionIdentifier:(NSString *)actionIdentifier
{
    return [[self alloc] initCharonWithNotification:notification actionIdentifier:actionIdentifier];
}

- (instancetype)initCharonWithNotification:(UNNotification *)notification actionIdentifier:(NSString *)actionIdentifier
{
    if ((self = [super init])) {
        _notification = [notification copy];
        _actionIdentifier = [actionIdentifier copy];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    return [self initCharonWithNotification:[coder decodeObjectOfClass:[UNNotification class] forKey:@"notification"]
                            actionIdentifier:[coder decodeObjectOfClass:[NSString class] forKey:@"actionIdentifier"]];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_notification forKey:@"notification"];
    [coder encodeObject:_actionIdentifier forKey:@"actionIdentifier"];
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (UNNotification *)notification
{
    return _notification;
}

- (NSString *)actionIdentifier
{
    return _actionIdentifier;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    return [object isKindOfClass:[UNNotificationResponse class]] && [_notification isEqual:[object notification]]
        && [_actionIdentifier isEqual:[object actionIdentifier]];
}

- (NSUInteger)hash
{
    return _notification.hash ^ _actionIdentifier.hash;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p; actionIdentifier: %@, notification: %@>", [self class], self,
                                      _actionIdentifier, _notification];
}

@end

NSString *const UNNotificationDefaultActionIdentifier = @"com.apple.UNNotificationDefaultActionIdentifier";
NSString *const UNNotificationDismissActionIdentifier = @"com.apple.UNNotificationDismissActionIdentifier";
NSString *const UNErrorDomain = @"UNErrorDomain";

@implementation UNTextInputNotificationResponse {
@private
    NSString *_userText;
}

+ (instancetype)responseWithNotification:(UNNotification *)notification actionIdentifier:(NSString *)actionIdentifier userText:(NSString *)userText
{
    return [[self alloc] initCharonWithNotification:notification actionIdentifier:actionIdentifier userText:userText];
}

- (instancetype)initCharonWithNotification:(UNNotification *)notification actionIdentifier:(NSString *)actionIdentifier userText:(NSString *)userText
{
    if ((self = [super initCharonWithNotification:notification actionIdentifier:actionIdentifier]))
        _userText = [userText copy];
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super initWithCoder:coder]))
        _userText = [coder decodeObjectOfClass:[NSString class] forKey:@"userText"];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    [coder encodeObject:_userText forKey:@"userText"];
}

- (NSString *)userText
{
    return _userText;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    return [object isKindOfClass:[UNTextInputNotificationResponse class]] && [super isEqual:object]
        && (_userText == [object userText] || [_userText isEqual:[object userText]]);
}

- (NSUInteger)hash
{
    return [super hash] ^ _userText.hash;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p; actionIdentifier: %@, userText: %@, notification: %@>", [self class], self, [self actionIdentifier],
                                      _userText, [self notification]];
}

@end
