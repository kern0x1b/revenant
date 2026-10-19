#import "CharonContacts.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation CNSocialProfile {
    NSString *_charonUrlString;
    NSString *_charonUsername;
    NSString *_charonUserIdentifier;
    NSString *_charonService;
}

@dynamic urlString, username, userIdentifier, service;

- (instancetype)initWithUrlString:(NSString *)urlString username:(NSString *)username userIdentifier:(NSString *)userIdentifier service:(NSString *)service
{
    self = [super init];
    if (self) {
        _charonUrlString = [urlString copy];
        _charonUsername = [username copy];
        _charonUserIdentifier = [userIdentifier copy];
        _charonService = [service copy];
    }
    return self;
}

- (NSString *)urlString { return _charonUrlString ?: @""; }
- (NSString *)username { return _charonUsername ?: @""; }
- (NSString *)userIdentifier { return _charonUserIdentifier ?: @""; }
- (NSString *)service { return _charonService ?: @""; }

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
    [coder encodeObject:_charonUrlString forKey:@"urlString"];
    [coder encodeObject:_charonUsername forKey:@"username"];
    [coder encodeObject:_charonUserIdentifier forKey:@"userIdentifier"];
    [coder encodeObject:_charonService forKey:@"service"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        _charonUrlString = [[coder decodeObjectOfClass:[NSString class] forKey:@"urlString"] copy];
        _charonUsername = [[coder decodeObjectOfClass:[NSString class] forKey:@"username"] copy];
        _charonUserIdentifier = [[coder decodeObjectOfClass:[NSString class] forKey:@"userIdentifier"] copy];
        _charonService = [[coder decodeObjectOfClass:[NSString class] forKey:@"service"] copy];
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
    return [NSString stringWithFormat:@"<%@: %p: service=%@, username=%@>", NSStringFromClass([self class]), self, _charonService, _charonUsername];
}

@end
