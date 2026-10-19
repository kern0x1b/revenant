// MPSBinaryImageKernel, from MPSImageKernel.h:344-345 of the iPhoneOS 16.4 surface. One object per
// release: MPS_CLASS_AVAILABLE_STARTING at :344 says ios(9.0), and the registry row says introduced
// 9.0, so this is a release-9 object and the file is named for that.
//
// WHY THIS FILE EXISTS, and it is the same reason as MPSUnaryImageKernel9.m and for the same reason it
// is not a duplicate of it: the release declares MPSImageArithmetic over this class
// (MPSImageMath.h), so the arithmetic kernels' own hierarchy names it, and nothing in this package
// defined it. Measured over every armv7 object before this file:
//
//   U _OBJC_CLASS_$_MPSBinaryImageKernel     (referenced from the arithmetic objects)
//
// and no @implementation of the class existed anywhere in the package or on origin/main. That is an
// undefined symbol on a real link.
//
// So this is the class. It is NOT the arithmetic: MPSImageArithmetic's two scales and its bias live in
// MPSImageArithmetic13.m's category, which is the other half of the same arrangement the threshold
// kernels have on MPSUnaryImageKernel.
//
// What the header gives it, and what this file does with each:
//   :primaryOffset, :secondaryOffset   MPSOffset, each default {0,0,0}, each "the position of
//                                       clipRect.origin in source coordinates" - in the primary and
//                                       the secondary buffer respectively.
//   :primaryEdgeMode, :secondaryEdgeMode MPSImageEdgeMode, each default "usually MPSImageEdgeModeZero".
//   :clipRect                           MTLRegion, default MPSRectNoClip, intersected with the
//                                       destination bounds as the unary one is.
//
// -primarySourceRegionForDestinationSize: and -secondarySourceRegionForDestinationSize: are answered,
// because each is arithmetic on the offset it names and the clip rectangle, and the header says exactly
// which values it consults: the primary offset and clip rectangle of the binary kernel (:1), and the
// secondary's are the same.
//
// OWED, refused by name rather than answered wrongly: the texture-path encodes and both in-place forms,
// which need a GPU kernel this port does not have and MPSCopyAllocator semantics. The MPSImage path is
// what this package implements; MPSImageArithmetic13.m's category carries it.

#import "CharonMPS.h"
#import "CharonMPSImage.h"

// MPSImageKernel.h declares -encodeToCommandBuffer:primaryImage:secondaryImage:destinationImage: on this
// class and this file does not implement it: MPSImageArithmetic13.m does, in a CATEGORY, because it is
// the four operations' shared walk and not something this base does alone. clang is right that the class
// as compiled here is incomplete, and the category is the other half. Same pragma, same reason, and no
// other diagnostic is silenced in this package.
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

// The zero offset is a literal, not MPSOffsetMake: MPSCoreTypes.h:309 gives MPSOffset three NSIntegers
// and this surface names no constructor for it.
static inline MPSOffset CharonMPSZeroOffset(void)
{
    MPSOffset offset;
    offset.x = 0;
    offset.y = 0;
    offset.z = 0;
    return offset;
}

// The clip rectangle, with the MPSRectNoClip sentinel already resolved against the destination size the
// header hands in. The resolved-region helper answers for an MPSImage and these calls have none - the
// header gives a destination size - so the sentinel is resolved here, and MPSRectNoClip means the whole
// destination, which MPSImageKernel.h states of both classes' clipRect.
static inline MTLRegion CharonMPSBinaryClip(MTLRegion clip, MTLSize destinationSize)
{
    if (clip.size.width < 0 || clip.size.height < 0) {
        clip.origin = MTLOriginMake(0, 0, 0);
        clip.size = destinationSize;
    }
    return clip;
}

// MPSRegion is not MTLRegion - MPSCoreTypes.h:355 gives it an MPSOrigin and an MPSSize of doubles - so
// the result is built field by field rather than cast between the two.
static inline MPSRegion CharonMPSBinaryReadRegion(MTLRegion clip, MPSOffset offset)
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
        _primaryOffset = CharonMPSZeroOffset();
        _secondaryOffset = CharonMPSZeroOffset();
        _primaryEdgeMode = MPSImageEdgeModeZero;
        _secondaryEdgeMode = MPSImageEdgeModeZero;
        _clipRect = MPSRectNoClip;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder device:(id<MTLDevice>)device
{
    // For the reason MPSKernel's own -initWithCoder:device: gives, and which MPSUnaryImageKernel9.m
    // follows: the release's keys are in no header and an invented one would read an archive the release
    // never wrote. The defaults stand and this is not recorded as round-tripping its properties.
    if ((self = [super initWithCoder:aDecoder device:device])) {
        _primaryOffset = CharonMPSZeroOffset();
        _secondaryOffset = CharonMPSZeroOffset();
        _primaryEdgeMode = MPSImageEdgeModeZero;
        _secondaryEdgeMode = MPSImageEdgeModeZero;
        _clipRect = MPSRectNoClip;
    }
    return self;
}

- (MPSRegion)primarySourceRegionForDestinationSize:(MTLSize)destinationSize
{
    return CharonMPSBinaryReadRegion(CharonMPSBinaryClip(_clipRect, destinationSize), _primaryOffset);
}

- (MPSRegion)secondarySourceRegionForDestinationSize:(MTLSize)destinationSize
{
    return CharonMPSBinaryReadRegion(CharonMPSBinaryClip(_clipRect, destinationSize), _secondaryOffset);
}

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
               primaryTexture:(id<MTLTexture>)primaryTexture
             secondaryTexture:(id<MTLTexture>)secondaryTexture
           destinationTexture:(id<MTLTexture>)destinationTexture
{
    CharonMPSRefuse(@"MPSBinaryImageKernel: the texture-path encode is not carried by this port - it is a"
                    @" GPU kernel and this package implements the MPSImage path - so nothing was written");
}

- (BOOL)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
              inPlacePrimaryTexture:(id<MTLTexture> __strong *)inPlacePrimaryTexture
                secondaryTexture:(id<MTLTexture>)secondaryTexture
         fallbackCopyAllocator:(MPSCopyAllocator)copyAllocator
{
    CharonMPSRefuse(@"MPSBinaryImageKernel: the in-place encode needs MPSCopyAllocator semantics this port"
                    @" does not carry, so the texture was left as it was");
    return NO;
}

- (BOOL)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
           inPlaceSecondaryTexture:(id<MTLTexture> __strong *)inPlaceSecondaryTexture
                  primaryTexture:(id<MTLTexture>)primaryTexture
         fallbackCopyAllocator:(MPSCopyAllocator)copyAllocator
{
    CharonMPSRefuse(@"MPSBinaryImageKernel: the in-place encode needs MPSCopyAllocator semantics this port"
                    @" does not carry, so the texture was left as it was");
    return NO;
}

@end
