#import "RevenantMPSGraph.h"

@implementation MPSGraphDevice {
    MPSGraphDeviceType _type;
    id<MTLDevice> _metalDevice;
}

+ (instancetype)deviceWithMTLDevice:(id<MTLDevice>)metalDevice
{
    return [[self alloc] initWithMTLDevice:metalDevice];
}

- (instancetype)initWithMTLDevice:(id<MTLDevice>)metalDevice
{
    if ((self = [super init])) {
        _type = MPSGraphDeviceTypeMetal;
        _metalDevice = metalDevice;
    }
    return self;
}

- (MPSGraphDeviceType)type
{
    return _type;
}

- (id<MTLDevice>)metalDevice
{
    return _metalDevice;
}

@end
