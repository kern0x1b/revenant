// MPSCNNElements10.m - the convolutional elements iOS 10 added, in ONE object for the ONE release
// they belong to. Every number on these rows is a measurement of the host's own MPS and not of the
// header's wording: tests/backports/host/mpscnn10/run.sh is the harness (Apple M4 Pro, macOS 27.0) and
// each rule below was solved from its transcript.
//
// WHAT IS HERE, and what each class is:
//
//   MPSCNNNeuron          the base. At 10.0 it declares only a, b and c (:188-190) and marks
//                         -initWithDevice: NS_UNAVAILABLE (:195), so a 10.0 caller cannot build it
//                         by name and neither can a subclass reach its initialiser. It is here
//                         because five classes inherit from it, and it refuses to be built rather
//                         than answering as something it is not.
//   MPSCNNNeuronLinear    f(x) = a*x + b          :318
//   MPSCNNNeuronReLU      f(x) = x, else a*x      :351
//   MPSCNNNeuronSigmoid   f(x) = 1/(1+e^-x)       :429
//   MPSCNNNeuronTanH      f(x) = a*tanh(b*x)      :466
//   MPSCNNNeuronAbsolute  f(x) = |x|              :501
//   MPSCNNSoftMax         exp(x_k)/sum exp(x_q) ACROSS FEATURE CHANNELS, measured
//   MPSCNNLogSoftMax      x_k - ln(sum exp(x_q)), across feature channels, measured
//   MPSCNNSpatialNormalization       X/(delta + alpha/(kw*kh)*N2)^beta
//   MPSCNNLocalContrastNormalization pm + ps*(X - p0*M)/(delta + alpha*VAR)^beta
//   MPSCNNCrossChannelNormalization  X/L^beta, L over a channel window Q(k)
//
// WHAT IS DELIBERATELY NOT HERE, each with the measurement that decides it:
//
//   MPSCNNNeuron's -initWithDevice:neuronDescriptor: is 11.3 API (MPSCNNNeuron.h:207-208) and its
//   -neuronType and -data are 11.0 (:187, :191), so NONE of them is defined in this file. The class
//   is a 10.0 class that is not directly constructible at 10.0, which is why -initWithDevice: refuses
//   below rather than pretending to be the base's own way in. MPSImageGaussianBlur's row in this same
//   file is the same shape of thing and says so in as many words.
//
//   MPSCNNFullyConnected's header says ios(10.0) (:1342) but it is not in this object. Its superclass
//   MPSCNNConvolution is already carried (MPSCNNConvolution10.m), so placement is not the blocker;
//   its weights arrive through id<MPSCNNConvolutionDataSource>, a protocol whose own rows are 11.3,
//   and whose -copyWithZone:device: and -weightsLayout the owed facts page lists against no header
//   at all. A class that builds and cannot be given weights is a symbol that loads and lies.
//
//   MPSImageConversion needs a CGColorConversionInfoRef (MPSImageConversion.h:60-64); first-rung
//   answers _CGColorConversionInfoCreate at 10.0.1 and the whole CoreGraphics colour-conversion
//   family is absent from this port (registry/CoreGraphics/absent_CoreGraphics.json).
//
//   MPSImagePyramid and MPSImageGaussianPyramid: the classes resolve and hold their parameters -
//   kernelWidth 5 and kernelHeight 5 by default, 3x3 from the custom initialiser, all measured -
//   but their encode is the in-place mip-level fill (MPSImageConvolution.h:513-520) and running it
//   against this host's own MPS on an 8x8 R32Float texture with four mip levels takes the process
//   down with SIGSEGV, exit 139. The port's MPSImage13.m also makes every texture with mipmapped:NO
//   (:253), so there are no mip levels for the fill to write: the same gap seen from this side.
//   Nothing here is decided dead; what is missing is a substrate that answers the encode.
//
//   MPSImageLaplacianPyramid, MPSImageLaplacianPyramidAdd and MPSImageLaplacianPyramidSubtract are
//   NOT in this release at all: first-rung answers 12.0 for all three against 10.0.1 for the twelve
//   above, so a 10.0 object carrying them would mix two releases. They are 12.0 work and their rows
//   are flipped to say so.
//
// FOUR RULES THE HEADER DOES NOT GIVE, OR GIVES IN A FORM THE RELEASE DOESN'T USE. Each was solved
// from the host's own answers:
//
//   SPATIAL, the window. The header gives no window for MPSCNNSpatialNormalization itself; the
//   gradient's formula at MPSCNNNormalization.h:60-62 gives L(i) = [i-floor((kw-1)/2), i+floor(kw/2],
//   which as a kw x kw block is CENTRED on the output, and that is what the release computes.
//   MEASURED at kw=3, where a centred window (first = -1) and a backward one (first = -2) are different
//   windows: the host agrees with centred to 3.0e-06 and disagrees with backward by 7.7e+04.
//
//   AND A CASE THAT COULD NOT HAVE TOLD, recorded because it is the kind of measurement that looks like
//   evidence and is not. An earlier version of this file claimed an EVEN kernel's window reaches BACK,
//   on the strength of a kw=2 case over a 4x4 of 1..16 whose sixteen implied N2 values (1, 5, 26, 66,
//   25, 26, 98, 138, 106, 242, 306, 378, 250, 546, 642, 746) were all reproduced. For a 2-wide kernel a
//   centred window starts at -(2/2) = -1 and a backward one at -2+1 = -1: the SAME two pixels. Every one
//   of the sixteen values was consistent with both rules and the case distinguished nothing. The claim
//   and its flag are gone; the kw=3 measurement is what the row now rests on.
//   LOCAL CONTRAST, p0's default. :151-153 says p0 defaults to 1.0, and the measurement needs it: at
//   alpha 0 the denominator is the constant delta^beta, so the host's answer solves M = X - Y*delta^beta
//   and at (0,0) that is 1.55555558 against the centred 3x3 mean 1.55555556. With p0 = 0 this file
//   would answer 32 where the host answers -17.7777786.
//   CROSS CHANNEL, the divisor and the window. :381-387 says alpha/N with "N is the kernel size",
//   over Q(k) = [max(0,k-floor(N/2)), min(D-1,k+floor((N-1)/2))]. Measured with kernelSize 3, the
//   divisor implied by the host is 3.000000 at all twelve outputs checked, where the window lengths
//   are 2, 3 and 2 for channels 0, 1 and 2 - so it is the kernelSize and not the window's length.
//   Q(k) is ASYMMETRIC: channel 0 sees channels 0 and 1, channel 1 sees all three, and channel 0's
//   measured answer is 1.24184335e-05. Symmetrising the window would change it.
//   SOFTMAX is ACROSS FEATURE CHANNELS, not across pixels. Measured on a 4x4 of two channels whose
//   values differ: every pixel answers 0.268941432 / 0.731058598, which is sigmoid(1-2) - the two
//   channels at THAT pixel. A softmax over the sixteen pixels of a row would answer sixteen different
//   numbers.
//
// ACCUMULATION IS IN DOUBLE and the store is float32, so each result is within a float32 ulp of the
// exact expression and not bit-identical to the host's. The harness compares these to a written-down
// tolerance and still compares the pooling cases beside them exactly.

