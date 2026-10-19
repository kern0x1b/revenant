// MPSMatrixRandomPhilox, from the header of the SDK of iOS 16.4. One object per release: the band machinery keeps an
// object whole or drops it whole, so a file here carries the API of exactly one release.

#import "CharonMPS.h"


@implementation MPSMatrixRandomPhilox

- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    if (!(self = [super initWithDevice:device charonRandom:YES]))
        return nil;
    return [self charon_mps_configureWithDataType:MPSDataTypeUInt32 seed:0 distribution:nil];
}

- (instancetype)initWithDevice:(id<MTLDevice>)device destinationDataType:(MPSDataType)destinationDataType seed:(NSUInteger)seed
{
    if (!(self = [super initWithDevice:device charonRandom:YES]))
        return nil;
    return [self charon_mps_configureWithDataType:destinationDataType seed:(uint32_t)seed distribution:nil];
}

- (instancetype)initWithDevice:(id<MTLDevice>)device destinationDataType:(MPSDataType)destinationDataType seed:(NSUInteger)seed distributionDescriptor:(MPSMatrixRandomDistributionDescriptor *)distributionDescriptor
{
    if (!(self = [super initWithDevice:device charonRandom:YES]))
        return nil;
    return [self charon_mps_configureWithDataType:destinationDataType seed:(uint32_t)seed distribution:distributionDescriptor];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder device:(id<MTLDevice>)device
{
    return [super initWithCoder:aDecoder device:device];
}

- (void)synchronizeStateOnCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
{
    // The generator's state is the caller's seed and this object's own fields, all of them on the CPU,
    // so there is nothing on a device to read back.
    (void)commandBuffer;
}

@end
