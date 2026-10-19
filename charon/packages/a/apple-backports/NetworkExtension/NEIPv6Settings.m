#import "CharonNetworkExtensionSettings.h"

/* NEIPv6Settings, the IPv6 counterpart of what NEIPv4Settings.m carries, and one object of its own
   because an object holds the API of one release: the caches place this class at iOS 8.0 and NEIPv6Route
   - which is in NEIPv6Route9.m, for the reason NEIPv4Route9.m gives - at 9.0.

   State, like their IPv4 counterparts: the system reads a settings object when a configuration is
   applied, so what a port object holds is what a release's own object would hold. The addresses and the
   prefix lengths an object was built over are readonly as the header declares them, and the routes are
   copied so a caller cannot change the object through the array it handed over.

   `+defaultRoute` is the route whose destination is the unspecified address with a prefix length of
   zero, which is what a default route is; tests/backports/host/netext-proxy/ compares both this file's
   answers against Apple's own, name by name, and the run's verdict line is what says the port's are
   Apple's.

   The two class methods `+settingsWithAutomaticAddressing` and `+settingsWithLinkLocalAddressing` are
   API_UNAVAILABLE on every platform in the 26.2 header, so Apple's own class does not carry them and a
   host comparison cannot be their oracle; what they mean is fixed by their names: automatic addressing
   is "the system fills the addresses in", and link-local addressing gives the interface its link-local
   address and nothing else. Each answers an object with the empty arrays its read-only properties
   answer, and the run checks the two names against the header instead. */

@implementation NEIPv6Settings {
    NSArray<NSString *> *_addresses;
    NSArray<NSNumber *> *_networkPrefixLengths;
    NSArray<NEIPv6Route *> *_includedRoutes;
    NSArray<NEIPv6Route *> *_excludedRoutes;
}

/* Measured: a fresh NEIPv6Settings answers `addresses` and `networkPrefixLengths` as **empty arrays**
   on the host, not nil - the same answer NEIPv4Settings gives, and the differential is what says so. */
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
