// ASPasswordCredential, of iOS 12.0: a user and a password, as a value.
//
// **Why this is implemented and the two provider classes are not.** A credential is a value object an
// application constructs and hands back; it asks nothing of the system and needs no daemon, no
// extension host and no hardware. The provider classes are absent for the opposite reason -- the release
// has no credential provider extension for the system's AutoFill to consult -- and that reason does not
// touch this one, so carrying it and leaving them absent is not a partial answer, it is the right one
// for each.
//
// **The two halves are kept apart.** `ASAuthorizationCredential` is what a finished request produces, and
// `ASPasswordCredential` is what an application supplies when a password field asks for one; the port
// carries the first through the request classes and this through here, and a caller's password is
// copied in and copied out so that the store's own value cannot be mutated through the object.
#import <AuthenticationServices/AuthenticationServices.h>
#import "CharonASConstruction.h"

@implementation ASPasswordCredential

@synthesize user = _user;
@synthesize password = _password;

- (instancetype)charon_initWithUser:(NSString *)user password:(NSString *)password
{
    // The protocol ASAuthorizationCredential this adopts is the one that declares the initialisers
    // NS_UNAVAILABLE -- the release does not want this object made by a subclass -- so the port's
    // construction is named and is the only way one is made here.
    self = [super init];
    if (self) {
        _user = [user copy];
        _password = [password copy];
    }
    return self;
}

- (instancetype)initWithUser:(NSString *)user password:(NSString *)password
{
    return [self charon_initWithUser:user password:password];
}

+ (instancetype)credentialWithUser:(NSString *)user password:(NSString *)password
{
    return [[ASPasswordCredential alloc] charon_initWithUser:user password:password];
}

- (NSString *)user
{
    return [_user copy];
}

- (NSString *)password
{
    return [_password copy];
}

+ (BOOL)supportsSecureCoding
{
    return NO;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    return [self charon_initWithUser:@"" password:@""];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
}

- (id)copyWithZone:(NSZone *)zone
{
    // A copy carries the user AND the password. A copy that dropped the password would be an object
    // that looks like a credential and cannot be used for one, and the value differential checks that
    // it is not.
    return [[[self class] allocWithZone:zone] charon_initWithUser:_user password:_password];
}

@end
