#import <AuthenticationServices/AuthenticationServices.h>
#import "RevenantASConstruction.h"

static NSString *const ASRevenantProviderCodingKey = @"org.revenant.authservices.provider";

@implementation ASAuthorizationRequest

@synthesize provider = _provider;

- (instancetype)revenant_initWithProvider:(id<ASAuthorizationProvider>)provider
{
    self = [super init];
    if (self)
        _provider = provider;
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        id provider = nil;
        if ([coder respondsToSelector:@selector(decodeObjectForKey:)]) {
            id decoded = [coder decodeObjectOfClass:[NSObject class] forKey:ASRevenantProviderCodingKey];
            if (decoded)
                provider = decoded;
        }
        _provider = provider;
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    if (_provider && [coder respondsToSelector:@selector(encodeObject:forKey:)])
        [coder encodeObject:_provider forKey:ASRevenantProviderCodingKey];
}

- (id<ASAuthorizationProvider>)provider
{
    return _provider;
}

+ (BOOL)supportsSecureCoding
{
    return NO;
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    ASAuthorizationRequest *copy = [[[self class] allocWithZone:zone] revenant_initWithProvider:_provider];
    return copy;
}

@end
