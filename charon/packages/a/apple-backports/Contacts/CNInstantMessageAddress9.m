#import "CharonContacts.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation CNInstantMessageAddress {
    NSString *_charonUsername;
    NSString *_charonService;
}

@dynamic username, service;

- (instancetype)initWithUsername:(NSString *)username service:(NSString *)service
{
    self = [super init];
    if (self) {
        _charonUsername = [username copy];
        _charonService = [service copy];
    }
    return self;
}

- (NSString *)username { return _charonUsername ?: @""; }
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
    [coder encodeObject:_charonUsername forKey:@"username"];
    [coder encodeObject:_charonService forKey:@"service"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        _charonUsername = [[coder decodeObjectOfClass:[NSString class] forKey:@"username"] copy];
        _charonService = [[coder decodeObjectOfClass:[NSString class] forKey:@"service"] copy];
    }
    return self;
}

- (BOOL)isEqual:(id)object
{
    if (self == object)
        return YES;
    if (![object isKindOfClass:[CNInstantMessageAddress class]])
        return NO;
    return [self.username isEqualToString:[object username]] && [self.service isEqualToString:[object service]];
}

- (NSUInteger)hash
{
    return self.username.hash ^ self.service.hash;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p: username=%@, service=%@>", NSStringFromClass([self class]), self, _charonUsername, _charonService];
}

@end