#import "CharonMPSCnn.h"
#import "CharonMPS.h"
#import "CharonMPSImage.h"

#pragma clang diagnostic ignored "-Wprotocol"
#pragma clang diagnostic ignored "-Wincomplete-implementation"
// Each of the six initialisers below is the header's own designated initialiser for its class
// (MPSCNNNeuron.h:208, :222, :327, :359, :422, :475), and none of them can call a designated
// initializer of its superclass: MPSCNNNeuron's only designated one at 10.0 is
// -initWithDevice:neuronDescriptor:, which is 11.3 API and is not defined in this file on purpose,
// and -initWithDevice: is NS_UNAVAILABLE on it (:195). So the chain reaches MPSCNNKernel's through
// this file's own -initCharonMPSWithDevice: seam, which clang cannot see as designated. The
// diagnostic is real and the reason is that the release's own 10.0 surface has no path through the
// base; MPSImageConvolution13.m carries this pragma for the same reason and it is recorded there in
// coordination/crutches.md.
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

// Whether two images can be walked at all as single precision. One refusal, named, rather than five
// walks each re-deriving it.
static BOOL CharonMPSCnnPairIsFloat32(MPSImage *source, MPSImage *destination, NSString *what)
{
    if (source.featureChannelFormat != MPSImageFeatureChannelFormatFloat32 ||
        destination.featureChannelFormat != MPSImageFeatureChannelFormatFloat32) {
        CharonMPSRefuse(@"%@: only single precision images are carried, so nothing was written", what);
        return NO;
    }
    if (!source.width || !source.height || !source.featureChannels ||
        !destination.width || !destination.height || !destination.featureChannels) {
        CharonMPSRefuse(@"%@: an image of the pair has no shape or no feature channels, so nothing was written",
                        what);
        return NO;
    }
    return YES;
}

// This object's view of one image: the family's own region buffer, and the INTERLEAVED addressing the
// port's MPSImage really has.
//
// The plane type in the shared CharonMPSCnn.h is not it, and the reason is measured. MPSImage13.m:50-72
// picks MTLPixelFormatR32Float, RG32Float or RGBA32Float from the channel count, and MPSImageWalk13.m:65
// states the consequence: "There is no planar format in that surface, so the addressing is always
// interleaved". The shared plane addresses channel c at row channel*height with a stride of width times
// one element, which is a planar layout: for a two-channel image it hands getBytes: a stride half the
// row's, the texture answers "bytes_per_row >= used_bytes_per_row", and every value comes back zero -
// eight such assertions and five all-zero cases in this harness's first port run. A one-channel image
// addresses identically under both, which is why every single-channel case was green before and is
// green now, and why only the cases that CROSS channels found it.
//
// So the walk reads through the four helpers the image family already shares -
// CharonMPSImageReadRegion, CharonMPSImageLoad, CharonMPSImageIndex and CharonMPSImageWriteRegion - and
// this type is the layout those work in. The shared header is left alone on purpose: MPSCNNPooling10.m
// and MPSCNNBatchNormalization12.m use its plane, those bands own those objects, and a defect in a
// shared header is fixed by the band that owns it rather than by a caller working around it.
typedef struct {
    const void *base;
    size_t width, height, channels;
    size_t valuesPerPixel;      // one, two or four: the texture's own width, read off the layout
} CharonMPSCnnInterleaved;

