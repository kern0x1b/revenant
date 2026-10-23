#import "RevenantASHostNames.h"
#import <AuthenticationServices/AuthenticationServices.h>
#import "RevenantASConstruction.h"

@implementation ASAuthorizationPlatformPublicKeyCredentialRegistrationRequest {
    NSString *_relyingPartyIdentifier;
    NSData *_userID;
    NSString *_name;
    NSString *_displayName;
    NSData *_challenge;
    ASAuthorizationPublicKeyCredentialUserVerificationPreference _userVerificationPreference;
    ASAuthorizationPublicKeyCredentialAttestationKind _attestationPreference;
}

- (instancetype)revenant_initWithProvider:(id<ASAuthorizationProvider>)provider challenge:(NSData *)challenge name:(NSString *)name userID:(NSData *)userID __attribute__((objc_method_family(init)))
{
    if ((self = [super revenant_initWithProvider:provider])) {
        _relyingPartyIdentifier = [((ASAuthorizationPlatformPublicKeyCredentialProvider *)provider).relyingPartyIdentifier copy];
        _challenge = [challenge copy];
        _name = [name copy];
        _userID = [userID copy];
        _userVerificationPreference = ASAuthorizationPublicKeyCredentialUserVerificationPreferencePreferred;
        _attestationPreference = ASAuthorizationPublicKeyCredentialAttestationKindNone;
    }
    return self;
}

- (NSString *)relyingPartyIdentifier
{
    return _relyingPartyIdentifier;
}

- (NSData *)challenge
{
    return _challenge;
}

- (void)setChallenge:(NSData *)challenge
{
    _challenge = [challenge copy];
}

- (NSData *)userID
{
    return _userID;
}

- (void)setUserID:(NSData *)userID
{
    _userID = [userID copy];
}

- (NSString *)name
{
    return _name;
}

- (void)setName:(NSString *)name
{
    _name = [name copy];
}

- (NSString *)displayName
{
    return _displayName;
}

- (void)setDisplayName:(NSString *)displayName
{
    _displayName = [displayName copy];
}

- (ASAuthorizationPublicKeyCredentialUserVerificationPreference)userVerificationPreference
{
    return _userVerificationPreference;
}

- (void)setUserVerificationPreference:(ASAuthorizationPublicKeyCredentialUserVerificationPreference)userVerificationPreference
{
    _userVerificationPreference = userVerificationPreference;
}

- (ASAuthorizationPublicKeyCredentialAttestationKind)attestationPreference
{
    return _attestationPreference;
}

- (void)setAttestationPreference:(ASAuthorizationPublicKeyCredentialAttestationKind)attestationPreference
{
    _attestationPreference = attestationPreference;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (id)copyWithZone:(NSZone *)zone
{
    ASAuthorizationPlatformPublicKeyCredentialRegistrationRequest *copy = [[[self class] allocWithZone:zone] revenant_initWithProvider:self.provider challenge:_challenge name:_name userID:_userID];
    copy->_displayName = [_displayName copy];
    copy->_userVerificationPreference = _userVerificationPreference;
    copy->_attestationPreference = _attestationPreference;
    return copy;
}

@end

@implementation ASAuthorizationPlatformPublicKeyCredentialAssertionRequest {
    NSData *_challenge;
    NSArray *_allowedCredentials;
    ASAuthorizationPublicKeyCredentialUserVerificationPreference _userVerificationPreference;
}

- (instancetype)revenant_initWithProvider:(id<ASAuthorizationProvider>)provider challenge:(NSData *)challenge __attribute__((objc_method_family(init)))
{
    if ((self = [super revenant_initWithProvider:provider])) {
        _challenge = [challenge copy];
        _allowedCredentials = @[];
        _userVerificationPreference = ASAuthorizationPublicKeyCredentialUserVerificationPreferencePreferred;
    }
    return self;
}

- (NSString *)relyingPartyIdentifier
{
    return ((ASAuthorizationPlatformPublicKeyCredentialProvider *)self.provider).relyingPartyIdentifier;
}

- (NSData *)challenge
{
    return _challenge;
}

- (void)setChallenge:(NSData *)challenge
{
    _challenge = [challenge copy];
}

- (NSArray *)allowedCredentials
{
    return _allowedCredentials;
}

- (void)setAllowedCredentials:(NSArray *)allowedCredentials
{
    _allowedCredentials = [allowedCredentials copy];
}

- (ASAuthorizationPublicKeyCredentialUserVerificationPreference)userVerificationPreference
{
    return _userVerificationPreference;
}

- (void)setUserVerificationPreference:(ASAuthorizationPublicKeyCredentialUserVerificationPreference)userVerificationPreference
{
    _userVerificationPreference = userVerificationPreference;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (id)copyWithZone:(NSZone *)zone
{
    ASAuthorizationPlatformPublicKeyCredentialAssertionRequest *copy = [[[self class] allocWithZone:zone] revenant_initWithProvider:self.provider challenge:_challenge];
    copy->_allowedCredentials = [_allowedCredentials copy];
    copy->_userVerificationPreference = _userVerificationPreference;
    return copy;
}

@end
