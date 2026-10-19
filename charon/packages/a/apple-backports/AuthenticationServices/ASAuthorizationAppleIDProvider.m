// ASAuthorizationAppleIDProvider, of iOS 13.0: the provider a Sign in with Apple request comes from,
// and the object that answers whether an opaque user identifier is still good.
//
// **This is the class that makes a request makeable.** `ASAuthorizationRequest`'s header marks `-init`
// and `+new` NS_UNAVAILABLE because a request is not constructed: it comes from a provider, and this is
// the provider for Apple ID. The host's own answers that path with no daemon, no network and no UI --
// `[[ASAuthorizationAppleIDProvider alloc] init] createRequest` returns a real
// `ASAuthorizationAppleIDRequest` -- which is what the value differential runs both sides through, so
// the port and the host are asked the same question the same way.
//
// **What the port answers to the credential state, and why it is not "authorized".** The state is
// Apple's own knowledge of whether an opaque user identifier was revoked, and this port has no line to
// Apple's servers and no account to ask with. What it *does* have is the truth about itself: it has
// never seen an Apple ID, so for any identifier it is handed the honest answer is
// `ASAuthorizationAppleIDProviderCredentialNotFound` -- and the header says that state arrives with an
// error, so the error is produced too, in `ASAuthorizationErrorDomain`. Answering "authorized" to a
// question about a revocation the port cannot see would have an application keep sending tokens for an
// identifier the user had revoked; "not found" tells it to sign the user in again, which is what is
// true.
#import <AuthenticationServices/AuthenticationServices.h>
#import "CharonASConstruction.h"

@implementation ASAuthorizationAppleIDProvider

- (instancetype)charon_initWithCredentialState:(id)store
{
    // The parameter is where a port that could answer getCredentialStateForUserID: would keep what it
    // knows; this port has nothing to keep, so it is accepted and held unused rather than invented. What
    // the release's own class list has, measured on macOS 27.0, is initWithProvider:, initWithCoder:,
    // init, .cxx_destruct, copyWithZone:, encodeWithCoder: and supportsStyle: -- and the header keeps
    // only createRequest and getCredentialStateForUserID:completion:.
    (void)store;
    self = [super init];
    return self;
}

- (ASAuthorizationAppleIDRequest *)createRequest
{
    // A fresh Apple ID request, and fresh is a shape rather than an absence: the host's own provider
    // hands out one whose scopes, state, nonce and requestedOperation are all nil, and the port's does
    // the same. The differential checks that, and the header's nullable properties are what it holds
    // against.
    // Through the port's own construction, not -init: the request's own header does not mark -init
    // unavailable, but its BASE's does, and the compiler reads the base's mark for the subclass too --
    // so a port class cannot construct another of its own classes by -init. The request is made the
    // way the release makes it, from a provider, and the port is that provider.
    return [[ASAuthorizationAppleIDRequest alloc] charon_initWithProvider:self];
}

- (id)copyWithZone:(NSZone *)zone
{
    // A provider holds no per-request state, so a copy is the same provider; and the release's own
    // class list has copyWithZone: because the protocol requires it, not because there is anything in
    // it yet.
    return [[[self class] allocWithZone:zone] charon_initWithCredentialState:nil];
}

- (void)getCredentialStateForUserID:(NSString *)userID completion:(void (^)(ASAuthorizationAppleIDProviderCredentialState credentialState, NSError * _Nullable error))completion
{
    // NotFound, with the error the header says that state arrives with. This port has never seen an
    // Apple ID, so for any identifier it is handed that is the truth, and "authorized" would not be:
    // it is a claim about a revocation this port cannot see, and an application acting on it would keep
    // sending tokens for an identifier the user had revoked. NotFound tells it to sign in again.
    if (!completion)
        return;
    if (!userID) {
        completion(ASAuthorizationAppleIDProviderCredentialNotFound,
                   [NSError errorWithDomain:ASAuthorizationErrorDomain
                                       code:ASAuthorizationErrorInvalidResponse
                                   userInfo:nil]);
        return;
    }
    completion(ASAuthorizationAppleIDProviderCredentialNotFound,
               [NSError errorWithDomain:ASAuthorizationErrorDomain
                                   code:ASAuthorizationErrorInvalidResponse
                               userInfo:@{NSLocalizedDescriptionKey: @"this port has never seen an Apple ID"}]);
}

+ (BOOL)supportsSecureCoding
{
    return NO;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    return [self charon_initWithCredentialState:nil];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
}

@end
