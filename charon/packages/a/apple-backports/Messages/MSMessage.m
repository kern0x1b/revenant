#import <Foundation/Foundation.h>
#import <Messages/MSMessage.h>
#import <Messages/MSMessageLayout.h>
#import <Messages/MSSession.h>

// The message is the data to be transferred to another device, and every property of it is a value the
// sender set and the receiver reads: the session it belongs to, the URL the payload rides in, the
// layout that draws it, the captions the transcript shows, whether it should expire, and the
// identifier that says who on this device sent it. A value object like this is implemented by keeping
// each value and answering it back - that is the whole of the contract, and it is not the same thing
// as a member that promises a change in the system.
//
// The three members that are not values are the interesting ones:
//
//   -senderParticipantIdentifier is scoped to the device, and the device is the release's own: one
//   NSUUID, generated once and kept in NSUserDefaults, so it is the same on every launch of this
//   device and a different one on every other, which is what the header says of it. The release
//   exports NSUUID (measured in the armv7 6.1.3 cache), so the value is a real one.
//
//   -isPending is YES while a message is unsent. Nothing in the port ever sends one: a message would
//   leave through -[MSConversation insertMessage:completionHandler:], and this release has no
//   conversation, no iMessage service and no Messages extension host to send it to. So the answer is
//   YES, and that is the true one - the message is unsent, because it cannot be otherwise - rather
//   than a flag kept and read by nothing.
//
//   -error is nil, because nothing has failed. A message cannot fail to be sent when no send was ever
//   attempted, and that is the honest reading; -isPending already reports the message's real state.

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

// The header marks both initialisers NS_DESIGNATED_INITIALIZER, so each is its own entry point to
// NSObject's init rather than a convenience on the other.
- (instancetype)initWithSession:(MSSession *)session
{
    if ((self = [super init])) {
        _shouldExpire = NO;
        _session = session;
    }
    return self;
}

// The one answer in this class that is not a value the caller gave. The header defines pending as a
// message that has not been sent, and nothing in the port sends one: a message leaves through
// -[MSConversation insertMessage:completionHandler:], and this release has no conversation, no iMessage
// service and no Messages extension host to insert it into. So YES is the true answer for a message the
// port holds - it is unsent, and it cannot be otherwise - rather than a flag kept for a reader that
// never comes. The day a conversation is carried, this is the line that has to change with it.
- (BOOL)isPending
{
    return YES;
}

- (NSUUID *)senderParticipantIdentifier
{
    // The device's own identifier, made once. A participant identifier that changed on every launch
    // would not identify a participant, and one that was made per message would identify nothing.
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

// -initWithCoder: is a secondary initialiser of a class with two designated ones, so it starts from
// -init rather than from NSObject's, which is what keeps _shouldExpire's default in one place.
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