// The WHOLE image read through the family layer's own helper, which allocates the buffer this view
// owns and CharonMPSCnnWrite hands back. Returns NO when the image could not be read, so a walk stops
// rather than walking a buffer that is not there.
static BOOL CharonMPSCnnRead(MPSImage *image, CharonMPSCnnInterleaved *out)
{
    CharonMPSImageLayout layout = CharonMPSImageLayoutOf(image);
    memset(out, 0, sizeof(*out));
    out->width = layout.width;
    out->height = layout.height;
    out->channels = layout.channels;
    out->valuesPerPixel = layout.elementSize ? layout.bytesPerPixel / layout.elementSize : 0;
    if (!out->width || !out->height || !out->channels || !out->valuesPerPixel)
        return NO;
    // The count is the whole image's, which is what this read is: the region is the whole image and not
    // a sub-rectangle of it, so the helper's own guard is over exactly the bytes it will fill.
    layout.count = out->width * out->height * out->channels;
    out->base = CharonMPSImageReadRegion(image, &layout,
                                         MTLRegionMake2D(0, 0, out->width, out->height),
                                         @"MPSCNNElements10");
    return out->base != NULL;
}

static void CharonMPSCnnWrite(MPSImage *image, CharonMPSCnnInterleaved *view)
{
    if (!view->base)
        return;
    CharonMPSImageLayout layout = CharonMPSImageLayoutOf(image);
    layout.count = view->width * view->height * view->channels;
    CharonMPSImageWriteRegion(image, &layout, MTLRegionMake2D(0, 0, view->width, view->height),
                              view->base, @"MPSCNNElements10");
    view->base = NULL;
}

// One element, and the off-image value is ZERO. (x, y, channel) is the channel-th value of the (x, y)-th
// PIXEL, which is what interleaved means - MPSImageWalk13.m:79-81 says the same of its index helper.
static double CharonMPSCnnValue(const CharonMPSCnnInterleaved *view, size_t x, size_t y, size_t channel)
{
    if (!view->base || x >= view->width || y >= view->height || channel >= view->channels)
        return 0.0;
    return CharonMPSLoad((const char *)view->base +
                         (y * view->width * view->valuesPerPixel + x * view->valuesPerPixel + channel) *
                         sizeof(float),
                         MPSDataTypeFloat32, 0);
}

static void CharonMPSCnnStore(CharonMPSCnnInterleaved *view, size_t x, size_t y, size_t channel, double value)
{
    if (!view->base || x >= view->width || y >= view->height || channel >= view->channels)
        return;
    CharonMPSStore((char *)view->base +
                   (y * view->width * view->valuesPerPixel + x * view->valuesPerPixel + channel) *
                   sizeof(float),
                   MPSDataTypeFloat32, 0, value);
}

// The sum of the squares of a CENTRED kw x kw window of one feature channel, with the off-image value
// zero. Centred is MPSCNNNormalization.h:60-62's own rule, and it is MEASURED rather than assumed - at
// kw=3, where a centred window (first = -1) and a backward one (first = -2) are different windows, the
// host agrees with centred to 3.0e-06 and disagrees with backward by 7.7e+04.
//
// This function carried a `back` flag and a comment claiming an even kernel's window reaches back. That
// was WRONG, and the case that "proved" it could not have: for a 2-wide kernel a centred window starts
// at -1 and a backward one at -2+1 = -1, so the two are the SAME two pixels and every implied N2 the
// harness printed was reproduced by both rules. The flag is gone rather than left as a second answer a
// later author could choose between.
static double CharonMPSCnnWindowSquares(const CharonMPSCnnInterleaved *view, size_t channel,
                                        size_t x, size_t y, NSUInteger kernel)
{
    long first = -(long)(kernel / 2);
    double total = 0.0;
    for (NSUInteger ky = 0; ky < kernel; ky++)
        for (NSUInteger kx = 0; kx < kernel; kx++) {
            double value = CharonMPSCnnValue(view, (size_t)((long)x + first + (long)kx),
                                             (size_t)((long)y + first + (long)ky), channel);
            total += value * value;
        }
    return total;
}

// The sum of a CENTRED kw x kw window's values, for the local contrast mean.
static double CharonMPSCnnWindowSum(const CharonMPSCnnInterleaved *view, size_t channel,
                                    size_t x, size_t y, NSUInteger kernel)
{
    long first = -(long)(kernel / 2);
    double total = 0.0;
    for (NSUInteger ky = 0; ky < kernel; ky++)
        for (NSUInteger kx = 0; kx < kernel; kx++)
            total += CharonMPSCnnValue(view, (size_t)((long)x + first + (long)kx),
                                       (size_t)((long)y + first + (long)ky), channel);
    return total;
}

