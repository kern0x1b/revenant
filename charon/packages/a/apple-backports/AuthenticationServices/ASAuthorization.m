// ASAuthorization, of iOS 13.0: what a finished request returns -- the provider that serviced it and
// the credential it produced.
//
// Two readonly properties and no method, which is the whole of it: an authorization is a pair, and an
// application reads `credential` to find out who signed in and `provider` to find out which provider
// did it. The header marks `-init` and `+new` unavailable, so it is not constructed by an application;
// the controller makes it, and the port's way in is the designated initialiser below.
//
// **Why the two are both here and neither alone.** `ASAuthorizationProvider` is the protocol the
// request side implements and `ASAuthorizationCredential` is the protocol the result side implements,
// and this class is what holds one of each together. The pair is also what makes the credential's
// meaning checkable: a credential whose provider is a different kind than the request that produced it
// is a pairing the framework would not make, and a port that let it through would be handing an
// application a credential from a provider it never asked. Both are held strongly, so a result that is
// held keeps both ends alive, which is what a result is for -- it is handed to a delegate and read there
// after the controller has gone.
#import <AuthenticationServices/AuthenticationServices.h>
#import "CharonASConstruction.h"

@implementation ASAuthorization

@synthesize provider = _provider;
@synthesize credential = _credential;

- (instancetype)charon_initWithProvider:(id<ASAuthorizationProvider>)provider
                              credential:(id<ASAuthorizationCredential>)credential
{
    self = [super init];
    if (self) {
        _provider = provider;
        _credential = credential;
    }
    return self;
}

- (id<ASAuthorizationProvider>)provider
{
    return _provider;
}

- (id<ASAuthorizationCredential>)credential
{
    return _credential;
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    // A copy holds the same pair. The provider and the credential are objects the caller did not create
    // and must not get replaced under it, so they are held as they are rather than copied -- copying an
    // authorization should not produce a second credential that claims the same identity.
    return [[[self class] allocWithZone:zone] charon_initWithProvider:_provider credential:_credential];
}

+ (BOOL)supportsSecureCoding
{
    return NO;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    return [self charon_initWithProvider:nil credential:nil];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
}

@end
