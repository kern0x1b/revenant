#import "RevenantMPS.h"
#import "RevenantMPSImage.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation MPSBinaryImageKernel {
    MPSOffset _primaryOffset, _secondaryOffset;
    MPSImageEdgeMode _primaryEdgeMode, _secondaryEdgeMode;
    MTLRegion _clipRect;
}

@synthesize primaryOffset = _primaryOffset;
@synthesize secondaryOffset = _secondaryOffset;
@synthesize primaryEdgeMode = _primaryEdgeMode;
@synthesize secondaryEdgeMode = _secondaryEdgeMode;
@synthesize clipRect = _clipRect;

static inline MPSOffset RevenantMPSZeroOffset(void)
{
    MPSOffset offset;
    offset.x = 0;
    offset.y = 0;
    offset.z = 0;
    return offset;
}

static inline MTLRegion RevenantMPSBinaryClip(MTLRegion clip, MTLSize destinationSize)
{
    if (clip.size.width < 0 || clip.size.height < 0) {
        clip.origin = MTLOriginMake(0, 0, 0);
        clip.size = destinationSize;
    }
    return clip;
}

static inline MPSRegion RevenantMPSBinaryReadRegion(MTLRegion clip, MPSOffset offset)
{
    MPSRegion read;
    read.origin.x = (double)(clip.origin.x + offset.x);
    read.origin.y = (double)(clip.origin.y + offset.y);
    read.origin.z = (double)offset.z;
    read.size.width = (double)clip.size.width;
    read.size.height = (double)clip.size.height;
    read.size.depth = (double)clip.size.depth;
    return read;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    if ((self = [super initWithDevice:device])) {
        _primaryOffset = RevenantMPSZeroOffset();
        _secondaryOffset = RevenantMPSZeroOffset();
        _primaryEdgeMode = MPSImageEdgeModeZero;
        _secondaryEdgeMode = MPSImageEdgeModeZero;
        _clipRect = MPSRectNoClip;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder device:(id<MTLDevice>)device
{
    if ((self = [super initWithCoder:aDecoder device:device])) {
        _primaryOffset = RevenantMPSZeroOffset();
        _secondaryOffset = RevenantMPSZeroOffset();
        _primaryEdgeMode = MPSImageEdgeModeZero;
        _secondaryEdgeMode = MPSImageEdgeModeZero;
        _clipRect = MPSRectNoClip;
    }
    return self;
}

- (MPSRegion)primarySourceRegionForDestinationSize:(MTLSize)destinationSize
{
    return RevenantMPSBinaryReadRegion(RevenantMPSBinaryClip(_clipRect, destinationSize), _primaryOffset);
}

- (MPSRegion)secondarySourceRegionForDestinationSize:(MTLSize)destinationSize
{
    return RevenantMPSBinaryReadRegion(RevenantMPSBinaryClip(_clipRect, destinationSize), _secondaryOffset);
}

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
               primaryTexture:(id<MTLTexture>)primaryTexture
             secondaryTexture:(id<MTLTexture>)secondaryTexture
           destinationTexture:(id<MTLTexture>)destinationTexture
{
    RevenantMPSRefuse(@"MPSBinaryImageKernel: the texture-path encode is not carried by this port - it is a"
                    @" GPU kernel and this package implements the MPSImage path - so nothing was written");
}

- (BOOL)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
              inPlacePrimaryTexture:(id<MTLTexture> __strong *)inPlacePrimaryTexture
                secondaryTexture:(id<MTLTexture>)secondaryTexture
         fallbackCopyAllocator:(MPSCopyAllocator)copyAllocator
{
    RevenantMPSRefuse(@"MPSBinaryImageKernel: the in-place encode needs MPSCopyAllocator semantics this port"
                    @" does not carry, so the texture was left as it was");
    return NO;
}

- (BOOL)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
           inPlaceSecondaryTexture:(id<MTLTexture> __strong *)inPlaceSecondaryTexture
                  primaryTexture:(id<MTLTexture>)primaryTexture
         fallbackCopyAllocator:(MPSCopyAllocator)copyAllocator
{
    RevenantMPSRefuse(@"MPSBinaryImageKernel: the in-place encode needs MPSCopyAllocator semantics this port"
                    @" does not carry, so the texture was left as it was");
    return NO;
}

@end