@implementation MPSCNNNeuron {
    MPSCNNNeuronType _charonType;
    float _a, _b, _c;
    const float *_prelu;
    NSUInteger _preluCount;
}

@synthesize a = _a;
@synthesize b = _b;
@synthesize c = _c;

// The one internal seam the five subclasses below reach. MPSCNNNeuron.h:195 marks
// -initWithDevice: NS_UNAVAILABLE, and `unavailable` is compile-time only - it removes no IMP - so a
// subclass below still has to get past it to MPSCNNKernel's initialiser. Naming the path
// `charon_mps_` says at the call site that it is this package's own and not an API a caller writes,
// which is what the naming convention is for; the release's own MPSCNNNeuron reaches the same place
// through its 11.3 descriptor initialiser, which this file does not define because it is not 10.0.
- (instancetype)initCharonMPSWithDevice:(id<MTLDevice>)device
{
    if ((self = [super initWithDevice:device])) {
        _charonType = MPSCNNNeuronTypeReLU;
        _a = 0.0f;
        _b = 0.0f;
        _c = 0.0f;
        _prelu = NULL;
        _preluCount = 0;
    }
    return self;
}

// MPSCNNNeuron.h:195 marks the plain -initWithDevice: as unavailable (NS_UNAVAILABLE), and the comment at
// :193-194 directs a caller to the neuron-descriptor initializer or to one of the subclasses instead.
// At 10.0 neither of those is available - the descriptor is 11.3 - so the base has no way in of its
// own and says so, rather than becoming a class a caller can build that answers as something else.
- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    CharonMPSRefuse(@"MPSCNNNeuron: at 10.0 this class has no initialiser of its own - its designated "
                    @"one takes an MPSNNNeuronDescriptor, which arrived in 11.3 - so use one of "
                    @"MPSCNNNeuronLinear, MPSCNNNeuronReLU, MPSCNNNeuronSigmoid, MPSCNNNeuronTanH "
                    @"or MPSCNNNeuronAbsolute");
    return nil;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder device:(id<MTLDevice>)device
{
    return [self initCharonMPSWithDevice:device];
}

// The function and the parameters, for the five subclasses and the walk below. The neuron type is
// NOT MPSCNNNeuron.h's public -neuronType, which is 11.0 API: it is this file's own state, and it is
// what -charon_mps_neuronType reads. PReLU's per-channel array rides here too, because
// MPSCNNNeuronTypePReLU is the one type whose A is per channel and the public -setNeuronToPReLUWith-
// ParametersA: is a 13.0 API, so a 10.0 object that wanted PReLU would have no way to be given one.
- (MPSCNNNeuronType)charon_mps_neuronType { return _charonType; }

- (void)charon_mps_setNeuron:(MPSCNNNeuronType)type
                            a:(float)a
                            b:(float)b
                            c:(float)c
{
    _charonType = type;
    _a = a;
    _b = b;
    _c = c;
}

