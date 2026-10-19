// ASPasswordCredentialIdentity, of iOS 12.0: one stored credential -- who may sign in to which
// service, and in what order the system should offer them.
//
// **This is the thing a password manager writes down.** An application calls
// `+[ASCredentialIdentityStore saveCredentialIdentities:completion:]` with these, and the system
// autofill offers them; that is why the class exists and why every part of it is a value the system
// reads later rather than a handle to something running.
//
// **The two identifiers and the rank, and why each is there.** `serviceIdentifier` says which service
// the credential is for, and `user` says who in it -- the pair is what autofill matches on, and a
// credential with the right user and the wrong service is offered in the wrong place.
// `recordIdentifier` is the application's own handle for the row in its own database, and the header
// says the system never interprets it, so the port stores and returns it and nothing else.
// `rank` is the one writable property: where two identities share a service identifier, the larger rank
// is offered first, and the default is 0. It is the only ordering the system applies, and the header
// says so, so the port does not invent a second one.
//
// **The designated initialiser is the release's own**, and only plain `-init` is unavailable here -- the
// same as `ASCredentialServiceIdentifier` and the opposite of the request classes, where the base marks
// both and a subclass cannot be constructed by `-init` at all.
#import <AuthenticationServices/AuthenticationServices.h>
#import "CharonASConstruction.h"

@implementation ASPasswordCredentialIdentity

@synthesize serviceIdentifier = _serviceIdentifier;
@synthesize user = _user;
@synthesize recordIdentifier = _recordIdentifier;
@synthesize rank = _rank;

- (instancetype)initWithServiceIdentifier:(ASCredentialServiceIdentifier *)serviceIdentifier
                                    user:(NSString *)user
                        recordIdentifier:(NSString *)recordIdentifier
{
    // The release's own designated initialiser, kept as it is: this class marks only plain -init
    // unavailable. The port holds the two non-null parts and leaves the record identifier nil when
    // there is none, which is what the header's nullable says.
    self = [super init];
    if (self) {
        _serviceIdentifier = serviceIdentifier;
        _user = [user copy];
        _recordIdentifier = [recordIdentifier copy];
        _rank = 0;
    }
    return self;
}

+ (instancetype)identityWithServiceIdentifier:(ASCredentialServiceIdentifier *)serviceIdentifier
                                        user:(NSString *)user
                            recordIdentifier:(NSString *)recordIdentifier
{
    return [[self alloc] initWithServiceIdentifier:serviceIdentifier user:user recordIdentifier:recordIdentifier];
}

- (ASCredentialServiceIdentifier *)serviceIdentifier
{
    return _serviceIdentifier;
}

- (NSString *)user
{
    return [_user copy];
}

- (NSString *)recordIdentifier
{
    return [_recordIdentifier copy];
}

- (NSInteger)rank
{
    return _rank;
}

- (void)setRank:(NSInteger)rank
{
    // The one writable property, and the header names the default as 0, so a fresh identity is at 0
    // and an application that wants it offered first says so here. Nothing is clamped: the header does
    // not give a range, and refusing a value the release would have taken is a difference in behaviour.
    _rank = rank;
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    // The three values and the rank. A copy at a different rank is a different offering, so the rank
    // travels with it rather than resetting to the default.
    ASPasswordCredentialIdentity *copy = [[[self class] allocWithZone:zone] initWithServiceIdentifier:_serviceIdentifier
                                                                                    user:_user
                                                                        recordIdentifier:_recordIdentifier];
    copy.rank = _rank;
    return copy;
}

#pragma mark - NSSecureCoding

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    // The service identifier is a class, so it is decoded as one rather than as a plain object: the
    // system compares service identifiers by value, and a decoded object that is not the right class
    // would compare unequal to every one of them.
    self = [self initWithServiceIdentifier:[coder decodeObjectOfClass:[ASCredentialServiceIdentifier class]
                                                              forKey:@"serviceIdentifier"]
                                      user:[coder decodeObjectOfClass:[NSString class] forKey:@"user"]
                          recordIdentifier:[coder decodeObjectOfClass:[NSString class] forKey:@"recordIdentifier"]];
    if (self)
        _rank = [coder decodeIntegerForKey:@"rank"];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_serviceIdentifier forKey:@"serviceIdentifier"];
    [coder encodeObject:_user forKey:@"user"];
    [coder encodeObject:_recordIdentifier forKey:@"recordIdentifier"];
    [coder encodeInteger:(NSInteger)_rank forKey:@"rank"];
}

@end
