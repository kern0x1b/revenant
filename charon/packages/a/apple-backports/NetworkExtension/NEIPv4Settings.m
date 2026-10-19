#import "CharonNetworkExtensionSettings.h"

/* The IPv4 settings object and the route it holds. State again: the system reads them when a
   configuration is applied, and the addresses and masks the object was built over are readonly, as
   the 26.2 header declares them. `settingsWithAutomaticAddressing` and `+defaultRoute` are the two
   class answers the header declares, and each is a fixed value rather than a call into a daemon:
   automatic addressing means "the system fills these in", and the default route is the route whose
   destination is 0.0.0.0 with a zero mask, which is what the header's own description of it says. */
@implementation NEIPv4Settings {
    NSArray<NSString *> *_addresses;
    NSArray<NSString *> *_subnetMasks;
    NSString *_router;
    NSArray<NEIPv4Route *> *_includedRoutes;
    NSArray<NEIPv4Route *> *_excludedRoutes;
}

/* Measured: a fresh NEIPv4Settings answers `addresses` and `subnetMasks` as **empty arrays** on the
   host, not nil. The differential caught it: this object answered nil until these two lines. */
- (instancetype)init
{
    return [self initWithAddresses:@[] subnetMasks:@[]];
}

- (instancetype)initWithAddresses:(NSArray<NSString *> *)addresses subnetMasks:(NSArray<NSString *> *)subnetMasks
{
    self = [super init];
    if (self) {
        _addresses = [addresses copy];
        _subnetMasks = [subnetMasks copy];
    }
    return self;
}

+ (NEIPv4Settings *)settingsWithAutomaticAddressing
{
    return [[NEIPv4Settings alloc] initWithAddresses:@[] subnetMasks:@[]];
}

- (NSArray<NSString *> *)addresses { return _addresses; }
- (NSArray<NSString *> *)subnetMasks { return _subnetMasks; }

- (NSString *)router { return _router; }
- (void)setRouter:(NSString *)router { _router = [router copy]; }

- (NSArray<NEIPv4Route *> *)includedRoutes { return _includedRoutes; }
- (void)setIncludedRoutes:(NSArray<NEIPv4Route *> *)routes { _includedRoutes = [routes copy]; }

- (NSArray<NEIPv4Route *> *)excludedRoutes { return _excludedRoutes; }
- (void)setExcludedRoutes:(NSArray<NEIPv4Route *> *)routes { _excludedRoutes = [routes copy]; }

- (id)copyWithZone:(NSZone *)zone
{
    NEIPv4Settings *copy = [[NEIPv4Settings allocWithZone:zone] initWithAddresses:_addresses subnetMasks:_subnetMasks];
    copy->_router = [_router copy];
    copy->_includedRoutes = [_includedRoutes copy];
    copy->_excludedRoutes = [_excludedRoutes copy];
    return copy;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        _addresses = [[coder decodeObjectOfClass:[NSArray class] forKey:@"addresses"] copy];
        _subnetMasks = [[coder decodeObjectOfClass:[NSArray class] forKey:@"subnetMasks"] copy];
        _router = [[coder decodeObjectOfClass:[NSString class] forKey:@"router"] copy];
        _includedRoutes = [[coder decodeObjectOfClass:[NSArray class] forKey:@"includedRoutes"] copy];
        _excludedRoutes = [[coder decodeObjectOfClass:[NSArray class] forKey:@"excludedRoutes"] copy];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_addresses forKey:@"addresses"];
    [coder encodeObject:_subnetMasks forKey:@"subnetMasks"];
    [coder encodeObject:_router forKey:@"router"];
    [coder encodeObject:_includedRoutes forKey:@"includedRoutes"];
    [coder encodeObject:_excludedRoutes forKey:@"excludedRoutes"];
}

+ (BOOL)supportsSecureCoding { return YES; }

@end
