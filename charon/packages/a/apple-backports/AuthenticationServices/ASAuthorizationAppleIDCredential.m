// ASAuthorizationAppleIDCredential, of iOS 13.0: what a finished Sign in with Apple returns.
//
// It is a value object: the header marks `-init` and `+new` unavailable and gives it seven readonly
// properties, so everything an application can learn from a sign-in is here, and everything the
// provider fills in is here too. There is no method to call and nothing to configure, which is why it is
// worth writing plainly rather than cleverly.
//
// **The three values that carry the sign-in** are `user`, `authorizedScopes` and `identityToken`:
// `user` is the opaque identifier the sign-in is for, `authorizedScopes` is what the user actually
// granted (a subset of what the request asked for, and never more), and `identityToken` is the signed
// assertion an application verifies server-side. `authorizationCode` is the other half of that pair: the
// short-lived code the server exchanges for the token.
//
// **`realUserStatus` is a hint, not a gate.** The header says so in as many words -- `LikelyReal` is "a
// hint that we have high confidence that the user is real", and `Unknown` is what a new user in the
// ecosystem gets, with the instruction not to block them. The port carries the value the provider gave
// and nothing more, and the facts file says the same: an application that treats it as a gate will drop
// new users, and the header says so.
//
// **`fullName` and `email` come once.** They are only ever filled on the *first* sign-in for a user, and
// they arrive as the name components and the address the user typed into Apple's form. A later sign-in
// carries nil for both, and an application that assumes otherwise will read a user's name off a nil.
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

// -init and +new are unavailable in the release's own header, so a credential is not made by
// constructing it. It is what the provider hands back, and the port's own way in is the designated
// initialiser below -- the same construction every class in this family uses, and the only member this
// class has that is not one of the seven the header declares. There are no stored members of the
// port's own: the seven are the release's, synthesised above, and the values arrive through the
// initialiser.
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
    // Non-null in the header, and a credential with no user is not a credential: the port's
    // initialiser takes it and holds it, and there is no path to one that does not.
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
    // NSSecureCoding is refused above, so a coder is never the way in; this answers the protocol with
    // nothing rather than with a partly-built credential.
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