// MPSCNNKernel.h:271-274 is the encode, and the header forbids the destination to alias the source, so
// both sides are read before the first write, which is what this does.
- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                  sourceImage:(MPSImage *)sourceImage
               destinationImage:(MPSImage *)destinationImage
{
    if (!CharonMPSCommandBufferPermits(commandBuffer))
        return;
    if (!CharonMPSCnnPairIsFloat32(sourceImage, destinationImage, @"MPSCNNNeuron"))
        return;

    CharonMPSCnnInterleaved from, to;
    if (!CharonMPSCnnRead(sourceImage, &from) || !CharonMPSCnnRead(destinationImage, &to)) {
        CharonMPSCnnWrite(destinationImage, &to);
        CharonMPSCnnWrite(sourceImage, &from);
        return;
    }
    // The view carries its own shape, so a walk reads from.width / from.channels rather than from a
    // second set of locals that could disagree with it.
    size_t inChannels = from.channels, outWidth = to.width, outHeight = to.height, outChannels = to.channels;

    MPSCNNNeuronType type = _charonType;
    double a = (double)_a, b = (double)_b, c = (double)_c;
    for (size_t channel = 0; channel < outChannels; channel++) {
        double perChannel = _prelu && channel < _preluCount ? (double)_prelu[channel] : a;
        size_t source = channel < inChannels ? channel : inChannels - 1;
        for (size_t y = 0; y < outHeight; y++)
            for (size_t x = 0; x < outWidth; x++) {
                double value = CharonMPSCnnValue(&from, x, y, source);
                double result = CharonMPSApplyNeuron(type, value, a, b, c, perChannel);
                CharonMPSCnnStore(&to, x, y, channel, result);
            }
    }
    CharonMPSCnnWrite(destinationImage, &to);
    CharonMPSCnnWrite(sourceImage, &from);
    CharonMPSConsumeReadCount(sourceImage);
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

@end

// The five fixed filters. Each is the whole class: the header gives it a designated initialiser and
// nothing else of its own, and each marks -initWithDevice: NS_UNAVAILABLE on itself - so the
// subclass is its function and its parameters, and the walk above is the base's.

@implementation MPSCNNNeuronLinear
// MPSCNNNeuron.h:315-318: f(x) = a * x + b. Measured with a=2, b=0.5 over 1..16: 2.5 at 1.
- (instancetype)initWithDevice:(id<MTLDevice>)device a:(float)a b:(float)b
{
    if ((self = [self initCharonMPSWithDevice:device]))
        [self charon_mps_setNeuron:MPSCNNNeuronTypeLinear a:a b:b c:1.0f];
    return self;
}
@end

@implementation MPSCNNNeuronReLU
// MPSCNNNeuron.h:333-338: f(x) = x if x >= 0, a * x if x < 0. Measured over a ramp of -8..7 with
// a=0.25: the negatives answer a*x exactly (-2, -1.75, ... -0.25) and the positives are unchanged.
- (instancetype)initWithDevice:(id<MTLDevice>)device a:(float)a
{
    // c is 0, and that is MEASURED rather than assumed: a fresh MPSCNNNeuronReLU on this host answers
    // c = 0 (harness line "relu-defaults a=0 b=0 c=0"). ReLU's formula does not use c, so every case's
    // numbers are the same either way, and a caller reading -c on a ReLU is not.
    if ((self = [self initCharonMPSWithDevice:device]))
        [self charon_mps_setNeuron:MPSCNNNeuronTypeReLU a:a b:0.0f c:0.0f];
    return self;
}
@end

@implementation MPSCNNNeuronSigmoid
// MPSCNNNeuron.h:429-431: f(x) = 1/(1+e^-x), no parameters. Measured over 1..16: 0.731058598 at 1,
// which is 1/(1+e^-1).
- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    if ((self = [self initCharonMPSWithDevice:device]))
        [self charon_mps_setNeuron:MPSCNNNeuronTypeSigmoid a:1.0f b:1.0f c:1.0f];
    return self;
}
@end

@implementation MPSCNNNeuronTanH
// MPSCNNNeuron.h:449-453: f(x) = a * tanh(b * x). Measured with a=3, b=0.5 over 1..16: 1.38635159 at
// 1, which is 3*tanh(0.5) - a outside, b inside, and the order matters.
- (instancetype)initWithDevice:(id<MTLDevice>)device a:(float)a b:(float)b
{
    if ((self = [self initCharonMPSWithDevice:device]))
        [self charon_mps_setNeuron:MPSCNNNeuronTypeTanH a:a b:b c:1.0f];
    return self;
}
@end

@implementation MPSCNNNeuronAbsolute
// MPSCNNNeuron.h:501: f(x) = |x|, no parameters. Measured over -8..7: 8 7 6 5 4 3 2 1 0 1 2 3 4 5 6 7,
// so the magnitudes are exact and a zero's sign is not preserved.
- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    if ((self = [self initCharonMPSWithDevice:device]))
        [self charon_mps_setNeuron:MPSCNNNeuronTypeAbsolute a:1.0f b:1.0f c:1.0f];
    return self;
}
@end

// The two softmaxes, and the one rule the measurement settles: both walk over FEATURE CHANNELS at one
// pixel. MPSCNNSoftMax.h:34-37 places the walk over the channels at every spatial location, and for the
// logarithmic form :101-104 gives pixel(x,y,k) - ln{sum(exp(pixel(x,y,0)) ... exp(pixel(x,y,N-1)))}, the sum
// being over the channel index at one pixel, which is what the measured answers show.
// The walk both softmaxes run, and the reason it is a static function of this file rather than a
// method on one of them: MPSCNNSoftMax.h:34 and :96 make them SIBLINGS over MPSCNNKernel - neither
// inherits from the other - so an encode written in one of them is not inherited by the other, and a
// category on MPSCNNKernel would be a message send to a `charon_` selector, which the harness's
// prefix_selectors.py renames on the send side and not on the definition side. A static is neither:
// one definition, called from both classes, no send and no second answer.
static void CharonMPSCnnSoftMaxWalk(MPSCNNKernel *owner, id<MTLCommandBuffer> commandBuffer,
                                    MPSImage *sourceImage, MPSImage *destinationImage, BOOL logarithmic)
{
    if (!CharonMPSCommandBufferPermits(commandBuffer))
        return;
    if (!CharonMPSCnnPairIsFloat32(sourceImage, destinationImage,
                                   logarithmic ? @"MPSCNNLogSoftMax" : @"MPSCNNSoftMax"))
        return;

    CharonMPSCnnInterleaved from, to;
    if (!CharonMPSCnnRead(sourceImage, &from) || !CharonMPSCnnRead(destinationImage, &to)) {
        CharonMPSCnnWrite(destinationImage, &to);
        CharonMPSCnnWrite(sourceImage, &from);
        return;
    }
    // The view carries its own shape, so a walk reads from.width / from.channels rather than from a
    // second set of locals that could disagree with it.
    size_t inChannels = from.channels, outWidth = to.width, outHeight = to.height, outChannels = to.channels;

    size_t channels = outChannels < inChannels ? outChannels : inChannels;
    double *values = calloc(channels ? channels : 1, sizeof(double));
    double *exponentials = calloc(channels ? channels : 1, sizeof(double));
    for (size_t y = 0; y < outHeight; y++) {
        for (size_t x = 0; x < outWidth; x++) {
            double sum = 0.0;
            for (size_t channel = 0; channel < channels; channel++) {
                double value = CharonMPSCnnValue(&from, x, y, channel);
                values[channel] = value;
                exponentials[channel] = exp(value);
                sum += exponentials[channel];
            }
            // A one-channel pixel divides by itself and answers 1, which is what the release answers,
            // and a set of channels whose exponentials all underflow to zero would divide by zero
            // here; the guard keeps the walk finite without inventing a value for it, and it is
            // reached only by inputs the header already calls undefined.
            if (sum == 0.0)
                sum = 1.0;
            double logarithm = log(sum);
            for (size_t channel = 0; channel < channels; channel++) {
                double result = logarithmic ? (values[channel] - logarithm)
                                            : (exponentials[channel] / sum);
                CharonMPSCnnStore(&to, x, y, channel, result);
            }
        }
    }
    free(exponentials);
    free(values);
    CharonMPSCnnWrite(destinationImage, &to);
    CharonMPSCnnWrite(sourceImage, &from);
    CharonMPSConsumeReadCount(sourceImage);
    (void)owner;
}

