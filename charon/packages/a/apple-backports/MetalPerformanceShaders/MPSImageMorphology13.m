// MPSImageMorphology, from MPSImageMorphology.h of the iPhoneOS 26.2 surface. One object per release:
// every class in this file is MPS_CLASS_AVAILABLE_STARTING ios(9.0) (:21, :71, :95, :173).
//
// Four classes, and all four are the same thing with two choices in it: the maximum or the minimum over a
// window centred on each pixel.
//
//   :17-18 MPSImageAreaMax : MPSUnaryImageKernel takes the maximum pixel value over a rectangular region
//        centred on each pixel of the source. With several channels, each one is processed on its own, so the
//        window is rectangular and centred, and each channel is reduced separately.
//   :72 MPSImageAreaMin : MPSImageAreaMax - the minimum over the same window.
//   :94 MPSImageDilate : MPSUnaryImageKernel - the maximum over the same window, but with the caller's probe:
//        :129 -initWithDevice:kernelHeight:kernelWidth:values: takes the values that make up the dilate probe,
//        and :116 says each probe describes a 3D surface of values, so the probe is a height per tap and the
//        result is the maximum of source plus probe.
//   :174 MPSImageErode : MPSImageDilate - the minimum over the same probe.
//
// THE EDGE IS CLAMPED HERE, and that is the one fact that makes this family unlike the convolution's:
// :69 and :93 both state the edgeMode is fixed to clamp for this filter.
// So a window reaching off the edge REPLICATES the border rather than reading zero, and this file clamps
// rather than multiplying by zero. Getting that wrong would be invisible on an interior pixel and wrong on
// every edge pixel, which is why the case runs a window wider than the image on purpose.
//
// The odd-dimension rule is stated at :117-119 for Dilate's kernelWidth and kernelHeight and is applied
// here to both pairs of classes, since a window that is not odd has no centre pixel to sit on and the
// header calls the window "centered around each pixel" (:17).
//
// EXACT, and compared exactly. A maximum and a minimum SELECT a value the source already holds - nothing
// is added and nothing is multiplied - so the answer is bit-for-bit one of the inputs and a tolerance would
// hide a real defect rather than absorb a rounding. That is the opposite of the convolution family, which
// accumulates in double and stores float32 and so carries one ulp, and the reference states which of the
// two it is doing.

#import "CharonMPS.h"
#import "CharonMPSImage.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"
// The same one the reduction and convolution families carry, recorded in coordination/crutches.md: the
// SDK marks each class's -initWithDevice: NS_UNAVAILABLE (:60, :132) and makes its parameterised
// initializer designated, so clang wants a superclass designated call this path cannot make.
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

// Which of the two, and the probe. AreaMax and AreaMin are Dilate and Erode with a probe of all ones, so
// they share the walk rather than having a second copy of it.
typedef NS_ENUM(NSInteger, CharonMPSMorphologyPick) {
    CharonMPSMorphologyMax = 0,
    CharonMPSMorphologyMin,
};

