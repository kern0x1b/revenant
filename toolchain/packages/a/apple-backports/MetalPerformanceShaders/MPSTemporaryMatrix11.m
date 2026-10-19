#import "RevenantMPS.h"


@implementation MPSTemporaryMatrix {
    NSUInteger _readCount;
}

- (instancetype)revenant_mps_withReadCount:(NSUInteger)readCount
{
    _readCount = readCount;
    return self;
}

+ (instancetype)temporaryMatrixWithCommandBuffer:(id<MTLCommandBuffer>)commandBuffer matrixDescriptor:(MPSMatrixDescriptor *)matrixDescriptor
{
    id<MTLDevice> device = [commandBuffer respondsToSelector:@selector(device)] ? [commandBuffer device] : MTLCreateSystemDefaultDevice();
    if (!device)
        device = MTLCreateSystemDefaultDevice();
    return [[[self alloc] initWithDevice:device descriptor:matrixDescriptor] revenant_mps_withReadCount:1];
}

+ (void)prefetchStorageWithCommandBuffer:(id<MTLCommandBuffer>)commandBuffer matrixDescriptorList:(NSArray<MPSMatrixDescriptor *> *)descriptorList
{
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
