// ASAuthorizationRequest, of iOS 13.0: the base every AuthenticationServices request is.
//
// **The template for the rest of this family.** Every request class below this one -- the Apple ID
// request, the passkey registration and assertion requests, the SSO request -- is a subclass with two
// or three more members and nothing else, so what is here is the shape they all share and the way each
// of them is made: a provider, a copy, and a coder.
//
// **What the host says, measured.** macOS 27.0's own AuthenticationServices has the class, and this is
// what it answers: `-provider` exists, the class adopts NSCopying and NSSecureCoding (`-copyWithZone:`,
// `-encodeWithCoder:`, `-initWithCoder:`), and the class list holds eight instance methods:
// `provider`, `initWithProvider:`, `initWithCoder:`, `init`, `.cxx_destruct`, `copyWithZone:`,
// `encodeWithCoder:` and `supportsStyle:`. `initWithProvider:` is the release's own way in and is not
// in the public header, so the port's construction is named and declared in
// CharonASConstruction.h rather than reaching for a private selector.
//
// **The provider is a strong reference and is kept as one.** It is the object that services the
// request, it is what the controller asks when it runs the request, and a request that outlived its
// provider would be a request nothing can service.
#import <AuthenticationServices/AuthenticationServices.h>
#import "CharonASConstruction.h"

// The key -encodeWithCoder: and -initWithCoder: use for the provider. It is the port's own: the
// release's coder key is not in the public header, and a key two implementations choose differently is
// a key neither can read. File-local: nothing else reads it, and a global would be API no release named.
static NSString *const ASCharonProviderCodingKey = @"org.charon.authservices.provider";

@implementation ASAuthorizationRequest

@synthesize provider = _provider;

- (instancetype)charon_initWithProvider:(id<ASAuthorizationProvider>)provider
{
    self = [super init];
    if (self)
        _provider = provider;
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    // The provider is an object the caller supplies, and a coder is text or bytes; the release's own
    // coder takes it through the same object reference a copy does. A decoded request with no
    // provider is a request that cannot be run, and the caller is told so by the nil it gets back.
    self = [super init];
    if (self) {
        id provider = nil;
        if ([coder respondsToSelector:@selector(decodeObjectForKey:)]) {
            id decoded = [coder decodeObjectOfClass:[NSObject class] forKey:ASCharonProviderCodingKey];
            if (decoded)
                provider = decoded;
        }
        _provider = provider;
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    // The provider is not a value the coder can carry across a process boundary in any form the port
    // can promise, so the key is written only when there is one, and a round trip of a request without
    // a provider gives a request without one. That is the honest behaviour, and it is why -provider is
    // documented above as what a caller re-supplies rather than as something an archive restores.
    if (_provider && [coder respondsToSelector:@selector(encodeObject:forKey:)])
        [coder encodeObject:_provider forKey:ASCharonProviderCodingKey];
}

- (id<ASAuthorizationProvider>)provider
{
    return _provider;
}

+ (BOOL)supportsSecureCoding
{
    return NO;
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    // A copy is the same request with the same provider: the members a subclass adds are its own to
    // copy, and the base copies only what the base holds.
    ASAuthorizationRequest *copy = [[[self class] allocWithZone:zone] charon_initWithProvider:_provider];
    return copy;
}

@end
