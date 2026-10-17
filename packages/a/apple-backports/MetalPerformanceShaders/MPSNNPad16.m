// MPSNNPad, the one padding kernel of MPSNNReshape.h, from the iPhoneOS 16.4 surface.
//
// ONE OBJECT FOR ONE RELEASE, and the release is 16.0 rather than the 12.1 the header's own annotation
// reads (MPSNNReshape.h:225, MPS_CLASS_AVAILABLE_STARTING(macos(10.14.1), ios(12.1), macCatalyst(13.0),
// tvos(12.1))). What an object is placed by is the HELD ladder and not the header's clause, because the
// release the port deploys on has to be one a release's own export answers for, and no release is held
// between 12.0 and 16.0:
//
//   $ printf 'MPSNNPad\n' | xmake l tools/cache-index/first-rung.lua
//   MPSNNPad   16.0
//
// so this class is answered by a 16.0 object and could not sit beside the 12.0 states of
// MPSNNStates12.m without one file carrying two band points - which `misplaced()` in backports.lua refuses
// and tools/release-split.lua reports as MIXED-RELEASES. The row says 12.1, which is the header's own date
// and is left as it is; this comment is the placement, and the command above is what it rests on. The same
// measurement puts MPSCNNNormalizationMeanAndVarianceState and MPSRNNMatrixTrainingState at 12.0, which is
// why those two are in MPSNNStates12.m and this one is here.
//
// THE SUPERCLASS is carried: MPSNNReshape.h:227 makes MPSNNPad an MPSCNNKernel, and MPSCNNKernel10.m is
// that class. What MPSNNPad adds over it is the pad.
//
// WHAT IT IS. paddingSizeBefore (:229-241) is the left, the top and the smaller feature-channel indices,
// paddingSizeAfter (:243-256) the other three ends, and the pad is filled either with one float (fillValue, the
// constant for MPSImageEdgeModeConstant, default 0.0f, :258-263) or with one float per destination feature channel
// out of the NSData the designated initializer takes (:282-287). Which of the two is in force is decided by
// the header at :260-262, where fillValue is ignored once a per-channel fill value is given, so an
// NSData present decides and the scalar is not consulted, which is why the encode below reads the
// array when there is one and the scalar when there is not.
//
// WHAT IS NOT CARRIED HERE. -destinationImageDescriptorForSourceImages:sourceStates: is the method
// paddingSizeBefore exists for: the sizing of the destination image from the source (:230-232). That method belongs to
// MPSCNNKernel and the graph layer, which is the release-11 object, so this object carries the pad and the
// fill and leaves the sizing to whoever carries the graph.
//
// WHAT IS NOT CLAIMED. No number in this file is a measurement of Apple's code: the release's own MPS
// cannot run on this host, which facts/MetalPerformanceShaders/Image9.md records with the selector and the
// text of the log. What has been checked is the armv7 build of this directory - every object compiles at
// -target armv7-apple-ios6.0 and `ld -r -undefined dynamic_lookup` over all of them leaves no MPS class
// undefined - and the commands are in facts/MetalPerformanceShaders/Release12.md. No host case, no device
// run and no gate: the gate is the coordinator's.

#import "CharonMPSCnn.h"

@implementation MPSNNPad {
    MPSImageCoordinate _paddingSizeBefore;
    MPSImageCoordinate _paddingSizeAfter;
    float _fillValue;
    NSData *_fillValueArray;
}

// The simplest of the three: MPSCNNKernel's initializer and the header's two properties at their
// documented defaults - no padding at all on either side, and a fill of 0.0f (MPSNNReshape.h:260).
//
// MPSNNReshape.h marks the four-argument form below a designated initializer of this class (:290-297),
// so this one is a SECONDARY initializer of it and must reach MPSCNNKernel's own initializer THROUGH it
// rather than by chaining to [super initWithDevice:] directly - which is what clang asks for at
// -Wobjc-designated-initializers, and what the two-argument form above already does. The state this
// leaves is the one MPSCNNKernel's initializer makes plus the three defaults, so it is the same object
// the direct chain built; no pragma is carried for the warning, because there is nothing left to warn
// about once the chain is the one the header's own initializer graph asks for.
- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    return [self initWithDevice:device
             paddingSizeBefore:(MPSImageCoordinate){0, 0, 0}
              paddingSizeAfter:(MPSImageCoordinate){0, 0, 0}
                 fillValueArray:nil];
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
            paddingSizeBefore:(MPSImageCoordinate)paddingSizeBefore
             paddingSizeAfter:(MPSImageCoordinate)paddingSizeAfter
{
    return [self initWithDevice:device paddingSizeBefore:paddingSizeBefore paddingSizeAfter:paddingSizeAfter fillValueArray:nil];
}

