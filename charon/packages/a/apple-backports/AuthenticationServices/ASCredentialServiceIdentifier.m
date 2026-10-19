// ASCredentialServiceIdentifier, of iOS 12.0: which service a stored credential is for, and whether
// that service is named by a domain or by a URL.
//
// **Why the type is part of the value and not a detail.** A credential identity says "this user may
// authenticate into this service", and the system autofill matches on the pair. The same string can be
// a domain (`example.com`) or a URL (`https://example.com`), and the system will not treat the two as
// the same service: a domain is an RFC 1035 name, a URL is an RFC 1738 one, and an application that
// stores a URL where the system expected a domain gets an identity nothing matches. So the identifier
// and the type are set together, both readonly, and a copy carries both.
//
// **What the port does not do.** It does not parse the string to check it against RFC 1035 or RFC 1738,
// because the release does not either — the header says what the type *represents* and leaves the
// conformance to the application that stored it. Inventing a validation the release does not perform
// would refuse identities the system would have kept, which is the worse of the two mistakes.
#import <AuthenticationServices/AuthenticationServices.h>
#import "CharonASConstruction.h"

@implementation ASCredentialServiceIdentifier

@synthesize identifier = _identifier;
@synthesize type = _type;

- (instancetype)initWithIdentifier:(NSString *)identifier type:(ASCredentialServiceIdentifierType)type
{
    // The header does NOT mark this -init unavailable -- it is the public designated initialiser, and
    // only plain -init is unavailable on this class. So this is the release's own construction and the
    // port keeps it as it is.
    self = [super init];
    if (self) {
        _identifier = [identifier copy];
        _type = type;
    }
    return self;
}

- (NSString *)identifier
{
    return [_identifier copy];
}

- (ASCredentialServiceIdentifierType)type
{
    return _type;
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    // Both parts: a copy with the right string and the wrong type is a different service, and an
    // identity stored against it would not match.
    return [[[self class] allocWithZone:zone] initWithIdentifier:_identifier type:_type];
}

#pragma mark - NSSecureCoding

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    return [self initWithIdentifier:[coder decodeObjectOfClass:[NSString class] forKey:@"identifier"]
                               type:(ASCredentialServiceIdentifierType)[coder decodeIntegerForKey:@"type"]];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_identifier forKey:@"identifier"];
    [coder encodeInteger:(NSInteger)_type forKey:@"type"];
}

@end
