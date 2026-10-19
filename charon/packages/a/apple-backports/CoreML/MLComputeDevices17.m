#import "CharonCoreMLComputeDevices.h"

@interface MLCPUComputeDevice (CharonFactory)
- (instancetype)charon_init;
@end

@implementation MLCPUComputeDevice (CharonFactory)

- (instancetype)charon_init
{
    return [super init];
}

@end

static MLCPUComputeDevice *CharonMLComputeCPUDevice(void)
{
    static MLCPUComputeDevice *device = nil;
    if (!device) {
        device = [[MLCPUComputeDevice alloc] charon_init];
    }
    return device;
}

@implementation MLCPUComputeDevice
@end

@implementation MLGPUComputeDevice

- (id<MTLDevice>)metalDevice
{
    return nil;
}

@end

@implementation MLNeuralEngineComputeDevice

- (NSInteger)totalCoreCount
{
    return 0;
}

@end

NSArray<id<MLComputeDeviceProtocol>> *MLAllComputeDevices(void)
{
    return @[CharonMLComputeCPUDevice()];
}

@implementation MLModel (MLComputeDevice)

+ (NSArray<id<MLComputeDeviceProtocol>> *)availableComputeDevices
{
    return MLAllComputeDevices();
}

@end
