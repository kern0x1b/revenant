// ASAuthorizationOpenIDRequest, of iOS 13.0: the OpenID-shaped request that Sign in with Apple and
// every other OpenID provider's request is.
//
// **The template's first subclass, and the first place the two header shapes differ.** Its superclass
// marks -init and +new NS_UNAVAILABLE; its own header does not, and the host's own class list for it
// (macOS 27.0, measured by tests/backports/host/authservices) has eleven instance methods including
// `init` and the four accessors this class owns:
//
//     nonce  setNonce:  state  setState:  requestedOperation  setRequestedOperation:
//     requestedScopes  setRequestedScopes:  init  .cxx_destruct  supportsStyle:
//
// `supportsStyle:` is the release's own and is not in the header, so it is not asked about: a private
// method is not a claim. `init` **is** asked about here and is bound here, because this header asks for
// it -- which is the distinction the check's must-be-unavailable state exists to draw, and the
// superclass is the other side of it.
//
// **What a fresh request holds**, measured on the host through the path a request is meant to come
// from -- `[[ASAuthorizationAppleIDProvider alloc] init] createRequest`, which needs no daemon, no
// network and no UI:

//     requestedScopes    nil
//     state              nil
//     nonce              nil
//     requestedOperation nil      <- not the implicit operation, and not an NSString
//     user               nil

// and its copy, with the first three set beforehand, carries all three. The `requestedOperation` being
// nil is the one that changes this class: the header types it non-nullable and the release leaves it
// nil, so the port leaves it nil too.
#import <AuthenticationServices/AuthenticationServices.h>
#import "CharonASConstruction.h"

@implementation ASAuthorizationOpenIDRequest

@synthesize requestedScopes = _requestedScopes;
@synthesize state = _state;
@synthesize nonce = _nonce;
@synthesize requestedOperation = _requestedOperation;

// This header does not mark -init unavailable and the release's own construction is -init, so it
// stays. It is a NAME for -charon_initWithProvider: rather than a second place the default is set: the
// port's provider builds its request through the construction, and a default that also lived here was a
// line nothing reached -- which is why a mutation of it changed nothing and the differential was
// agreeing with the host by accident.
- (instancetype)init
{
    return [self charon_initWithProvider:nil];
}

// The construction the provider uses, and the ONE place the four defaults are set. It was in -init, and
// -init is not what -charon_initWithProvider: calls -- the base marks -init unavailable and the compiler
// reads the base's mark for a subclass -- so the defaults were never applied on the path a real request
// takes, and a mutation of the line changed nothing: the differential was agreeing with the host by
// accident. The defaults are here because this is where the object is made.
- (instancetype)charon_initWithProvider:(id<ASAuthorizationProvider>)provider __attribute__((objc_method_family(init)))
{
    self = [super charon_initWithProvider:provider];
    if (self) {
        _requestedScopes = nil;
        _state = nil;
        _nonce = nil;
        // nil, and this is a measurement rather than a reading of the header: the host's own provider
        // hands out a request whose requestedOperation is nil, asked on macOS 27.0 through
        // [[ASAuthorizationAppleIDProvider alloc] init] createRequest. The header types the property
        // non-nullable and the release leaves it nil, and the port follows the release.
        _requestedOperation = nil;
    }
    return self;
}

#pragma mark - the OpenID shape

- (NSArray<ASAuthorizationScope> *)requestedScopes
{
    // A copy on the way out as well as on the way in: the scopes are what the request asks for and
    // nothing should be able to change them between the request and the provider reading them.
    return [_requestedScopes copy];
}

- (void)setRequestedScopes:(NSArray<ASAuthorizationScope> *)requestedScopes
{
    _requestedScopes = [requestedScopes copy];
}

- (NSString *)state
{
    return [_state copy];
}

- (void)setState:(NSString *)state
{
    _state = [state copy];
}

- (NSString *)nonce
{
    return [_nonce copy];
}

- (void)setNonce:(NSString *)nonce
{
    _nonce = [nonce copy];
}

- (ASAuthorizationOpenIDOperation)requestedOperation
{
    return [_requestedOperation copy];
}

- (void)setRequestedOperation:(ASAuthorizationOpenIDOperation)requestedOperation
{
    _requestedOperation = [requestedOperation copy];
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    // A copy of an OpenID request is the same request: the same provider, the same scopes, the same
    // state, the same nonce and the same operation. A request's identity is what it asks the provider
    // for, and a copy that quietly changed one of those would be a different request wearing the same
    // object's memory.
    ASAuthorizationOpenIDRequest *copy = [[[self class] allocWithZone:zone] init];
    copy.requestedScopes = _requestedScopes;
    copy.state = _state;
    copy.nonce = _nonce;
    copy.requestedOperation = _requestedOperation;
    return copy;
}

@end
