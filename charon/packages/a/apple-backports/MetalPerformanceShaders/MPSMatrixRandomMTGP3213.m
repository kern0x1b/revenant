// MPSMatrixRandomMTGP32, from the header of the SDK of iOS 16.4. One object per release: the band machinery keeps an
// object whole or drops it whole, so a file here carries the API of exactly one release.

#import "CharonMPS.h"

#pragma clang diagnostic ignored "-Wprotocol"
#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation MPSMatrixRandomMTGP32

- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    if (!(self = [super initWithDevice:device charonRandom:NO]))
        return nil;
    return [self charon_mps_configureWithDataType:MPSDataTypeUInt32 seed:0 distribution:nil];
}

- (instancetype)initWithDevice:(id<MTLDevice>)device destinationDataType:(MPSDataType)destinationDataType seed:(NSUInteger)seed
{
    if (!(self = [super initWithDevice:device charonRandom:NO]))
        return nil;
    return [self charon_mps_configureWithDataType:destinationDataType seed:(uint32_t)seed distribution:nil];
}

- (instancetype)initWithDevice:(id<MTLDevice>)device destinationDataType:(MPSDataType)destinationDataType seed:(NSUInteger)seed distributionDescriptor:(MPSMatrixRandomDistributionDescriptor *)distributionDescriptor
{
    if (!(self = [super initWithDevice:device charonRandom:NO]))
        return nil;
    return [self charon_mps_configureWithDataType:destinationDataType seed:(uint32_t)seed distribution:distributionDescriptor];
}

- (void)synchronizeStateOnCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
{
    (void)commandBuffer;
}

@end
