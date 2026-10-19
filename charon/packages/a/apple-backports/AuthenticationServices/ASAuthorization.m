#import <AuthenticationServices/AuthenticationServices.h>
#import "CharonASConstruction.h"

@implementation ASAuthorization

@synthesize provider = _provider;
@synthesize credential = _credential;

- (instancetype)charon_initWithProvider:(id<ASAuthorizationProvider>)provider
                              credential:(id<ASAuthorizationCredential>)credential
{
    self = [super init];
    if (self) {
        _provider = provider;
        _credential = credential;
    }
    return self;
}

- (id<ASAuthorizationProvider>)provider
{
    return _provider;
}

- (id<ASAuthorizationCredential>)credential
{
    return _credential;
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    return [[[self class] allocWithZone:zone] charon_initWithProvider:_provider credential:_credential];
}

+ (BOOL)supportsSecureCoding
{
    return NO;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    return [self charon_initWithProvider:nil credential:nil];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
}

@end
