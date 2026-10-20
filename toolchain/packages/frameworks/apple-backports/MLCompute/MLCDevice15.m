#import "RevenantMLCompute.h"

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
