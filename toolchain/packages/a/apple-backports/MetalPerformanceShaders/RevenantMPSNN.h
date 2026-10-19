#import "CharonMPS.h"
#import "CharonMPSImage.h"

NS_ASSUME_NONNULL_BEGIN

@interface MPSNNImageNode (CharonMPSNN)
- (MPSImage *)charon_mps_image;
- (void)charon_mps_setImage:(MPSImage *)image;
@end

@interface MPSNNStateNode (CharonMPSNN)
- (MPSState *)charon_mps_state;
- (void)charon_mps_setState:(MPSState *)state;
@end

@interface MPSImage (CharonMPSNN)
- (MPSImageDescriptor *)charon_mps_descriptor;
@end

@interface MPSNNFilterNode (CharonMPSNN)
- (instancetype)initWithDevice:(nullable id<MTLDevice>)device;

- (NSArray<MPSNNImageNode *> *)charon_mps_sourceNodes;
- (void)charon_mps_setSourceNodes:(NSArray<MPSNNImageNode *> *)nodes;
- (void)charon_mps_addSourceNode:(MPSNNImageNode *)node;
- (MPSKernel *)charon_mps_kernel;
- (MPSImage *)charon_mps_sourceImageAtIndex:(NSUInteger)index;
- (void)charon_mps_setSourceImages:(NSArray<MPSImage *> *)images;
- (MPSImage *)charon_mps_destinationImage;
- (void)charon_mps_setDestinationImage:(MPSImage *)image;
- (MPSImageDescriptor *)charon_mps_destinationDescriptorForSource:(MPSImageDescriptor *)source;
- (void)charon_mps_setDevice:(id<MTLDevice>)device;
- (id<MTLDevice>)charon_mps_device;
+ (NSMapTable *)charon_mps_producers;
- (void)charon_mps_encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer;
@end

@interface MPSNNBinaryArithmeticNode (CharonMPSNN)
+ (Class)charon_mps_kernelClass;
@end

@interface MPSCNNPoolingNode (CharonMPSNN)
+ (Class)charon_mps_kernelClass;
@end

static inline long CharonMPSNNDestSize(long sourceSize, long stride, long filterWindowSize, MPSNNPaddingMethod method)
{
    long style = (long)((method >> 4) & 0x3) - 1;
    long size = sourceSize + style * (filterWindowSize - 1);
    return (size + stride - 1) / stride;
}

static inline long CharonMPSNNReadSize(long destinationSize, long stride, long filterWindowSize)
{
    return (destinationSize - 1) * stride + filterWindowSize;
}

static inline long CharonMPSNNOffset(long sourceSize, long stride, long filterWindowSize, MPSNNPaddingMethod method)
{
    long correction = filterWindowSize / 2;
    long destinationSize = CharonMPSNNDestSize(sourceSize, stride, filterWindowSize, method);
    long readSize = CharonMPSNNReadSize(destinationSize, stride, filterWindowSize);
    long extraSize = readSize - sourceSize;
    long leftExtraPixels = (extraSize + 0) / 2;
    return correction - leftExtraPixels;
}

NS_ASSUME_NONNULL_END
