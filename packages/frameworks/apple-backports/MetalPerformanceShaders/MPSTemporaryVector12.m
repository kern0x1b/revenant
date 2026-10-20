#import "RevenantMPS.h"


@implementation MPSTemporaryVector {
    NSUInteger _readCount;
}

- (instancetype)revenant_mps_withReadCount:(NSUInteger)readCount
{
    _readCount = readCount;
    return self;
}

+ (instancetype)temporaryVectorWithCommandBuffer:(id<MTLCommandBuffer>)commandBuffer descriptor:(MPSVectorDescriptor *)descriptor
{
    id<MTLDevice> device = [commandBuffer respondsToSelector:@selector(device)] ? [commandBuffer device] : MTLCreateSystemDefaultDevice();
    if (!device)
        device = MTLCreateSystemDefaultDevice();
    return [[[self alloc] initWithDevice:device descriptor:descriptor] revenant_mps_withReadCount:1];
}

+ (void)prefetchStorageWithCommandBuffer:(id<MTLCommandBuffer>)commandBuffer descriptorList:(NSArray<MPSVectorDescriptor *> *)descriptorList
{
    (void)commandBuffer;
    for (MPSVectorDescriptor *descriptor in descriptorList) {
        if (!descriptor) {
            NSLog(@"MPSVector: a temporary storage list holds no descriptor");
            return;
        }
    }
}

- (instancetype)initWithBuffer:(id<MTLBuffer>)buffer descriptor:(MPSVectorDescriptor *)descriptor
{
    (void)buffer;
    (void)descriptor;
    NSLog(@"MPSTemporaryVector: -initWithBuffer:descriptor: makes no temporary vector; use +temporaryVectorWithCommandBuffer:descriptor:");
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
