#import <Foundation/Foundation.h>
#import <Messages/MSSession.h>

// A session is the identity two messages share so the system can order them as one exchange. It has no
// properties and no methods at all: two sessions are the same session when they are the same object,
// and a message carries the one it was made with. What is here is what the header promises and what
// the release's own machines cannot give: the object is made, kept, compared by identity like any
// NSObject, and archived and unarchived, so an application that persists a message persists the
// session with it and gets the same session back.
//
// What the port cannot do is hand a message to anything. A session becomes a conversation when
// -[MSConversation insertMessage:completionHandler:] is called, and this release has no iMessage
// service, no Messages extension host and no conversation to insert into (see
// facts/Messages/MSMessage.md), so a session is an identity and nothing has ever acted on one.

@implementation MSSession

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    return [super init];
}

- (id)copyWithZone:(NSZone *)zone
{
    // A session is an identity, so a copy is the same session. -copyWithZone: on NSObject would
    // allocate a new object, which would make a copy a different session and break the one thing a
    // session is for.
    return self;
}

- (BOOL)isEqual:(id)other
{
    return other == self;
}

- (NSUInteger)hash
{
    return (NSUInteger)self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p> session", NSStringFromClass([self class]), self];
}

@end
