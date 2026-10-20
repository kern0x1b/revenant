#import "RevenantCoreMLComputeDevices.h"

@interface MLCPUComputeDevice (RevenantFactory)
- (instancetype)revenant_init;
@end

@implementation MLCPUComputeDevice (RevenantFactory)

- (instancetype)revenant_init
{
    return [super init];
}

@end

static MLCPUComputeDevice *RevenantMLComputeCPUDevice(void)
{
    static MLCPUComputeDevice *device = nil;
    if (!device) {
        device = [[MLCPUComputeDevice alloc] revenant_init];
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
    return @[RevenantMLComputeCPUDevice()];
}

@implementation MLModel (MLComputeDevice)

+ (NSArray<id<MLComputeDeviceProtocol>> *)availableComputeDevices
{
    return MLAllComputeDevices();
}

@end
