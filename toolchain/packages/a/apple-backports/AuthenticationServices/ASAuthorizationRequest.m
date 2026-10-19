#import <AuthenticationServices/AuthenticationServices.h>
#import "CharonASConstruction.h"

static NSString *const ASCharonProviderCodingKey = @"org.charon.authservices.provider";

@implementation ASAuthorizationRequest

@synthesize provider = _provider;

- (instancetype)charon_initWithProvider:(id<ASAuthorizationProvider>)provider
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
            id decoded = [coder decodeObjectOfClass:[NSObject class] forKey:ASCharonProviderCodingKey];
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
        [coder encodeObject:_provider forKey:ASCharonProviderCodingKey];
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
    ASAuthorizationRequest *copy = [[[self class] allocWithZone:zone] charon_initWithProvider:_provider];
    return copy;
}

@end
