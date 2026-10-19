// MPSTemporaryMatrix, from the header of the SDK of iOS 16.4. One object per release: the band machinery keeps an
// object whole or drops it whole, so a file here carries the API of exactly one release.

#import "CharonMPS.h"


@implementation MPSTemporaryMatrix {
    NSUInteger _readCount;
}

- (instancetype)charon_mps_withReadCount:(NSUInteger)readCount
{
    _readCount = readCount;
    return self;
}

+ (instancetype)temporaryMatrixWithCommandBuffer:(id<MTLCommandBuffer>)commandBuffer matrixDescriptor:(MPSMatrixDescriptor *)matrixDescriptor
{
    id<MTLDevice> device = [commandBuffer respondsToSelector:@selector(device)] ? [commandBuffer device] : MTLCreateSystemDefaultDevice();
    if (!device)
        device = MTLCreateSystemDefaultDevice();
    // A read count starts at one: a temporary matrix may be written any number of times and read once.
    return [[[self alloc] initWithDevice:device descriptor:matrixDescriptor] charon_mps_withReadCount:1];
}

+ (void)prefetchStorageWithCommandBuffer:(id<MTLCommandBuffer>)commandBuffer matrixDescriptorList:(NSArray<MPSMatrixDescriptor *> *)descriptorList
{
    // Every temporary matrix's storage is its own device buffer, made when its -data is asked for, so
    // there is no cache of free stores for a list of descriptors to be poured into ahead of time. The
    // descriptors are still walked, so a nil in the list is caught here rather than at the kernel
    // that would have used it.
    (void)commandBuffer;
    for (MPSMatrixDescriptor *descriptor in descriptorList) {
        if (!descriptor) {
            NSLog(@"MPSMatrix: a temporary storage list holds no descriptor");
            return;
        }
    }
}

- (instancetype)initWithBuffer:(id<MTLBuffer>)buffer descriptor:(MPSMatrixDescriptor *)descriptor
{
    // The header marks this unavailable for a temporary matrix: a temporary one takes its storage from
    // the release's heap, so a caller that hands it a buffer of its own has asked for something the
    // release would not do either.
    (void)buffer;
    (void)descriptor;
    NSLog(@"MPSTemporaryMatrix: -initWithBuffer:descriptor: makes no temporary matrix; use +temporaryMatrixWithCommandBuffer:matrixDescriptor:");
    return nil;
}

- (NSUInteger)readCount
{
    return _readCount;
}

- (void)setReadCount:(NSUInteger)readCount
{
    _readCount = readCount;
}

@end
