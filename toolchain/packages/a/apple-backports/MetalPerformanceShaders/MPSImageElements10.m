#import "CharonMPS.h"
#import "CharonMPSImage.h"
#import "CharonMPSTemporaryImage.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"

static const float kCharonMPSImageLaplacianWeights[9] = { 0.0f, 1.0f, 0.0f,
                                                           1.0f, -4.0f, 1.0f,
                                                           0.0f, 1.0f, 0.0f };

@interface MPSUnaryImageKernel (CharonMPSConvolutionSeam)
- (void)charon_mps_convolveRegionWithSource:(MPSImage *)source
                                destination:(MPSImage *)destination
                                 kernelWidth:(NSUInteger)kernelWidth
                                kernelHeight:(NSUInteger)kernelHeight
                                    weights:(const float *)weights
                                        bias:(double)bias
                                        what:(NSString *)what;
@end

@implementation MPSImageLaplacian {
    float _bias;
}

@synthesize bias = _bias;

- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    if ((self = [super initWithDevice:device])) {
        _bias = 0.0f;
    }
    return self;
}

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                  sourceImage:(MPSImage *)sourceImage
               destinationImage:(MPSImage *)destinationImage
{
    [self charon_mps_convolveRegionWithSource:sourceImage
                                  destination:destinationImage
                                   kernelWidth:3
                                  kernelHeight:3
                                      weights:kCharonMPSImageLaplacianWeights
                                          bias:(double)self.bias
                                          what:@"MPSImageLaplacian"];
}

@end

@implementation MPSTemporaryImage {
    NSUInteger _readCount;
}

+ (id<MPSImageAllocator>)defaultAllocator
{
    static id<MPSImageAllocator> shared = nil;
    if (!shared)
        shared = CharonMPSTemporaryImageDefaultAllocator();
    return shared;
}

+ (instancetype)temporaryImageWithCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                                imageDescriptor:(MPSImageDescriptor *)imageDescriptor
{
    if (!commandBuffer) {
        CharonMPSRefuse(@"MPSTemporaryImage: no command buffer, so no temporary image was made");
        return nil;
    }
    id<MTLDevice> device = [commandBuffer respondsToSelector:@selector(device)] ? [commandBuffer device] : nil;
    if (!device)
        device = MTLCreateSystemDefaultDevice();
    if (!device || !imageDescriptor) {
        CharonMPSRefuse(@"MPSTemporaryImage: a temporary image needs a command buffer with a device and a "
                        @"descriptor, and one of the two was missing");
        return nil;
    }
    MPSTemporaryImage *image = [[MPSTemporaryImage alloc] initWithDevice:device imageDescriptor:imageDescriptor];
    image->_readCount = 1;
    return image;
}

+ (instancetype)temporaryImageWithCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                              textureDescriptor:(MTLTextureDescriptor *)textureDescriptor
{
    if (!commandBuffer || !textureDescriptor) {
        CharonMPSRefuse(@"MPSTemporaryImage: a temporary image needs a command buffer and a texture "
                        @"descriptor, and one of the two was missing");
        return nil;
    }
    id<MTLDevice> device = [commandBuffer respondsToSelector:@selector(device)] ? [commandBuffer device] : nil;
    if (!device)
        device = MTLCreateSystemDefaultDevice();
    if (!device)
        return nil;
    NSUInteger channels = 1;
    switch (textureDescriptor.pixelFormat) {
    case MTLPixelFormatRG32Float: case MTLPixelFormatRG16Float: case MTLPixelFormatRG8Unorm:
        channels = 2;
        break;
    case MTLPixelFormatRGBA32Float: case MTLPixelFormatRGBA16Float: case MTLPixelFormatRGBA8Unorm:
        channels = 4;
        break;
    default:
        break;
    }
    MPSTemporaryImage *image = [[MPSTemporaryImage alloc] initWithTexture:[device newTextureWithDescriptor:textureDescriptor]
                                                        featureChannels:channels];
    image->_readCount = 1;
    return image;
}

+ (instancetype)temporaryImageWithCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                              textureDescriptor:(MTLTextureDescriptor *)textureDescriptor
                                featureChannels:(NSUInteger)featureChannels
{
    if (!commandBuffer || !textureDescriptor) {
        CharonMPSRefuse(@"MPSTemporaryImage: a temporary image needs a command buffer and a texture "
                        @"descriptor, and one of the two was missing");
        return nil;
    }
    id<MTLDevice> device = [commandBuffer respondsToSelector:@selector(device)] ? [commandBuffer device] : nil;
    if (!device)
        device = MTLCreateSystemDefaultDevice();
    if (!device)
        return nil;
    MPSTemporaryImage *image = [[MPSTemporaryImage alloc] initWithTexture:[device newTextureWithDescriptor:textureDescriptor]
                                                        featureChannels:featureChannels ? featureChannels : 1];
    image->_readCount = 1;
    return image;
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