// The two softmaxes, and the one rule the measurement settles: both walk over FEATURE CHANNELS at one
// pixel. MPSCNNSoftMax.h:34-37 places the walk over the channels at every spatial location, and for the
// logarithmic form :101-104 gives pixel(x,y,k) - ln{sum(exp(pixel(x,y,0)) ... exp(pixel(x,y,N-1)))}, the sum
// being over the channel index at one pixel, which is what the measured answers show.
//
// Whether this class's walk takes the logarithmic branch is a class method OVERRIDDEN by
// MPSCNNLogSoftMax rather than an instance flag the subclass sets, and the reason is measured: the
// harness's prefix_selectors.py renames a message send whose selector this port defines and no SDK
// header declares, and leaves the DEFINITION's spelling alone, so a send to a `charon_` setter reaches
// `ccharonHost_charon_mps_...` while the definition stays `charon_mps_...` and the port build aborts
// with "unrecognized selector". An overridden class method has no such send.
@implementation MPSCNNSoftMax

+ (BOOL)charon_mps_isLogarithmic
{
    return NO;
}

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                  sourceImage:(MPSImage *)sourceImage
               destinationImage:(MPSImage *)destinationImage
{
    CharonMPSCnnSoftMaxWalk(self, commandBuffer, sourceImage, destinationImage,
                            [[self class] charon_mps_isLogarithmic]);
}

@end

@implementation MPSCNNLogSoftMax
// The whole class, per MPSCNNSoftMax.h:107-110: the logarithmic form is the natural log of the plain
// softmax result, so it is the same walk with the subtraction instead of the division, and nothing else
// of its own. The one thing it answers is which of the two branches its walk takes; see the class
// method on MPSCNNSoftMax for why that is a method and not an instance flag.
+ (BOOL)charon_mps_isLogarithmic
{
    return YES;
}

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                  sourceImage:(MPSImage *)sourceImage
               destinationImage:(MPSImage *)destinationImage
{
    CharonMPSCnnSoftMaxWalk(self, commandBuffer, sourceImage, destinationImage,
                            [[self class] charon_mps_isLogarithmic]);
}
@end

@implementation MPSCNNSpatialNormalization {
    float _alpha, _beta, _delta;
}

@synthesize alpha = _alpha;
@synthesize beta = _beta;
@synthesize delta = _delta;

// MPSCNNNormalization.h:41-48 gives alpha 1.0, beta 5.0, delta 1.0, and all three were read off a
// fresh kernel on this host and agree to the digit. Measured over a 4x4 of 1..16 with kw=kh=3: the
// answer at (0,0) is 2.48832257e-05, and 1/(1 + 66/9)^5 is 2.48832e-05 - the 66 being the sum of the
// squares of the centred 3x3 window, zero outside the image.
- (instancetype)initWithDevice:(id<MTLDevice>)device
                 kernelWidth:(NSUInteger)kernelWidth
                kernelHeight:(NSUInteger)kernelHeight
{
    if ((self = [super initWithDevice:device])) {
        _alpha = 1.0f;
        _beta = 5.0f;
        _delta = 1.0f;
        [self charon_mps_setWindowWidth:kernelWidth height:kernelHeight
                        strideInPixelsX:1 strideInPixelsY:1 dilationRateX:1 dilationRateY:1];
    }
    return self;
}

