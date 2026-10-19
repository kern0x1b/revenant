#import <AuthenticationServices/AuthenticationServices.h>
#import "CharonASConstruction.h"

@implementation ASPasswordCredential

@synthesize user = _user;
@synthesize password = _password;

- (instancetype)charon_initWithUser:(NSString *)user password:(NSString *)password
{
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
    return [[[self class] allocWithZone:zone] charon_initWithUser:_user password:_password];
}

@end