// The designated one, :282-287. The array is the header's per-channel fill, kept as a strong ivar so it
// outlives this method; the array's length is not checked against the destination's channel count here
// because the header says a short array has undefined results (:286-287), and the encode below refuses rather than reading past it.
- (instancetype)initWithDevice:(id<MTLDevice>)device
            paddingSizeBefore:(MPSImageCoordinate)paddingSizeBefore
             paddingSizeAfter:(MPSImageCoordinate)paddingSizeAfter
                fillValueArray:(NSData *)fillValueArray
{
    if ((self = [super initWithDevice:device])) {
        _paddingSizeBefore = paddingSizeBefore;
        _paddingSizeAfter = paddingSizeAfter;
        _fillValue = 0.0f;
        _fillValueArray = fillValueArray;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder device:(id<MTLDevice>)device
{
    // The default initializer for the coder (:301), which reaches the same defaults as -initWithDevice:.
    return [super initWithCoder:aDecoder device:device];
}

- (MPSImageCoordinate)paddingSizeBefore { return _paddingSizeBefore; }
- (void)setPaddingSizeBefore:(MPSImageCoordinate)paddingSizeBefore { _paddingSizeBefore = paddingSizeBefore; }
- (MPSImageCoordinate)paddingSizeAfter { return _paddingSizeAfter; }
- (void)setPaddingSizeAfter:(MPSImageCoordinate)paddingSizeAfter { _paddingSizeAfter = paddingSizeAfter; }
- (float)fillValue { return _fillValue; }
- (void)setFillValue:(float)fillValue { _fillValue = fillValue; }

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                  sourceImage:(MPSImage *)sourceImage
             destinationImage:(MPSImage *)destinationImage
{
    NSString *what = @"MPSNNPad";
    if (!CharonMPSCommandBufferPermits(commandBuffer))
        return;
    if (!sourceImage || !destinationImage || !sourceImage.width || !sourceImage.height ||
        !destinationImage.width || !destinationImage.height) {
        CharonMPSRefuse(@"%@: an image with no shape was given, so nothing was written", what);
        return;
    }
    // The destination is the source with the pad on each side of each axis, which is what the header's
    // two properties mean: paddingSizeBefore's x is "the left", its y "the top" and its channel the
    // smaller feature-channel indices (MPSNNReshape.h:229-241), paddingSizeAfter's the other three ends
    // (:243-256). A destination that is not that shape is refused by name rather than partly written.
    NSUInteger wantWidth = sourceImage.width + _paddingSizeBefore.x + _paddingSizeAfter.x;
    NSUInteger wantHeight = sourceImage.height + _paddingSizeBefore.y + _paddingSizeAfter.y;
    NSUInteger wantChannels = sourceImage.featureChannels + _paddingSizeBefore.channel + _paddingSizeAfter.channel;
    if (destinationImage.width != wantWidth || destinationImage.height != wantHeight ||
        destinationImage.featureChannels != wantChannels) {
        CharonMPSRefuse(@"%@: a %lux%lu source with %lu before and %lu after pads is %lux%lu with %lu feature"
                        @" channels, and the destination is %lux%lu with %lu; nothing was written", what,
                        (unsigned long)sourceImage.width, (unsigned long)sourceImage.height,
                        (unsigned long)_paddingSizeBefore.x, (unsigned long)_paddingSizeAfter.x,
                        (unsigned long)wantWidth, (unsigned long)wantHeight, (unsigned long)wantChannels,
                        (unsigned long)destinationImage.width, (unsigned long)destinationImage.height,
                        (unsigned long)destinationImage.featureChannels);
        return;
    }
    NSUInteger perChannel = 0;
    const float *fill = (const float *)[_fillValueArray bytes];
    if (fill)
        perChannel = (NSUInteger)([_fillValueArray length] / sizeof(float));
    if (fill && perChannel < wantChannels) {
        CharonMPSRefuse(@"%@: the fill array holds %lu value(s) and the destination has %lu feature channels,"
                        @" which is undefined behavior, so nothing was written", what,
                        (unsigned long)perChannel, (unsigned long)wantChannels);
        return;
    }

    // One pass over the destination, in the plane layout CharonMPSCnn.h owns: a pixel inside the pad
    // takes its fill, and one inside the source takes the source's own value. The source's origin in the
    // destination is the "before" coordinate, which is what makes -paddingSizeBefore the left and the top
    // and not the right and the bottom.
    CharonMPSCnnPlane from, to;
    size_t inWidth, inHeight, inChannels, outWidth, outHeight, outChannels;
    CharonMPSCnnTake(sourceImage, &from, &inWidth, &inHeight, &inChannels);
    CharonMPSCnnTake(destinationImage, &to, &outWidth, &outHeight, &outChannels);
    for (NSUInteger channel = 0; channel < outChannels; channel++) {
        // The fill for this channel: the array's own when there is one, the scalar otherwise. The array's
        // index is the DESTINATION channel: entry 0 of the array fills the first output channel, counted in the destination (:283-284), not the source's.
        double filled = fill ? (double)fill[channel] : (double)_fillValue;
        for (NSUInteger oy = 0; oy < outHeight; oy++) {
            for (NSUInteger ox = 0; ox < outWidth; ox++) {
                long sx = (long)ox - (long)_paddingSizeBefore.x;
                long sy = (long)oy - (long)_paddingSizeBefore.y;
                long sc = (long)channel - (long)_paddingSizeBefore.channel;
                double value = filled;
                if (sx >= 0 && sy >= 0 && sc >= 0 && (NSUInteger)sx < inWidth && (NSUInteger)sy < inHeight &&
                    (NSUInteger)sc < inChannels) {
                    value = CharonMPSLoad(CharonMPSCnnPixel(&from, (size_t)sx, (size_t)sy, (size_t)sc),
                                          MPSDataTypeFloat32, 0);
                }
                CharonMPSStore(CharonMPSCnnPixelMutable(&to, ox, oy, channel), MPSDataTypeFloat32, 0, value);
            }
        }
    }
    CharonMPSCnnGive(destinationImage, &to);
    CharonMPSCnnGive(sourceImage, &from);
    CharonMPSConsumeReadCount(sourceImage);
}

@end
