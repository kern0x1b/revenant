// MPSImageThreshold13.m - the five threshold kernels, and the state they share.
//
// Each of the five answers one comparison per channel, and the comparison is the header's own:
// MPSImageThreshold.h states the formula for each, and this file implements those five and nothing else.
//
// The five all inherit directly from MPSUnaryImageKernel in the release's own hierarchy, and that
// hierarchy is kept: MPSImageThresholdToZero, …ToZeroInverse, …Binary, …BinaryInverse and …Truncate are
// declared there as subclasses of MPSUnaryImageKernel, and a class the SDK declares cannot be
// re-declared here. So there is no shared base class in the chain, and the three values the five hold -
// the threshold, the maximum and the transform - are declared in each of the five, and the code that
// fills them, applies them and runs the encode is a CATEGORY on MPSUnaryImageKernel, which the five call.
// The category holds no ivars of its own: on this fragile-ABI target a category cannot, and it does not
// need to, because the state is the five's.
//
// The threshold initialiser belongs to the thresholds, not to MPSUnaryImageKernel, which declares only
// -initWithDevice: (available, and used), so `[super initWithDevice:]` from each of the five is the
// kernel's own and needs no runtime detour. The arithmetic file's does not: MPSImageArithmetic's
// -initWithDevice: is NS_UNAVAILABLE and the arithmetic state lives on the class above it, which is why
// that one goes through objc_msgSendSuper.
//
// The threshold value is the caller's and the header makes it readonly - the initialiser sets it - and
// the header marks -initWithDevice: unavailable on all five, so this file does not define it on any of
// them: a kernel that was never given a value refuses to encode rather than answering against a zero it
// did not receive.
//
// The transform is the header's array of THREE floats, and its default is BT.601/JPEG, which
// MPSImageThreshold.h states five times, once per subclass:
//
//   @param transform  Three floats giving the matrix; when none is given the default is
//                     BT.601/JPEG: {0.299f, 0.587f, 0.114f};
//
// A kernel of this family walks a one-channel image - MPSImage13.m refuses an image whose feature channel
// count is not one - so the transform's first entry is the whole of it.

#import "CharonMPS.h"
#import "CharonMPSImage.h"

// No diagnostic is silenced in this file. What the build reports, with the pragmas stripped and
// -Wall -Wextra, is in the commits that removed the pragmas: the category declares a protocol and
// nothing of its own, so it declares no method it does not define, and the five conform through a
// category each.
//
// What the build still prints, and each KIND accounted for. The counts are the part that stays true;
// line numbers are not quoted, because this comment is itself inside the file and every one of them
// moved the moment it was written - a reader who followed :92 for the category landed twelve lines above
// it, and the same for the five pairs. So: the diagnostic and the count, and nothing that rots.
//
//   ONE   -Wobjc-protocol-method-implementation. Inherent to putting the shared encode in a category on
//          a class the SDK owns: the five classes implement it too, and the one that runs is the
//          category's.
//   FIVE  -Wincomplete-implementation and FIVE -Wobjc-designated-initializers, one pair per class, both
//          about 'initWithCoder:device:'. MPSKernel9.m:74-82 implements that initialiser once and the
//          five inherit it, and MPSImageThreshold.h declares it fifteen times without defining it on
//          any class, so the release does not define it per subclass either. It is the same owed
//          -initWithCoder:device: this series records on MPSMatrixRandomMTGP32 with an effect string.
//
// Nothing else, and the count is the check: 5 + 5 + 1 = 11, measured stripped of pragmas and asked with
// -Wall -Wextra, under the harness's own flags and under none. A twelfth entry is deliberately absent from
// the list: -Wincompatible-sysroot fires when -isysroot names the current directory, so it is a property
// of the command line and not of this file, and it appears under neither invocation.
//
//   --- MPSImageThreshold13, no pragma, -Wall -Wextra:
//         5 [-Wincomplete-implementation]
//         5 [-Wobjc-designated-initializers]
//         1 [-Wobjc-protocol-method-implementation]

@protocol CharonMPSImageThresholdHooks <NSObject>
- (float)charon_mps_thresholdValue;
- (float)charon_mps_maximumValue;
- (const float *)charon_mps_transform;
- (BOOL)charon_mps_hasThreshold;
- (double)CharonMPSThreshold:(double)value;
@end

// The transform's three entries, defaulted to the header's BT.601 and then overwritten by the caller's
// three. A plain indexed loop: the previous one read and wrote its index in one expression with no
// intervening sequence point, which clang reported as -Wunsequenced and which read transform[-1] on its
// first iteration.
static void CharonMPSFillTransform(float *out, const float *transform)
{
    out[0] = 0.299f; out[1] = 0.587f; out[2] = 0.114f;
    if (transform)
        for (NSUInteger i = 0; i < 3; i++)
            out[i] = transform[i];
}