static void CharonMPSMorphologyRegion(MPSImage *source, MPSImage *destination, MTLRegion read,
                                      NSUInteger kernelWidth, NSUInteger kernelHeight,
                                      const float *probe, CharonMPSMorphologyPick pick, NSString *what)
{
    CharonMPSImageLayout in = CharonMPSImageLayoutOf(source);
    CharonMPSImageLayout out = CharonMPSImageLayoutOf(destination);
    if (!kernelWidth || !kernelHeight) {
        CharonMPSRefuse(@"%@: a %lux%lu window has no centre, so nothing was written", what,
                        (unsigned long)kernelWidth, (unsigned long)kernelHeight);
        return;
    }
    CharonMPSImageLayout slice = in;
    slice.count = read.size.width * read.size.height * in.channels;
    void *from = CharonMPSImageReadRegion(source, &slice, read, what);
    if (slice.count && !from)
        return;

    NSUInteger halfW = kernelWidth / 2, halfH = kernelHeight / 2;
    float *answer = calloc(slice.count ? slice.count : 1, sizeof(float));
    if (!answer) {
        CharonMPSRefuse(@"%@: no memory for a %lux%lu result, so nothing was written", what,
                        (unsigned long)read.size.width, (unsigned long)read.size.height);
        return;
    }
    // Each channel is reduced on its own, per :18 - "each channel is processed in" its own window - so the
    // channel is a third loop and not a divide of the buffer.
    for (NSUInteger channel = 0; channel < in.channels; channel++) {
        for (NSUInteger y = 0; y < read.size.height; y++) {
            for (NSUInteger x = 0; x < read.size.width; x++) {
                double best = 0.0;
                for (NSUInteger ky = 0; ky < kernelHeight; ky++) {
                    for (NSUInteger kx = 0; kx < kernelWidth; kx++) {
                        long sy = (long)(read.origin.y + y + ky) - (long)halfH;
                        long sx = (long)(read.origin.x + x + kx) - (long)halfW;
                        // MPSImageMorphology.h:69 and :93 - the edge mode is fixed at clamp for this filter, so an off-edge tap takes the nearest edge
                        // value rather than zero. This is the difference from the convolution family.
                        if (sy < 0) sy = 0;
                        if (sx < 0) sx = 0;
                        if (sy >= (long)in.height) sy = (long)in.height - 1;
                        if (sx >= (long)in.width) sx = (long)in.width - 1;
                        NSUInteger index = (NSUInteger)sy * in.width + (NSUInteger)sx;
                        double value = CharonMPSImageLoad(from, &slice,
                                                         CharonMPSImageIndex(&slice, index, channel));
                        double candidate = probe ? (value + (double)probe[ky * kernelWidth + kx]) : value;
                        if (kx == 0 && ky == 0)
                            best = candidate;
                        else if (pick == CharonMPSMorphologyMax ? candidate > best : candidate < best)
                            best = candidate;
                    }
                }
                // A maximum and a minimum select: the answer is one of the values that went in, so it is
                // stored without arithmetic and is bit-for-bit comparable.
                answer[(y * read.size.width + x) * in.channels + channel] = (float)best;
            }
        }
    }
    CharonMPSImageWriteRegion(destination, &out, read, answer, what);
    free(answer);
    CharonMPSConsumeReadCount(source);
}

@implementation MPSImageAreaMax {
    NSUInteger _kernelWidth, _kernelHeight;
}

@synthesize kernelWidth = _kernelWidth;
@synthesize kernelHeight = _kernelHeight;

// :42 - initWithDevice:kernelHeight:kernelWidth: is the designated initializer, and :117-119's "Must be an
// odd number" is applied to both, since the window is "centered around each pixel" (:17).
- (instancetype)initWithDevice:(id<MTLDevice>)device
                  kernelHeight:(NSUInteger)kernelHeight
                   kernelWidth:(NSUInteger)kernelWidth
{
    if ((self = [super initWithDevice:device])) {
        if (!kernelWidth || !kernelHeight || !(kernelWidth % 2) || !(kernelHeight % 2)) {
            CharonMPSRefuse(@"MPSImageAreaMax: a %lux%lu window is refused - it must be odd so the window"
                            @" has a centre, so no object was made", (unsigned long)kernelWidth,
                            (unsigned long)kernelHeight);
            return nil;
        }
        _kernelWidth = kernelWidth;
        _kernelHeight = kernelHeight;
    }
    return self;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    CharonMPSRefuse(@"MPSImageAreaMax: -initWithDevice: is NS_UNAVAILABLE - the"
                    @" window is what makes the filter, so no object was made");
    return nil;
}

