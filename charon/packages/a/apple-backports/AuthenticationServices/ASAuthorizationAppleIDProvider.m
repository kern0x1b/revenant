#import <AuthenticationServices/AuthenticationServices.h>
#import "CharonASConstruction.h"

@implementation ASAuthorizationAppleIDProvider

- (instancetype)charon_initWithCredentialState:(id)store
{
    (void)store;
    self = [super init];
    return self;
}

- (ASAuthorizationAppleIDRequest *)createRequest
{
    return [[ASAuthorizationAppleIDRequest alloc] charon_initWithProvider:self];
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[[self class] allocWithZone:zone] charon_initWithCredentialState:nil];
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
    return [self charon_initWithCredentialState:nil];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
}

@end