// The transform is NOT applied, and this file does not apply it.
//
// MPSImageThreshold.h states the rule once for all five, at :18-19 and again at :78-79, :138-139,
// :198-199 and :258-259: a multi-channel input is first turned into a single luminance channel with the
// linear gray color transform, and only then is the threshold applied.
// That is ONE SCALAR LUMINANCE PER PIXEL - 0.299*r + 0.587*g + 0.114*b at the default - computed from
// the three channels and then thresholded ONCE.
//
// This file does not do that, and an earlier version of this comment claimed it did. What the code did
// was multiply each channel by its own coefficient and threshold each channel separately, which is not
// the header's rule and not any rule: for a 3-channel image that answers three comparisons where the
// header answers one, and it wrote three where the header writes one. Multiplying a single channel's
// value by 0.299 is not that either, which is how a one channel image came to answer 2.0 * 0.299 =
// 0.598 where the header's own formula says 2.0.
//
// So a multi channel image is REFUSED, the way the walk refuses an image it cannot walk, and this file
// answers only what it answers correctly: a ONE channel image, thresholded on its own value, which is
// what MPSImageThreshold.h:194 and its four siblings state. The luminance path is owed and is written
// down as owed in facts/MetalPerformanceShaders/Image.md.

// YES when the image is a ONE channel one. Only a one channel image is answered, and the refusal a
// multi channel one gets names the feature channel count, so the caller can see which case is owed.
static BOOL CharonMPSIsSingleChannel(MPSImage *image)
{
    return image.featureChannels <= 1;
}

@implementation MPSUnaryImageKernel (CharonImageThreshold)

// The encode all five share, in the shape MPSImageKernel.h declares: a source image, a destination
// image, and the clip rectangle the caller set.
- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                 sourceImage:(MPSImage *)sourceImage
            destinationImage:(MPSImage *)destinationImage
{
    NSString *what = NSStringFromClass([self class]);
    id<CharonMPSImageThresholdHooks> kernel = (id<CharonMPSImageThresholdHooks>)self;
    // Only a ONE channel image is answered, and it is thresholded on its own value. The luminance path
    // a multi channel image needs is not implemented - see the comment on this file's transform - so the
    // encode refuses it by name rather than answering something the header does not say.
    if (!CharonMPSIsSingleChannel(sourceImage)) {
        CharonMPSRefuse(@"%@: the image has %lu feature channels. The filter converts a "
                        "multi channel image to ONE scalar luminance with the linearGrayColorTransform "
                        "and then thresholds that, which this port does not implement, so nothing was "
                        "written. The path is owed; a one channel image is answered.",
                        what, (unsigned long)sourceImage.featureChannels);
        return;
    }
    if (!commandBuffer) {
        CharonMPSRefuse(@"%@: no command buffer, so nothing was written", what);
        return;
    }
    if (!kernel.charon_mps_hasThreshold) {
        CharonMPSRefuse(@"%@: the kernel carries no threshold value. Every one of the five declares "
                        "-initWithDevice: as NS_UNAVAILABLE and says the initializer carrying the value "
                        "is the one to use, so a kernel that did not get one is not a kernel a caller can "
                        "have, and nothing is written", what);
        return;
    }
    CharonMPSImageMapUnary(sourceImage, destinationImage, self.clipRect, ^double(NSUInteger pixel,
                                                                                  NSUInteger channel,
                                                                                  double value) {
        (void)pixel; (void)channel;
        return [kernel CharonMPSThreshold:value];
    }, what);
}

@end

// The five, each carrying the initialiser the header declares on it, the three values, and the one
// comparison that is the whole class.

// The ivar block and the four accessors, identical in the five, because the release's hierarchy has no
// base of this file's to put them in.
#define CHARON_MPS_IMAGE_THRESHOLD_STATE                                        \
    float _thresholdValue;                                                      \
    float _maximumValue;                                                        \
    float _charonTransform[3];                                                  \
    BOOL _hasThreshold;

#define CHARON_MPS_IMAGE_THRESHOLD_ACCESSORS                                    \
    - (float)charon_mps_thresholdValue { return _thresholdValue; }             \
    - (float)charon_mps_maximumValue { return _maximumValue; }                 \
    - (const float *)charon_mps_transform { return _charonTransform; }                \
    - (BOOL)charon_mps_hasThreshold { return _hasThreshold; }

// Conformance is declared here and not in a re-declaration of the class, which the SDK owns.
@interface MPSImageThresholdToZero (CharonThresholdHooks) <CharonMPSImageThresholdHooks> @end

@implementation MPSImageThresholdToZero {
CHARON_MPS_IMAGE_THRESHOLD_STATE
}
CHARON_MPS_IMAGE_THRESHOLD_ACCESSORS

- (instancetype)initWithDevice:(id<MTLDevice>)device
                thresholdValue:(float)thresholdValue
       linearGrayColorTransform:(const float *)transform
{
    if ((self = [super initWithDevice:device])) {
        _thresholdValue = thresholdValue;
        _maximumValue = 1.0f;
        _hasThreshold = YES;
        CharonMPSFillTransform(_charonTransform, transform);
    }
    return self;
}

