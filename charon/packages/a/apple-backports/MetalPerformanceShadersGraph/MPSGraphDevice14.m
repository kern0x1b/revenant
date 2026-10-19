// MPSGraphDevice, from the header of MPSGraphDevice.h in the SDK of iOS 16.4: the compute device a graph
// runs on. MPSGraphDeviceTypeMetal is 0, which is the only kind there is here, because every device this
// port has is charon's own Metal device.

#import "CharonMPSGraph.h"

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
