#import <AuthenticationServices/AuthenticationServices.h>
#import "RevenantASConstruction.h"

@implementation ASAuthorizationOpenIDRequest

@synthesize requestedScopes = _requestedScopes;
@synthesize state = _state;
@synthesize nonce = _nonce;
@synthesize requestedOperation = _requestedOperation;

- (instancetype)init
{
    return [self revenant_initWithProvider:nil];
}

- (instancetype)revenant_initWithProvider:(id<ASAuthorizationProvider>)provider __attribute__((objc_method_family(init)))
{
    self = [super revenant_initWithProvider:provider];
    if (self) {
        _requestedScopes = nil;
        _state = nil;
        _nonce = nil;
        _requestedOperation = nil;
    }
    return self;
}

#pragma mark - the OpenID shape

- (NSArray<ASAuthorizationScope> *)requestedScopes
{
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
    ASAuthorizationOpenIDRequest *copy = [[[self class] allocWithZone:zone] init];
    copy.requestedScopes = _requestedScopes;
    copy.state = _state;
    copy.nonce = _nonce;
    copy.requestedOperation = _requestedOperation;
    return copy;
}

@end
