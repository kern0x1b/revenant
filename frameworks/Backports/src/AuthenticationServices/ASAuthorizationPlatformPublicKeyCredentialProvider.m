#import "RevenantASHostNames.h"
#import <AuthenticationServices/AuthenticationServices.h>
#import "RevenantASConstruction.h"

@implementation ASAuthorizationPlatformPublicKeyCredentialProvider {
    NSString *_relyingPartyIdentifier;
}

- (instancetype)initWithRelyingPartyIdentifier:(NSString *)relyingPartyIdentifier
{
    if ((self = [super init])) {
        _relyingPartyIdentifier = [relyingPartyIdentifier copy];
    }
    return self;
}

- (NSString *)relyingPartyIdentifier
{
    return _relyingPartyIdentifier;
}

- (ASAuthorizationPlatformPublicKeyCredentialRegistrationRequest *)createCredentialRegistrationRequestWithChallenge:(NSData *)challenge name:(NSString *)name userID:(NSData *)userID
{
    return [[ASAuthorizationPlatformPublicKeyCredentialRegistrationRequest alloc] revenant_initWithProvider:self challenge:challenge name:name userID:userID];
}

- (ASAuthorizationPlatformPublicKeyCredentialRegistrationRequest *)createCredentialRegistrationRequestWithChallenge:(NSData *)challenge displayName:(NSString *)displayName name:(NSString *)name userID:(NSData *)userID
{
    ASAuthorizationPlatformPublicKeyCredentialRegistrationRequest *request = [self createCredentialRegistrationRequestWithChallenge:challenge name:name userID:userID];
    request.displayName = displayName;
    return request;
}

- (ASAuthorizationPlatformPublicKeyCredentialAssertionRequest *)createCredentialAssertionRequestWithChallenge:(NSData *)challenge
{
    return [[ASAuthorizationPlatformPublicKeyCredentialAssertionRequest alloc] revenant_initWithProvider:self challenge:challenge];
}

@end
