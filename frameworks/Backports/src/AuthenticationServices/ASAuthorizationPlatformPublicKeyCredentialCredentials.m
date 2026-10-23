#import <AuthenticationServices/AuthenticationServices.h>

@implementation ASAuthorizationPlatformPublicKeyCredentialRegistration {
    NSData *_credentialID;
    NSData *_rawClientDataJSON;
    NSData *_rawAttestationObject;
}

- (NSData *)credentialID
{
    return _credentialID;
}

- (NSData *)rawClientDataJSON
{
    return _rawClientDataJSON;
}

- (NSData *)rawAttestationObject
{
    return _rawAttestationObject;
}

@end

@implementation ASAuthorizationPlatformPublicKeyCredentialAssertion {
    NSData *_credentialID;
    NSData *_rawClientDataJSON;
    NSData *_rawAuthenticatorData;
    NSData *_userID;
    NSData *_signature;
}

- (NSData *)credentialID
{
    return _credentialID;
}

- (NSData *)rawClientDataJSON
{
    return _rawClientDataJSON;
}

- (NSData *)rawAuthenticatorData
{
    return _rawAuthenticatorData;
}

- (NSData *)userID
{
    return _userID;
}

- (NSData *)signature
{
    return _signature;
}

@end
