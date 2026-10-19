// MPSUnaryImageKernel, from MPSImageKernel.h of the iPhoneOS 16.4 surface. One object per release: the
// class arrived in iOS 9, and the band machinery keeps an object whole or drops it whole.
//
// WHY THIS FILE EXISTS. MPSImageThreshold13.m carries a CATEGORY on this class - the encode the five
// threshold kernels share - and a category cannot create the class it is written on. The five kernels
// and their category therefore reference _OBJC_CLASS_$_MPSUnaryImageKernel, and nothing in this package
// defined it: on an armv7 link it was an undefined symbol, measured as
//   MPSImageThreshold13.o  U _OBJC_CLASS_$_MPSUnaryImageKernel
// and neither origin/main nor any other band defined it either. So this is the class, written here.
//
// What the header gives it, and what this file does with each:
//   :offset      MPSOffset, default {0,0,0} - the place in source coordinates where the clip origin sits,
//                and with that default the two top left corners line up with each other
//   :clipRect    MTLRegion, default MPSRectNoClip - the overlap of the clip rectangle with the destination is used,
//                with MPSRectNoClip meaning the whole destination. The sentinel
//                is resolved against the image by CharonMPSImageResolvedRegion before anything is read,
//                which is why no texture ever sees xoffset + width = -2.
//   :edgeMode    MPSImageEdgeMode, default usually MPSImageEdgeModeZero - the header's own hedge, and
//                this is that case: a filter that reads off the edge is not what this base is.
//
// -sourceRegionForDestinationSize: is answered, because it is arithmetic on the two properties above and
// the header says exactly what it consults: the offset and clipRect parameters, which together fix how much of the source is read.
//
// OWED, and refused by name rather than answered wrongly:
//   -encodeToCommandBuffer:sourceTexture:destinationTexture: and its in-place and
//   -encodeToCommandBuffer:sourceImage:destinationImage: variants on raw textures. The MPSImage path is
//   what this package implements; the texture path is a GPU kernel this port does not have, and the
//   in-place form additionally needs MPSCopyAllocator semantics. A caller that reaches them is told so
//   rather than handed a texture nobody wrote.

#import "CharonMPS.h"
#import "CharonMPSImage.h"

// MPSImageKernel.h declares -encodeToCommandBuffer:sourceImage:destinationImage: on this class, and
// this file does not implement it: MPSImageThreshold13.m implements it, in a CATEGORY on this class,
// because it is the five threshold kernels' shared walk rather than anything this base does on its own.
// clang is right that the class as compiled here is incomplete, and the category is the other half. The
// same pragma MPSImageThreshold13.m carries for the same reason, and no diagnostic is silenced anywhere
// else in this package.
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
        _offset = (MPSOffset){ .x = 0, .y = 0, .z = 0 };   // MPSCoreTypes.h:309, no MPSOffsetMake on this surface
        _clipRect = MPSRectNoClip;                       // MPSImageKernel.h: default, the whole destination
        _edgeMode = MPSImageEdgeModeZero;                // MPSImageKernel.h: "usually MPSImageEdgeModeZero"
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder device:(id<MTLDevice>)device
{
    // For the reason MPSKernel's own -initWithCoder:device: gives: the release's keys are in no header
    // and an invented one would read an archive the release never wrote. The defaults above stand, and
    // this kernel is not recorded as round-tripping its properties.
    if ((self = [super initWithCoder:aDecoder device:device])) {
        _offset = (MPSOffset){ .x = 0, .y = 0, .z = 0 };   // MPSCoreTypes.h:309, no MPSOffsetMake on this surface
        _clipRect = MPSRectNoClip;
        _edgeMode = MPSImageEdgeModeZero;
    }
    return self;
}

- (MPSRegion)sourceRegionForDestinationSize:(MTLSize)destinationSize
{
    // The header (MPSImageKernel.h) takes the size of the full destination image and returns the region of the full
    // source image that is read. The destination's clip rectangle, moved by the offset, is that region, since the offset gives the
    // position of the clip origin in source coordinates. MPSRectNoClip means the whole destination, and MPSRegion is MTLRegion on the
    // 16.4 surface, so the two are the same type and no conversion stands between them.
    // MPSRegion is not MTLRegion: MPSCoreTypes.h:355 gives it an MPSOrigin and an MPSSize of doubles,
    // where MTLRegion has an MTLOrigin and an MTLSize of NSUInteger. The sentinel is resolved here, on
    // the clip rectangle itself, because the resolved-region helper answers for an MPSImage and this
    // call has none - the header gives a destination size, not an image.
    MTLRegion clip = _clipRect;
    if (clip.size.width < 0 || clip.size.height < 0) {
        clip.origin = MTLOriginMake(0, 0, 0);
        clip.size = destinationSize;                    // MPSRectNoClip: the whole destination
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
