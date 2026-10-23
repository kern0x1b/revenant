#import "RevenantASHostNames.h"
#import <AuthenticationServices/AuthenticationServices.h>
#import "RevenantASConstruction.h"

@implementation ASAuthorizationController {
    NSArray<ASAuthorizationRequest *> *_authorizationRequests;
}

@synthesize authorizationRequests = _authorizationRequests;

- (instancetype)initWithAuthorizationRequests:(NSArray<ASAuthorizationRequest *> *)authorizationRequests
{
    if ((self = [super init])) {
        _authorizationRequests = [authorizationRequests copy];
    }
    return self;
}

- (NSError *)revenant_error
{
    for (ASAuthorizationRequest *request in _authorizationRequests) {
        if ([request isKindOfClass:[ASAuthorizationAppleIDRequest class]]) {
            return [NSError errorWithDomain:ASAuthorizationErrorDomain code:ASAuthorizationErrorUnknown userInfo:nil];
        }
        if ([request isKindOfClass:[ASAuthorizationPlatformPublicKeyCredentialRegistrationRequest class]] ||
            [request isKindOfClass:[ASAuthorizationPlatformPublicKeyCredentialAssertionRequest class]]) {
            return [NSError errorWithDomain:ASAuthorizationErrorDomain code:ASAuthorizationErrorFailed userInfo:nil];
        }
    }
    return [NSError errorWithDomain:ASAuthorizationErrorDomain code:ASAuthorizationErrorNotHandled userInfo:nil];
}

- (void)revenant_complete
{
    id<ASAuthorizationControllerDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(authorizationController:didCompleteWithError:)]) {
        [delegate authorizationController:self didCompleteWithError:[self revenant_error]];
    }
}

- (void)performRequests
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self revenant_complete];
    });
}

- (void)performAutoFillAssistedRequests
{
    [self performRequests];
}

- (void)performRequestsWithOptions:(ASAuthorizationControllerRequestOptions)options
{
    [self performRequests];
}

- (void)cancel
{
}

@end
