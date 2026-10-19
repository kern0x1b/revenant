// MLCDevice, the object a graph is compiled for, and the numbers it answers about itself.
//
// iOS 6.1.3 has a CPU and nothing else this framework can use: no Metal, so no GPU device, and no
// Neural Engine, so none either. So MLCDeviceTypeGPU and MLCDeviceTypeANE are carried and answer the
// way a machine with neither does - +gpuDevice and +aneDevice are nil, a device made for either type is
// nil, and the lists of Metal devices are empty - and MLCDeviceTypeAny, which means "whichever is
// best", resolves to the CPU and reports that, which is what the host does when the CPU is the only
// device it has (measured: +[MLCDevice deviceWithType:MLCDeviceTypeAny] answers type 0 on a machine
// whose own GPU device also answers 0 for its actualDeviceType only where no GPU was chosen;
// facts/MLCompute/Device.md).

#import "CharonMLCompute.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
#pragma clang diagnostic ignored "-Wnullability-completeness"

@implementation MLCDevice {
    MLCDeviceType _type;
    MLCDeviceType _actualDeviceType;
    NSUInteger _selectsMultipleComputeDevices;
}

+ (instancetype)cpuDevice
{
    return [[self alloc] initWithType:MLCDeviceTypeCPU actual:MLCDeviceTypeCPU];
}

+ (instancetype)gpuDevice
{
    return nil;
}

+ (instancetype)aneDevice
{
    return nil;
}

+ (instancetype)deviceWithType:(MLCDeviceType)type
{
    // "Any" is a request, not a device: it is answered with the device that will do the work, which on a
    // machine with no GPU and no Neural Engine is the CPU (measured on the host, which answers type 0).
    if (type == MLCDeviceTypeAny) {
        return [self cpuDevice];
    }
    if (type == MLCDeviceTypeGPU || type == MLCDeviceTypeANE) {
        return nil;
    }
    if (type != MLCDeviceTypeCPU) {
        return nil;
    }
    return [[self alloc] initWithType:type actual:type];
}

+ (instancetype)deviceWithType:(MLCDeviceType)type selectsMultipleComputeDevices:(BOOL)selectsMultipleComputeDevices
{
    MLCDevice *device = [self deviceWithType:type];
    if (device && selectsMultipleComputeDevices) {
        device->_selectsMultipleComputeDevices = YES;
    }
    return device;
}

+ (instancetype)deviceWithGPUDevices:(NSArray<id> *)gpus
{
    // This release has no Metal at all, so every element of such a list names a device that is not there
    // and there is nothing to answer with but the absence of one - which is what +gpuDevice answers for
    // the same reason, and what a machine with no GPU answers on the host.
    return nil;
}

- (instancetype)initWithType:(MLCDeviceType)type actual:(MLCDeviceType)actual
{
    self = [super init];
    if (self) {
        _type = type;
        _actualDeviceType = actual;
        _selectsMultipleComputeDevices = NO;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    // A copy is another device of the same kind, and it selects multiple compute devices only where the
    // one it was copied from did (measured: the copy of a CPU device answers the same type).
    MLCDevice *copy = [[[self class] allocWithZone:zone] initWithType:_type actual:_actualDeviceType];
    copy->_selectsMultipleComputeDevices = _selectsMultipleComputeDevices;
    return copy;
}

- (MLCDeviceType)type
{
    return _type;
}

- (MLCDeviceType)actualDeviceType
{
    return _actualDeviceType;
}

- (NSArray<id> *)gpuDevices
{
    return @[];
}

@end
