#import "RevenantNetworkExtensionSettings.h"

@implementation NEIPv6Settings {
    NSArray<NSString *> *_addresses;
    NSArray<NSNumber *> *_networkPrefixLengths;
    NSArray<NEIPv6Route *> *_includedRoutes;
    NSArray<NEIPv6Route *> *_excludedRoutes;
}

- (instancetype)init
{
    return [self initWithAddresses:@[] networkPrefixLengths:@[]];
}

- (instancetype)initWithAddresses:(NSArray<NSString *> *)addresses networkPrefixLengths:(NSArray<NSNumber *> *)networkPrefixLengths
{
    self = [super init];
    if (self) {
        _addresses = [addresses copy];
        _networkPrefixLengths = [networkPrefixLengths copy];
    }
    return self;
}

+ (instancetype)settingsWithAutomaticAddressing
{
    return [[NEIPv6Settings alloc] initWithAddresses:@[] networkPrefixLengths:@[]];
}

+ (instancetype)settingsWithLinkLocalAddressing
{
    return [[NEIPv6Settings alloc] initWithAddresses:@[] networkPrefixLengths:@[]];
}

- (NSArray<NSString *> *)addresses { return _addresses; }
- (NSArray<NSNumber *> *)networkPrefixLengths { return _networkPrefixLengths; }

- (NSArray<NEIPv6Route *> *)includedRoutes { return _includedRoutes; }
- (void)setIncludedRoutes:(NSArray<NEIPv6Route *> *)routes { _includedRoutes = [routes copy]; }

- (NSArray<NEIPv6Route *> *)excludedRoutes { return _excludedRoutes; }
- (void)setExcludedRoutes:(NSArray<NEIPv6Route *> *)routes { _excludedRoutes = [routes copy]; }

- (id)copyWithZone:(NSZone *)zone
{
    NEIPv6Settings *copy = [[NEIPv6Settings allocWithZone:zone] initWithAddresses:_addresses
                                                           networkPrefixLengths:_networkPrefixLengths];
    copy->_includedRoutes = [_includedRoutes copy];
    copy->_excludedRoutes = [_excludedRoutes copy];
    return copy;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        _addresses = [[coder decodeObjectOfClass:[NSArray class] forKey:@"addresses"] copy];
        _networkPrefixLengths = [[coder decodeObjectOfClass:[NSArray class] forKey:@"networkPrefixLengths"] copy];
        _includedRoutes = [[coder decodeObjectOfClass:[NSArray class] forKey:@"includedRoutes"] copy];
        _excludedRoutes = [[coder decodeObjectOfClass:[NSArray class] forKey:@"excludedRoutes"] copy];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_addresses forKey:@"addresses"];
    [coder encodeObject:_networkPrefixLengths forKey:@"networkPrefixLengths"];
    [coder encodeObject:_includedRoutes forKey:@"includedRoutes"];
    [coder encodeObject:_excludedRoutes forKey:@"excludedRoutes"];
}

+ (BOOL)supportsSecureCoding { return YES; }

@end
