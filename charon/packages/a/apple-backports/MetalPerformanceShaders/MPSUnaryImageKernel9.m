#import "CharonMPS.h"
#import "CharonMPSImage.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation MPSUnaryImageKernel {
    MPSOffset _offset;
    MTLRegion _clipRect;
    MPSImageEdgeMode _edgeMode;
}

@synthesize offset = _offset;
@synthesize clipRect = _clipRect;
@synthesize edgeMode = _edgeMode;

- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    if ((self = [super initWithDevice:device])) {
        _offset = (MPSOffset){ .x = 0, .y = 0, .z = 0 };
        _clipRect = MPSRectNoClip;
        _edgeMode = MPSImageEdgeModeZero;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder device:(id<MTLDevice>)device
{
    if ((self = [super initWithCoder:aDecoder device:device])) {
        _offset = (MPSOffset){ .x = 0, .y = 0, .z = 0 };
        _clipRect = MPSRectNoClip;
        _edgeMode = MPSImageEdgeModeZero;
    }
    return self;
}

- (MPSRegion)sourceRegionForDestinationSize:(MTLSize)destinationSize
{
    MTLRegion clip = _clipRect;
    if (clip.size.width < 0 || clip.size.height < 0) {
        clip.origin = MTLOriginMake(0, 0, 0);
        clip.size = destinationSize;
    }
    MPSRegion read;
    read.origin.x = (double)(clip.origin.x + _offset.x);
    read.origin.y = (double)(clip.origin.y + _offset.y);
    read.origin.z = (double)_offset.z;
    read.size.width = (double)clip.size.width;
    read.size.height = (double)clip.size.height;
    read.size.depth = (double)clip.size.depth;
    return read;
}

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                sourceTexture:(id<MTLTexture>)sourceTexture
           destinationTexture:(id<MTLTexture>)destinationTexture
{
    CharonMPSRefuse(@"MPSUnaryImageKernel: -encodeToCommandBuffer:sourceTexture:destinationTexture: is"
                    @" not carried by this port - it is a GPU kernel and this package implements the"
                    @" MPSImage path - so nothing was written");
}

- (BOOL)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                inPlaceTexture:(id<MTLTexture> __strong *)texture
       fallbackCopyAllocator:(MPSCopyAllocator)copyAllocator
{
    CharonMPSRefuse(@"MPSUnaryImageKernel: the in-place encode needs MPSCopyAllocator semantics this port"
                    @" does not carry, so the texture was left as it was");
    return NO;
}

@end
