#import <AuthenticationServices/AuthenticationServices.h>
#import "CharonASConstruction.h"

@implementation ASAuthorizationAppleIDCredential

@synthesize user = _user;
@synthesize state = _state;
@synthesize authorizedScopes = _authorizedScopes;
@synthesize authorizationCode = _authorizationCode;
@synthesize identityToken = _identityToken;
@synthesize email = _email;
@synthesize fullName = _fullName;
@synthesize realUserStatus = _realUserStatus;

- (instancetype)charon_initWithUser:(NSString *)user
                   authorizedScopes:(NSArray<ASAuthorizationScope> *)authorizedScopes
                   identityToken:(NSData *)identityToken
                  authorizationCode:(NSData *)authorizationCode
                             state:(NSString *)state
                             email:(NSString *)email
                          fullName:(NSPersonNameComponents *)fullName
                    realUserStatus:(ASUserDetectionStatus)realUserStatus
{
    self = [super init];
    if (self) {
        _user = [user copy];
        _authorizedScopes = [authorizedScopes copy] ?: @[];
        _identityToken = [identityToken copy];
        _authorizationCode = [authorizationCode copy];
        _state = [state copy];
        _email = [email copy];
        _fullName = [fullName copy];
        _realUserStatus = realUserStatus;
    }
    return self;
}

#pragma mark - the seven the header declares

- (NSString *)user
{
    return [_user copy];
}

- (NSString *)state
{
    return [_state copy];
}

- (NSArray<ASAuthorizationScope> *)authorizedScopes
{
    return [_authorizedScopes copy] ?: @[];
}

- (NSData *)authorizationCode
{
    return [_authorizationCode copy];
}

- (NSData *)identityToken
{
    return [_identityToken copy];
}

- (NSString *)email
{
    return [_email copy];
}

- (NSPersonNameComponents *)fullName
{
    return [_fullName copy];
}

- (ASUserDetectionStatus)realUserStatus
{
    return _realUserStatus;
}

+ (BOOL)supportsSecureCoding
{
    return NO;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    return [self charon_initWithUser:@""
                   authorizedScopes:@[]
                     identityToken:nil
                  authorizationCode:nil
                             state:nil
                             email:nil
                          fullName:nil
                    realUserStatus:ASUserDetectionStatusUnsupported];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    return [[[self class] allocWithZone:zone] charon_initWithUser:_user
                                                 authorizedScopes:_authorizedScopes
                                                     identityToken:_identityToken
                                                  authorizationCode:_authorizationCode
                                                             state:_state
                                                             email:_email
                                                          fullName:_fullName
                                                    realUserStatus:_realUserStatus];
}

@end
