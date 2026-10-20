#import <AuthenticationServices/AuthenticationServices.h>
#import "RevenantASConstruction.h"

@implementation ASAuthorizationAppleIDRequest

@synthesize user = _user;

- (instancetype)init
{
    self = [super init];
    if (self)
        _user = nil;
    return self;
}

- (instancetype)revenant_initWithProvider:(id<ASAuthorizationProvider>)provider __attribute__((objc_method_family(init)))
{
    self = [super revenant_initWithProvider:provider];
    if (self)
        _user = nil;
    return self;
}

- (NSString *)user
{
    return [_user copy];
}

- (void)setUser:(NSString *)user
{
    _user = [user copy];
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    ASAuthorizationAppleIDRequest *copy = [super copyWithZone:zone];
    if ([copy isKindOfClass:[ASAuthorizationAppleIDRequest class]])
        ((ASAuthorizationAppleIDRequest *)copy).user = _user;
    return copy;
}

@end