- (double)CharonMPSThreshold:(double)value
{
    return value > (double)_thresholdValue ? value : 0.0;
}
@end

// Conformance is declared here and not in a re-declaration of the class, which the SDK owns.
@interface MPSImageThresholdToZeroInverse (CharonThresholdHooks) <CharonMPSImageThresholdHooks> @end

@implementation MPSImageThresholdToZeroInverse {
CHARON_MPS_IMAGE_THRESHOLD_STATE
}
CHARON_MPS_IMAGE_THRESHOLD_ACCESSORS

- (instancetype)initWithDevice:(id<MTLDevice>)device
                thresholdValue:(float)thresholdValue
       linearGrayColorTransform:(const float *)transform
{
    if ((self = [super initWithDevice:device])) {
        _thresholdValue = thresholdValue;
        _maximumValue = 1.0f;
        _hasThreshold = YES;
        CharonMPSFillTransform(_charonTransform, transform);
    }
    return self;
}

- (double)CharonMPSThreshold:(double)value
{
    return value > (double)_thresholdValue ? 0.0 : value;
}
@end

// Conformance is declared here and not in a re-declaration of the class, which the SDK owns.
@interface MPSImageThresholdTruncate (CharonThresholdHooks) <CharonMPSImageThresholdHooks> @end

@implementation MPSImageThresholdTruncate {
CHARON_MPS_IMAGE_THRESHOLD_STATE
}
CHARON_MPS_IMAGE_THRESHOLD_ACCESSORS

- (instancetype)initWithDevice:(id<MTLDevice>)device
                thresholdValue:(float)thresholdValue
       linearGrayColorTransform:(const float *)transform
{
    if ((self = [super initWithDevice:device])) {
        _thresholdValue = thresholdValue;
        _maximumValue = 1.0f;
        _hasThreshold = YES;
        CharonMPSFillTransform(_charonTransform, transform);
    }
    return self;
}

- (double)CharonMPSThreshold:(double)value
{
    return value > (double)_thresholdValue ? (double)_thresholdValue : value;
}
@end

// The two Binary kernels declare the FOUR-argument initializer, with the maximum the kernel writes where
// the source is at or above the threshold, and MPSImageThresholdBinaryInverse declares the two-argument
// one as well. Both shapes are implemented on each of the two, so a caller that uses either gets one.

// Conformance is declared here and not in a re-declaration of the class, which the SDK owns.
@interface MPSImageThresholdBinary (CharonThresholdHooks) <CharonMPSImageThresholdHooks> @end

@implementation MPSImageThresholdBinary {
CHARON_MPS_IMAGE_THRESHOLD_STATE
}
CHARON_MPS_IMAGE_THRESHOLD_ACCESSORS

- (instancetype)initWithDevice:(id<MTLDevice>)device
                thresholdValue:(float)thresholdValue
       linearGrayColorTransform:(const float *)transform
{
    return [self initWithDevice:device thresholdValue:thresholdValue maximumValue:1.0f
            linearGrayColorTransform:transform];
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
                thresholdValue:(float)thresholdValue
                 maximumValue:(float)maximumValue
       linearGrayColorTransform:(const float *)transform
{
    if ((self = [super initWithDevice:device])) {
        _thresholdValue = thresholdValue;
        _maximumValue = maximumValue;
        _hasThreshold = YES;
        CharonMPSFillTransform(_charonTransform, transform);
    }
    return self;
}

- (double)CharonMPSThreshold:(double)value
{
    return value > (double)_thresholdValue ? (double)_maximumValue : 0.0;
}
@end

// Conformance is declared here and not in a re-declaration of the class, which the SDK owns.
@interface MPSImageThresholdBinaryInverse (CharonThresholdHooks) <CharonMPSImageThresholdHooks> @end

@implementation MPSImageThresholdBinaryInverse {
CHARON_MPS_IMAGE_THRESHOLD_STATE
}
CHARON_MPS_IMAGE_THRESHOLD_ACCESSORS

- (instancetype)initWithDevice:(id<MTLDevice>)device
                thresholdValue:(float)thresholdValue
       linearGrayColorTransform:(const float *)transform
{
    return [self initWithDevice:device thresholdValue:thresholdValue maximumValue:1.0f
            linearGrayColorTransform:transform];
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
                thresholdValue:(float)thresholdValue
                 maximumValue:(float)maximumValue
       linearGrayColorTransform:(const float *)transform
{
    if ((self = [super initWithDevice:device])) {
        _thresholdValue = thresholdValue;
        _maximumValue = maximumValue;
        _hasThreshold = YES;
        CharonMPSFillTransform(_charonTransform, transform);
    }
    return self;
}

- (double)CharonMPSThreshold:(double)value
{
    return value > (double)_thresholdValue ? 0.0 : (double)_maximumValue;
}
@end