// The probe is this object's: a base class takes an operation and its subclass supplies the other half.
- (CharonMPSMorphologyPick)charon_pick
{
    return CharonMPSMorphologyMax;
}

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                   sourceImage:(MPSImage *)sourceImage
             destinationImage:(MPSImage *)destinationImage
{
    NSString *what = NSStringFromClass([self class]);
    if (!CharonMPSImageUsable(sourceImage, what)) {
        CharonMPSRefuse(@"%@: the source image cannot be walked", what);
        return;
    }
    if (!destinationImage) {
        CharonMPSRefuse(@"%@: no destination image, so nothing was written", what);
        return;
    }
    // NULL probe: an area filter has no probe at all, it is the bare maximum or minimum of the window.
    CharonMPSMorphologyRegion(sourceImage, destinationImage,
                              CharonMPSImageResolvedRegion(destinationImage, self.clipRect),
                              _kernelWidth, _kernelHeight, NULL, [self charon_pick], what);
}

@end

// MPSImageAreaMin : MPSImageAreaMax (:72) - the same window, the other half of the choice.
@implementation MPSImageAreaMin
- (CharonMPSMorphologyPick)charon_pick
{
    return CharonMPSMorphologyMin;
}
@end

@implementation MPSImageDilate {
    NSUInteger _kernelWidth, _kernelHeight;
    NSMutableData *_probe;
}

@synthesize kernelWidth = _kernelWidth;
@synthesize kernelHeight = _kernelHeight;

// :129 - initWithDevice:kernelHeight:kernelWidth:values: is the designated initializer. Its values argument is
// the set of values the dilate probe is built from, and :116 says each probe describes a 3D surface of values,
// so it is one height per tap, row-major over kernelWidth like the convolution family's weights.
- (instancetype)initWithDevice:(id<MTLDevice>)device
                  kernelHeight:(NSUInteger)kernelHeight
                   kernelWidth:(NSUInteger)kernelWidth
                       values:(const float *)values
{
    if ((self = [super initWithDevice:device])) {
        if (!kernelWidth || !kernelHeight || !(kernelWidth % 2) || !(kernelHeight % 2)) {
            CharonMPSRefuse(@"MPSImageDilate: a %lux%lu window is refused - the width and the height have to be odd,"
                            @" so no object was made", (unsigned long)kernelWidth,
                            (unsigned long)kernelHeight);
            return nil;
        }
        if (!values) {
            CharonMPSRefuse(@"MPSImageDilate: no probe was given and a dilate probe IS the filter, so no"
                            @" object was made");
            return nil;
        }
        _kernelWidth = kernelWidth;
        _kernelHeight = kernelHeight;
        _probe = [NSMutableData dataWithLength:kernelWidth * kernelHeight * sizeof(float)];
        if (!_probe) {
            CharonMPSRefuse(@"MPSImageDilate: no memory for a %lux%lu probe, so no object was made",
                            (unsigned long)kernelWidth, (unsigned long)kernelHeight);
            return nil;
        }
        [_probe replaceBytesInRange:NSMakeRange(0, kernelWidth * kernelHeight * sizeof(float))
                         withBytes:values];
    }
    return self;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    CharonMPSRefuse(@"MPSImageDilate: -initWithDevice: is NS_UNAVAILABLE - the"
                    @" window and the probe are what make the filter, so no object was made");
    return nil;
}

- (CharonMPSMorphologyPick)charon_pick
{
    return CharonMPSMorphologyMax;
}

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                   sourceImage:(MPSImage *)sourceImage
             destinationImage:(MPSImage *)destinationImage
{
    NSString *what = NSStringFromClass([self class]);
    if (!CharonMPSImageUsable(sourceImage, what)) {
        CharonMPSRefuse(@"%@: the source image cannot be walked", what);
        return;
    }
    if (!destinationImage) {
        CharonMPSRefuse(@"%@: no destination image, so nothing was written", what);
        return;
    }
    CharonMPSMorphologyRegion(sourceImage, destinationImage,
                              CharonMPSImageResolvedRegion(destinationImage, self.clipRect),
                              _kernelWidth, _kernelHeight, (const float *)_probe.bytes,
                              [self charon_pick], what);
}

@end

// MPSImageErode : MPSImageDilate (:174) - the same probe, the other half of the choice.
@implementation MPSImageErode
- (CharonMPSMorphologyPick)charon_pick
{
    return CharonMPSMorphologyMin;
}
@end