// Y(i,j) = X(i,j) / (delta + alpha/(kw*kh) * N2(i,j))^beta, MPSCNNNormalization.h:26-28. The
// denominator divides by the window's AREA, so a window hanging off the image is divided by the whole
// kernel and not by the part of it really there - the rule MPSCNNPooling10.m measured for the
// average pooling, and for the same reason.
- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                  sourceImage:(MPSImage *)sourceImage
               destinationImage:(MPSImage *)destinationImage
{
    if (!CharonMPSCommandBufferPermits(commandBuffer))
        return;
    if (!CharonMPSCnnPairIsFloat32(sourceImage, destinationImage, @"MPSCNNSpatialNormalization"))
        return;

    CharonMPSCnnInterleaved from, to;
    if (!CharonMPSCnnRead(sourceImage, &from) || !CharonMPSCnnRead(destinationImage, &to)) {
        CharonMPSCnnWrite(destinationImage, &to);
        CharonMPSCnnWrite(sourceImage, &from);
        return;
    }
    // The view carries its own shape, so a walk reads from.width / from.channels rather than from a
    // second set of locals that could disagree with it.
    size_t inChannels = from.channels, outWidth = to.width, outHeight = to.height, outChannels = to.channels;

    NSUInteger kernel = self.kernelWidth ? self.kernelWidth : 1;
    double area = (double)kernel * (double)(self.kernelHeight ? self.kernelHeight : kernel);
    double alpha = (double)_alpha, beta = (double)_beta, delta = (double)_delta;
    for (size_t channel = 0; channel < outChannels; channel++) {
        size_t source = channel < inChannels ? channel : inChannels - 1;
        for (size_t y = 0; y < outHeight; y++)
            for (size_t x = 0; x < outWidth; x++) {
                double n2 = CharonMPSCnnWindowSquares(&from, source, x, y, kernel);
                double value = CharonMPSCnnValue(&from, x, y, source);
                double denominator = pow(delta + alpha / area * n2, beta);
                double result = denominator == 0.0 ? 0.0 : value / denominator;
                CharonMPSCnnStore(&to, x, y, channel, result);
            }
    }
    CharonMPSCnnWrite(destinationImage, &to);
    CharonMPSCnnWrite(sourceImage, &from);
    CharonMPSConsumeReadCount(sourceImage);
}

@end

@implementation MPSCNNLocalContrastNormalization {
    float _alpha, _beta, _delta, _p0, _pm, _ps;
}

@synthesize alpha = _alpha;
@synthesize beta = _beta;
@synthesize delta = _delta;
@synthesize p0 = _p0;
@synthesize pm = _pm;
@synthesize ps = _ps;

// MPSCNNNormalization.h:151-178 gives every default, and all six were read off a fresh kernel on this
// host and agree to the digit: alpha 0, beta 0.5, delta 0.000976562, p0 1, pm 0, ps 1. The header is
// explicit that alpha 0 is "not recommended and is preserved for backwards compatibility" and that
// with alpha 0 "it performs a local mean subtraction", which is the measured case at the top of this
// file's normalisation notes.
//
// p0 = 1 is load-bearing. At alpha 0 the denominator is the constant delta^beta, so the host's answer
// solves M = X - Y*delta^beta, and at (0,0) that is 1.55555558 against the centred 3x3 mean
// 1.55555556. With p0 = 0 this walk would answer 32 where the host answers -17.7777786.
- (instancetype)initWithDevice:(id<MTLDevice>)device
                 kernelWidth:(NSUInteger)kernelWidth
                kernelHeight:(NSUInteger)kernelHeight
{
    if ((self = [super initWithDevice:device])) {
        _alpha = 0.0f;
        _beta = 0.5f;
        _delta = 1.0f / 1024.0f;
        _p0 = 1.0f;
        _pm = 0.0f;
        _ps = 1.0f;
        [self charon_mps_setWindowWidth:kernelWidth height:kernelHeight
                        strideInPixelsX:1 strideInPixelsY:1 dilationRateX:1 dilationRateY:1];
    }
    return self;
}

