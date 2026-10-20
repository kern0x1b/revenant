#import "RevenantMPS.h"
#import "RevenantMPSImage.h"

NS_ASSUME_NONNULL_BEGIN

@interface MPSNNImageNode (RevenantMPSNN)
- (MPSImage *)revenant_mps_image;
- (void)revenant_mps_setImage:(MPSImage *)image;
@end

@interface MPSNNStateNode (RevenantMPSNN)
- (MPSState *)revenant_mps_state;
- (void)revenant_mps_setState:(MPSState *)state;
@end

@interface MPSImage (RevenantMPSNN)
- (MPSImageDescriptor *)revenant_mps_descriptor;
@end

@interface MPSNNFilterNode (RevenantMPSNN)
- (instancetype)initWithDevice:(nullable id<MTLDevice>)device;

- (NSArray<MPSNNImageNode *> *)revenant_mps_sourceNodes;
- (void)revenant_mps_setSourceNodes:(NSArray<MPSNNImageNode *> *)nodes;
- (void)revenant_mps_addSourceNode:(MPSNNImageNode *)node;
- (MPSKernel *)revenant_mps_kernel;
- (MPSImage *)revenant_mps_sourceImageAtIndex:(NSUInteger)index;
- (void)revenant_mps_setSourceImages:(NSArray<MPSImage *> *)images;
- (MPSImage *)revenant_mps_destinationImage;
- (void)revenant_mps_setDestinationImage:(MPSImage *)image;
- (MPSImageDescriptor *)revenant_mps_destinationDescriptorForSource:(MPSImageDescriptor *)source;
- (void)revenant_mps_setDevice:(id<MTLDevice>)device;
- (id<MTLDevice>)revenant_mps_device;
+ (NSMapTable *)revenant_mps_producers;
- (void)revenant_mps_encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer;
@end

@interface MPSNNBinaryArithmeticNode (RevenantMPSNN)
+ (Class)revenant_mps_kernelClass;
@end

@interface MPSCNNPoolingNode (RevenantMPSNN)
+ (Class)revenant_mps_kernelClass;
@end

static inline long RevenantMPSNNDestSize(long sourceSize, long stride, long filterWindowSize, MPSNNPaddingMethod method)
{
    long style = (long)((method >> 4) & 0x3) - 1;
    long size = sourceSize + style * (filterWindowSize - 1);
    return (size + stride - 1) / stride;
}

static inline long RevenantMPSNNReadSize(long destinationSize, long stride, long filterWindowSize)
{
    return (destinationSize - 1) * stride + filterWindowSize;
}

static inline long RevenantMPSNNOffset(long sourceSize, long stride, long filterWindowSize, MPSNNPaddingMethod method)
{
    long correction = filterWindowSize / 2;
    long destinationSize = RevenantMPSNNDestSize(sourceSize, stride, filterWindowSize, method);
    long readSize = RevenantMPSNNReadSize(destinationSize, stride, filterWindowSize);
    long extraSize = readSize - sourceSize;
    long leftExtraPixels = (extraSize + 0) / 2;
    return correction - leftExtraPixels;
}

NS_ASSUME_NONNULL_END
