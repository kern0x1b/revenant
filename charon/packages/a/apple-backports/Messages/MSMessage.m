#import <Foundation/Foundation.h>
#import <Messages/MSMessage.h>
#import <Messages/MSMessageLayout.h>
#import <Messages/MSSession.h>

static NSString *const CharonSenderParticipantKey = @"org.charon.apple-backports.MSMessage.senderParticipant";

@implementation MSMessage

@synthesize session = _session;
@synthesize layout = _layout;
@synthesize URL = _URL;
@synthesize shouldExpire = _shouldExpire;
@synthesize accessibilityLabel = _accessibilityLabel;
@synthesize summaryText = _summaryText;
@synthesize error = _error;

- (instancetype)init
{
    if ((self = [super init]))
        _shouldExpire = NO;
    return self;
}

- (instancetype)initWithSession:(MSSession *)session
{
    if ((self = [super init])) {
        _shouldExpire = NO;
        _session = session;
    }
    return self;
}

- (BOOL)isPending
{
    return YES;
}

- (NSUUID *)senderParticipantIdentifier
{
    static NSUUID *identifier;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSString *held = [defaults objectForKey:CharonSenderParticipantKey];
        if (![held isKindOfClass:[NSString class]] || held.length == 0) {
            held = [[NSUUID UUID] UUIDString];
            [defaults setObject:held forKey:CharonSenderParticipantKey];
            [defaults synchronize];
        }
        identifier = [[NSUUID alloc] initWithUUIDString:held];
    });
    return identifier;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeConditionalObject:_session forKey:@"session"];
    [coder encodeObject:_layout forKey:@"layout"];
    [coder encodeObject:_URL forKey:@"URL"];
    [coder encodeBool:_shouldExpire forKey:@"shouldExpire"];
    [coder encodeObject:_accessibilityLabel forKey:@"accessibilityLabel"];
    [coder encodeObject:_summaryText forKey:@"summaryText"];
    [coder encodeObject:_error forKey:@"error"];
    [coder encodeObject:[self senderParticipantIdentifier] forKey:@"senderParticipantIdentifier"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [self init])) {
        _session = [coder decodeObjectOfClass:[MSSession class] forKey:@"session"];
        _layout = [coder decodeObjectOfClass:[MSMessageLayout class] forKey:@"layout"];
        _URL = [coder decodeObjectOfClass:[NSURL class] forKey:@"URL"];
        _shouldExpire = [coder decodeBoolForKey:@"shouldExpire"];
        _accessibilityLabel = [coder decodeObjectOfClass:[NSString class] forKey:@"accessibilityLabel"];
        _summaryText = [coder decodeObjectOfClass:[NSString class] forKey:@"summaryText"];
        _error = [coder decodeObjectOfClass:[NSError class] forKey:@"error"];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    MSMessage *copy = [[[self class] allocWithZone:zone] initWithSession:_session];
    copy->_layout = [_layout copy];
    copy->_URL = [_URL copy];
    copy->_shouldExpire = _shouldExpire;
    copy->_accessibilityLabel = [_accessibilityLabel copy];
    copy->_summaryText = [_summaryText copy];
    copy->_error = [_error copy];
    return copy;
}

- (BOOL)isEqual:(id)other
{
    if (other == self)
        return YES;
    if (![other isKindOfClass:[MSMessage class]])
        return NO;
    MSMessage *message = other;
    return message->_session == _session &&
           [message->_layout isEqual:_layout] &&
           [message->_URL isEqual:_URL] &&
           message->_shouldExpire == _shouldExpire &&
           [message->_accessibilityLabel isEqualToString:_accessibilityLabel] &&
           [message->_summaryText isEqualToString:_summaryText] &&
           [message->_error isEqual:_error];
}

- (NSUInteger)hash
{
    return [_summaryText hash] ^ [_URL hash] ^ [_layout hash] ^ (NSUInteger)_session ^ _shouldExpire;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p> summary=%@ URL=%@ session=%p layout=%@ pending=%d",
            NSStringFromClass([self class]), self, _summaryText, _URL, _session, _layout, [self isPending]];
}

@end
