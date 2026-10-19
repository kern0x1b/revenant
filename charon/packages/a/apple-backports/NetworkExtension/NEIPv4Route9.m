#import "CharonNetworkExtensionSettings.h"

/* NEIPv4Route, from iOS 9.0, apart from NEIPv4Settings.m (iOS 8.0): an object carries one release.
   The route the IPv4 settings hold: state, with `+defaultRoute` the fixed route whose destination
   is 0.0.0.0 with a zero mask, which is what the 26.2 header's own description of it says. */
@implementation NEIPv4Route {
    NSString *_destinationAddress;
    NSString *_destinationSubnetMask;
    NSString *_gatewayAddress;
}

- (instancetype)initWithDestinationAddress:(NSString *)address subnetMask:(NSString *)subnetMask
{
    self = [super init];
    if (self) {
        _destinationAddress = [address copy];
        _destinationSubnetMask = [subnetMask copy];
    }
    return self;
}

- (NSString *)destinationAddress { return _destinationAddress; }
- (NSString *)destinationSubnetMask { return _destinationSubnetMask; }

- (NSString *)gatewayAddress { return _gatewayAddress; }
- (void)setGatewayAddress:(NSString *)gateway { _gatewayAddress = [gateway copy]; }

+ (NEIPv4Route *)defaultRoute
{
    return [[NEIPv4Route alloc] initWithDestinationAddress:@"0.0.0.0" subnetMask:@"0.0.0.0"];
}

- (id)copyWithZone:(NSZone *)zone
{
    NEIPv4Route *copy = [[NEIPv4Route allocWithZone:zone] initWithDestinationAddress:_destinationAddress
                                                                      subnetMask:_destinationSubnetMask];
    copy->_gatewayAddress = [_gatewayAddress copy];
    return copy;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        _destinationAddress = [[coder decodeObjectOfClass:[NSString class] forKey:@"destinationAddress"] copy];
        _destinationSubnetMask = [[coder decodeObjectOfClass:[NSString class] forKey:@"destinationSubnetMask"] copy];
        _gatewayAddress = [[coder decodeObjectOfClass:[NSString class] forKey:@"gatewayAddress"] copy];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_destinationAddress forKey:@"destinationAddress"];
    [coder encodeObject:_destinationSubnetMask forKey:@"destinationSubnetMask"];
    [coder encodeObject:_gatewayAddress forKey:@"gatewayAddress"];
}

+ (BOOL)supportsSecureCoding { return YES; }

@end
