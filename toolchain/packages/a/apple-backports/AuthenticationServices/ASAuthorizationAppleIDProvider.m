#import <AuthenticationServices/AuthenticationServices.h>
#import "RevenantASConstruction.h"

@implementation ASAuthorizationAppleIDProvider

- (instancetype)revenant_initWithCredentialState:(id)store
{
    (void)store;
    self = [super init];
    return self;
}

- (ASAuthorizationAppleIDRequest *)createRequest
{
    return [[ASAuthorizationAppleIDRequest alloc] revenant_initWithProvider:self];
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[[self class] allocWithZone:zone] revenant_initWithCredentialState:nil];
}

- (void)getCredentialStateForUserID:(NSString *)userID completion:(void (^)(ASAuthorizationAppleIDProviderCredentialState credentialState, NSError * _Nullable error))completion
{
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
    return [self revenant_initWithCredentialState:nil];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
}

@end
