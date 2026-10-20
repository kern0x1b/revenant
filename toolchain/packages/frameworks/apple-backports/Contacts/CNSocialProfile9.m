#import "RevenantContacts.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation CNSocialProfile {
    NSString *_revenantUrlString;
    NSString *_revenantUsername;
    NSString *_revenantUserIdentifier;
    NSString *_revenantService;
}

@dynamic urlString, username, userIdentifier, service;

- (instancetype)initWithUrlString:(NSString *)urlString username:(NSString *)username userIdentifier:(NSString *)userIdentifier service:(NSString *)service
{
    self = [super init];
    if (self) {
        _revenantUrlString = [urlString copy];
        _revenantUsername = [username copy];
        _revenantUserIdentifier = [userIdentifier copy];
        _revenantService = [service copy];
    }
    return self;
}

- (NSString *)urlString { return _revenantUrlString ?: @""; }
- (NSString *)username { return _revenantUsername ?: @""; }
- (NSString *)userIdentifier { return _revenantUserIdentifier ?: @""; }
- (NSString *)service { return _revenantService ?: @""; }

+ (NSString *)localizedStringForKey:(NSString *)key
{
    return key;
}

+ (NSString *)localizedStringForService:(NSString *)service
{
    return service;
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_revenantUrlString forKey:@"urlString"];
    [coder encodeObject:_revenantUsername forKey:@"username"];
    [coder encodeObject:_revenantUserIdentifier forKey:@"userIdentifier"];
    [coder encodeObject:_revenantService forKey:@"service"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        _revenantUrlString = [[coder decodeObjectOfClass:[NSString class] forKey:@"urlString"] copy];
        _revenantUsername = [[coder decodeObjectOfClass:[NSString class] forKey:@"username"] copy];
        _revenantUserIdentifier = [[coder decodeObjectOfClass:[NSString class] forKey:@"userIdentifier"] copy];
        _revenantService = [[coder decodeObjectOfClass:[NSString class] forKey:@"service"] copy];
    }
    return self;
}

- (BOOL)isEqual:(id)object
{
    if (self == object)
        return YES;
    if (![object isKindOfClass:[CNSocialProfile class]])
        return NO;
    CNSocialProfile *other = object;
    return [self.urlString isEqualToString:other.urlString] && [self.username isEqualToString:other.username]
        && [self.userIdentifier isEqualToString:other.userIdentifier] && [self.service isEqualToString:other.service];
}

- (NSUInteger)hash
{
    return self.service.hash ^ self.username.hash;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p: service=%@, username=%@>", NSStringFromClass([self class]), self, _revenantService, _revenantUsername];
}

@end
