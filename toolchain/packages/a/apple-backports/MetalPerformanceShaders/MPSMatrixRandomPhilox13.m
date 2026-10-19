#import "RevenantMPS.h"


@implementation MPSMatrixRandomPhilox

- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    if (!(self = [super initWithDevice:device revenantRandom:YES]))
        return nil;
    return [self revenant_mps_configureWithDataType:MPSDataTypeUInt32 seed:0 distribution:nil];
}

- (instancetype)initWithDevice:(id<MTLDevice>)device destinationDataType:(MPSDataType)destinationDataType seed:(NSUInteger)seed
{
    if (!(self = [super initWithDevice:device revenantRandom:YES]))
        return nil;
    return [self revenant_mps_configureWithDataType:destinationDataType seed:(uint32_t)seed distribution:nil];
}

- (instancetype)initWithDevice:(id<MTLDevice>)device destinationDataType:(MPSDataType)destinationDataType seed:(NSUInteger)seed distributionDescriptor:(MPSMatrixRandomDistributionDescriptor *)distributionDescriptor
{
    if (!(self = [super initWithDevice:device revenantRandom:YES]))
        return nil;
    return [self revenant_mps_configureWithDataType:destinationDataType seed:(uint32_t)seed distribution:distributionDescriptor];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder device:(id<MTLDevice>)device
{
    return [super initWithCoder:aDecoder device:device];
}

- (void)synchronizeStateOnCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
{
    (void)commandBuffer;
}

@end
