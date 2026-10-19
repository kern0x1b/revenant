#import "CharonNetworkExtensionSettings.h"

/* NEIPv6Route, from iOS 9.0, apart from NEIPv6Settings.m (iOS 8.0): an object carries one release, and
   `tools/release-split.lua` is what says so. The route the IPv6 settings hold: state, with
   `+defaultRoute` the fixed route whose destination is the unspecified address with a prefix length of
   zero, which is what a default route matches and what the host's own class answers -
   tests/backports/host/netext-proxy/ compares it name by name against Apple's. */

@implementation NEIPv6Route {
    NSString *_destinationAddress;
    NSNumber *_destinationNetworkPrefixLength;
    NSString *_gatewayAddress;
}

- (instancetype)initWithDestinationAddress:(NSString *)address networkPrefixLength:(NSNumber *)networkPrefixLength
{
    self = [super init];
    if (self) {
        _destinationAddress = [address copy];
        _destinationNetworkPrefixLength = [networkPrefixLength copy];
    }
    return self;
}

- (NSString *)destinationAddress { return _destinationAddress; }
- (NSNumber *)destinationNetworkPrefixLength { return _destinationNetworkPrefixLength; }

- (NSString *)gatewayAddress { return _gatewayAddress; }
- (void)setGatewayAddress:(NSString *)gateway { _gatewayAddress = [gateway copy]; }

+ (NEIPv6Route *)defaultRoute
{
    return [[NEIPv6Route alloc] initWithDestinationAddress:@"::" networkPrefixLength:@0];
}

- (id)copyWithZone:(NSZone *)zone
{
    NEIPv6Route *copy = [[NEIPv6Route allocWithZone:zone] initWithDestinationAddress:_destinationAddress
                                                                networkPrefixLength:_destinationNetworkPrefixLength];
    copy->_gatewayAddress = [_gatewayAddress copy];
    return copy;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        _destinationAddress = [[coder decodeObjectOfClass:[NSString class] forKey:@"destinationAddress"] copy];
        _destinationNetworkPrefixLength = [[coder decodeObjectOfClass:[NSNumber class] forKey:@"destinationNetworkPrefixLength"] copy];
        _gatewayAddress = [[coder decodeObjectOfClass:[NSString class] forKey:@"gatewayAddress"] copy];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_destinationAddress forKey:@"destinationAddress"];
    [coder encodeObject:_destinationNetworkPrefixLength forKey:@"destinationNetworkPrefixLength"];
    [coder encodeObject:_gatewayAddress forKey:@"gatewayAddress"];
}

+ (BOOL)supportsSecureCoding { return YES; }

@end