// Y(i,j) = pm + ps * (X(i,j) - p0*M(i,j)) / (delta + alpha*VAR(i,j))^beta,
// MPSCNNNormalization.h:139-142. VAR is the window's variance, E[x^2] - M^2, over the same CENTRED
// window with the same off-image zero, and it is the same window helper the spatial normalisation
// uses - which is the point of the correction above: there is one window rule in this file, measured
// once, rather than two of them.
- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                  sourceImage:(MPSImage *)sourceImage
               destinationImage:(MPSImage *)destinationImage
{
    if (!CharonMPSCommandBufferPermits(commandBuffer))
        return;
    if (!CharonMPSCnnPairIsFloat32(sourceImage, destinationImage, @"MPSCNNLocalContrastNormalization"))
        return;

    CharonMPSCnnInterleaved from, to;
    if (!CharonMPSCnnRead(sourceImage, &from) || !CharonMPSCnnRead(destinationImage, &to)) {
        CharonMPSCnnWrite(destinationImage, &to);
        CharonMPSCnnWrite(sourceImage, &from);
        return;
    }
    // The view carries its own shape, so a walk reads from.width / from.channels rather than from a
    // second set of locals that could disagree with it.
    size_t inChannels = from.channels, outWidth = to.width, outHeight = to.height, outChannels = to.channels;

    NSUInteger kernel = self.kernelWidth ? self.kernelWidth : 1;
    double count = (double)kernel * (double)(self.kernelHeight ? self.kernelHeight : kernel);
    double alpha = (double)_alpha, beta = (double)_beta, delta = (double)_delta;
    double p0 = (double)_p0, pm = (double)_pm, ps = (double)_ps;
    for (size_t channel = 0; channel < outChannels; channel++) {
        size_t source = channel < inChannels ? channel : inChannels - 1;
        for (size_t y = 0; y < outHeight; y++)
            for (size_t x = 0; x < outWidth; x++) {
                double sum = CharonMPSCnnWindowSum(&from, source, x, y, kernel);
                double squares = CharonMPSCnnWindowSquares(&from, source, x, y, kernel);
                double mean = sum / count;
                double variance = squares / count - mean * mean;
                double value = CharonMPSCnnValue(&from, x, y, source);
                double denominator = pow(delta + alpha * variance, beta);
                double result = denominator == 0.0 ? pm : pm + ps * (value - p0 * mean) / denominator;
                CharonMPSCnnStore(&to, x, y, channel, result);
            }
    }
    CharonMPSCnnWrite(destinationImage, &to);
    CharonMPSCnnWrite(sourceImage, &from);
    CharonMPSConsumeReadCount(sourceImage);
}

@end

@implementation MPSCNNCrossChannelNormalization {
    float _alpha, _beta, _delta;
    NSUInteger _kernelSize;
}

@synthesize alpha = _alpha;
@synthesize beta = _beta;
@synthesize delta = _delta;
@synthesize kernelSize = _kernelSize;

// MPSCNNNormalization.h:397-413: alpha 1.0, beta 5.0, delta 1.0, and kernelSize 5 - READONLY there,
// so the initialiser is the only way to set it and there is deliberately no setter above.
- (instancetype)initWithDevice:(id<MTLDevice>)device kernelSize:(NSUInteger)kernelSize
{
    if ((self = [super initWithDevice:device])) {
        _alpha = 1.0f;
        _beta = 5.0f;
        _delta = 1.0f;
        _kernelSize = kernelSize ? kernelSize : 5;
    }
    return self;
}

// Y(i,j,k) = X(i,j,k) / L(i,j,k)^beta with L = delta + alpha/N * sum over q in Q(k) of X(i,j,q)^2,
// MPSCNNNormalization.h:379-387. Two things there were measured rather than assumed, and both are
// written at the top of this file: the divisor is the kernelSize (3.000000 implied at all twelve
// outputs checked with kernelSize 3) and not the window's length (2, 3, 2 for the three channels),
// and Q(k) = [k-floor(N/2), k+floor((N-1)/2)] is asymmetric, so channel 0 sees two channels and
// channel 1 sees all three.
- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                  sourceImage:(MPSImage *)sourceImage
               destinationImage:(MPSImage *)destinationImage
{
    if (!CharonMPSCommandBufferPermits(commandBuffer))
        return;
    if (!CharonMPSCnnPairIsFloat32(sourceImage, destinationImage, @"MPSCNNCrossChannelNormalization"))
        return;

    CharonMPSCnnInterleaved from, to;
    if (!CharonMPSCnnRead(sourceImage, &from) || !CharonMPSCnnRead(destinationImage, &to)) {
        CharonMPSCnnWrite(destinationImage, &to);
        CharonMPSCnnWrite(sourceImage, &from);
        return;
    }
    // The view carries its own shape, so a walk reads from.width / from.channels rather than from a
    // second set of locals that could disagree with it.
    size_t inChannels = from.channels, outWidth = to.width, outHeight = to.height, outChannels = to.channels;

    size_t channels = outChannels < inChannels ? outChannels : inChannels;
    NSUInteger size = _kernelSize ? _kernelSize : 5;
    double divisor = (double)size;
    double alpha = (double)_alpha, beta = (double)_beta, delta = (double)_delta;
    for (size_t y = 0; y < outHeight; y++) {
        for (size_t x = 0; x < outWidth; x++) {
            for (size_t channel = 0; channel < channels; channel++) {
                long first = (long)channel - (long)(size / 2);
                long last = (long)channel + (long)((size - 1) / 2);
                if (first < 0)
                    first = 0;
                if (last > (long)channels - 1)
                    last = (long)channels - 1;
                double squares = 0.0;
                for (long q = first; q <= last; q++) {
                    double value = CharonMPSCnnValue(&from, x, y, (size_t)q);
                    squares += value * value;
                }
                double value = CharonMPSCnnValue(&from, x, y, channel);
                double denominator = pow(delta + alpha / divisor * squares, beta);
                double result = denominator == 0.0 ? 0.0 : value / denominator;
                CharonMPSCnnStore(&to, x, y, channel, result);
            }
        }
    }
    CharonMPSCnnWrite(destinationImage, &to);
    CharonMPSCnnWrite(sourceImage, &from);
    CharonMPSConsumeReadCount(sourceImage);
}

@end
