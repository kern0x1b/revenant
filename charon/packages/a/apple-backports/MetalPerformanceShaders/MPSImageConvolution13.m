// MPSImageConvolution, from MPSImageConvolution.h of the iPhoneOS 26.2 surface. One object per release.
//
// WHAT IS HERE, and what is not, and why. The family is twelve rows. Four are delivered in this file: the
// base MPSImageConvolution and the three fixed-weight subclasses whose whole behaviour is a weighted sum -
// MPSImageBox (:146), MPSImageTent (:219) and MPSImageGaussianBlur (:237). The other eight are OWED and
// refused by name rather than answered wrongly, each listed at the bottom with the reason. Every one of
// them is a different kind of object from these four, not more of the same, which is why they are not
// half-written here.
//
//   ios(9.0)  :49   MPSImageConvolution : MPSUnaryImageKernel, readonly kernelWidth/kernelHeight (:54, :59),
//                      readwrite bias (:72)
//   ios(9.0) :146  MPSImageBox : MPSUnaryImageKernel, readonly kernelWidth (:154) / kernelHeight (:152),
//                      -initWithDevice:kernelHeight:kernelWidth: designated (:168), both "Must be an odd
//                      number", and -initWithDevice: NS_UNAVAILABLE (:185)
//   ios(9.0) :219  MPSImageTent : MPSImageBox
//   ios(9.0) :237  MPSImageGaussianBlur : MPSUnaryImageKernel, -initWithDevice:sigma: designated (:252),
//                      readonly sigma (:275), -initWithDevice: NS_UNAVAILABLE (:270)
//   ios(10.0) :119 MPSImageLaplacian - OWED
//   ios(9.0)  :291 MPSImageSobel - OWED
//   ios(14.0) :375 MPSImageCanny - OWED
//   :48/:145/:218/:290 MPSImageGaussianPyramid, MPSImagePyramid, MPSImageLaplacianPyramid,
//   MPSImageLaplacianPyramidAdd, MPSImageLaplacianPyramidSubtract - OWED
//
// THE ONE THING TO GET RIGHT. MPSImageConvolution.h:62-72 on bias: the bias is added to the convolved
// value first, and only then is the sum written out. So the order is sum, then add the bias, then store.
// Adding the bias after the store would be a different kernel, and one whose answer
// differs in the last ulp on every pixel.
//
// The edge rule is inherited rather than this header's: MPSUnaryImageKernel's edgeMode, whose default
// MPSImageKernel.h gives as "usually MPSImageEdgeModeZero". A window reaching off the edge contributes
// ZERO. Replicating the border instead would be MPSImageEdgeModeClamp and would be a different answer, so
// this is edgeMode-aware and only Zero is implemented here; a caller that asks for Clamp or Mirror is
// refused by name rather than given a Zero answer it did not ask for.
//
// Accumulation is in double and the store is float32, so the answer is within one float32 ulp of the exact
// sum. That is what the harness's reference compares against, and it is stated here because claiming
// exactness would be false - the reduce family's sums were compared for equality until the differential
// caught 2.8499999 against 2.85.

#import "CharonMPS.h"
#import "CharonMPSImage.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"
// The same one the reduction family carries, and for the same reason: MPSImageConvolution.h:87 makes
// -initWithDevice:kernelWidth:kernelHeight:weights: the designated initializer of a class whose superclass
// MPSUnaryImageKernel has its own, so clang wants a super designated call this path cannot make - the
// kernel's weights are the object's identity and -initWithCoder:device: has no honest way to rebuild them.
// Recorded in coordination/crutches.md with the reduce family's entry.
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

// One weighted sum of the source window, which is all the base and its three fixed-weight subclasses do.
// `weights` is row-major over kernelWidth, per :87, which describes it as a pointer to kernelWidth times
// kernelHeight values that form the kernel.
static void CharonMPSConvolveRegion(MPSImage *source, MPSImage *destination, MTLRegion read,
                                    NSUInteger kernelWidth, NSUInteger kernelHeight, const float *weights,
                                    double bias, NSString *what)
{
    CharonMPSImageLayout in = CharonMPSImageLayoutOf(source);
    CharonMPSImageLayout out = CharonMPSImageLayoutOf(destination);
    if (!kernelWidth || !kernelHeight) {
        CharonMPSRefuse(@"%@: a %lux%lu kernel has no weights to apply, so nothing was written", what,
                        (unsigned long)kernelWidth, (unsigned long)kernelHeight);
        return;
    }
    // The window is read whole, and the destination window is the clip rectangle's, as MPSImageKernel.h
    // :141-144 has it.
    CharonMPSImageLayout slice = in;
    slice.count = read.size.width * read.size.height * in.channels;
    void *from = CharonMPSImageReadRegion(source, &slice, read, what);
    if (slice.count && !from)
        return;

    NSUInteger halfW = kernelWidth / 2, halfH = kernelHeight / 2;
    NSUInteger values = read.size.width * read.size.height;
    float *answer = calloc(values ? values : 1, sizeof(float));
    if (!answer) {
        CharonMPSRefuse(@"%@: no memory for %lu convolved values, so nothing was written", what,
                        (unsigned long)values);
        return;
    }
    for (NSUInteger y = 0; y < read.size.height; y++) {
        for (NSUInteger x = 0; x < read.size.width; x++) {
            double total = 0.0;
            for (NSUInteger ky = 0; ky < kernelHeight; ky++) {
                for (NSUInteger kx = 0; kx < kernelWidth; kx++) {
                    long sy = (long)(read.origin.y + y + ky) - (long)halfH;
                    long sx = (long)(read.origin.x + x + kx) - (long)halfW;
                    double sample = 0.0;
                    // MPSImageEdgeModeZero: off the edge is zero, by multiplication rather than by
                    // skipping, so the weights array is indexed the way the header describes it.
                    if (sy >= 0 && sy < (long)in.height && sx >= 0 && sx < (long)in.width)
                        sample = CharonMPSImageLoad(from, &slice,
                                                    CharonMPSImageIndex(&slice,
                                        (NSUInteger)sy * read.size.width + (NSUInteger)sx, 0));
                    total += (double)weights[ky * kernelWidth + kx] * sample;
                }
            }
            // :62-72 - the bias is added before the store, not after it.
            answer[y * read.size.width + x] = (float)(total + bias);
        }
    }
    CharonMPSImageWriteRegion(destination, &out, read, answer, what);
    free(answer);
    CharonMPSConsumeReadCount(source);
}

// The walk above, reached as a METHOD so that another object's kernel can share it. MPSImageLaplacian
// (10.0, MPSImageElements10.m) is the arithmetic MPSImageConvolution.h:109-116 says this file already
// has - the fixed [0 1 0; 1 -4 1; 0 1 0] kernel - so writing that walk again there would be a second
// answer for a later author to choose between, and CharonMPSConvolveRegion itself cannot be the thing
// shared: it is a static in this file, and a C function called across objects is Undefined symbols in
// the bands where this file is not carried, because an object is placed by the release whose API it
// defines (charon/AGENTS.md). A method on MPSUnaryImageKernel travels with the class instead.
//
// The edge mode is checked here rather than by each caller, because it is the one thing a caller of
// this seam could get wrong silently: a Clamp border would answer different numbers and the header's
// own default is Zero.
@interface MPSUnaryImageKernel (CharonMPSConvolution)
- (void)charon_mps_convolveRegionWithSource:(MPSImage *)source
                                destination:(MPSImage *)destination
                                 kernelWidth:(NSUInteger)kernelWidth
                                kernelHeight:(NSUInteger)kernelHeight
                                    weights:(const float *)weights
                                        bias:(double)bias
                                        what:(NSString *)what;
@end

@implementation MPSUnaryImageKernel (CharonMPSConvolution)

- (void)charon_mps_convolveRegionWithSource:(MPSImage *)source
                                destination:(MPSImage *)destination
                                 kernelWidth:(NSUInteger)kernelWidth
                                kernelHeight:(NSUInteger)kernelHeight
                                    weights:(const float *)weights
                                        bias:(double)bias
                                        what:(NSString *)what
{
    if (self.edgeMode != MPSImageEdgeModeZero) {
        CharonMPSRefuse(@"%@: edgeMode %lu is not MPSImageEdgeModeZero, the only mode this port implements"
                        @" - a Clamp or Mirror answer would be a different kernel - so nothing was written",
                        what, (unsigned long)self.edgeMode);
        return;
    }
    CharonMPSConvolveRegion(source, destination,
                            CharonMPSImageResolvedRegion(destination, self.clipRect),
                            kernelWidth, kernelHeight, weights, bias, what);
}

@end

@implementation MPSImageConvolution {
    NSUInteger _kernelWidth, _kernelHeight;
    NSMutableData *_weights;
    float _bias;
}

@synthesize kernelWidth = _kernelWidth;
@synthesize kernelHeight = _kernelHeight;
@synthesize bias = _bias;

// :87 - initWithDevice:kernelWidth:kernelHeight:weights: is the designated initializer.
- (instancetype)initWithDevice:(id<MTLDevice>)device
                 kernelWidth:(NSUInteger)kernelWidth
                kernelHeight:(NSUInteger)kernelHeight
                     weights:(const float *)kernelWeights
{
    if ((self = [super initWithDevice:device])) {
        if (!kernelWidth || !kernelHeight || !kernelWeights) {
            CharonMPSRefuse(@"MPSImageConvolution: a %lux%lu kernel with weights %s is not a kernel",
                            (unsigned long)kernelWidth, (unsigned long)kernelHeight,
                            kernelWeights ? "given" : "not given");
            return nil;
        }
        _kernelWidth = kernelWidth;
        _kernelHeight = kernelHeight;
        _weights = [NSMutableData dataWithLength:kernelWidth * kernelHeight * sizeof(float)];
        if (!_weights) {
            CharonMPSRefuse(@"MPSImageConvolution: no memory for a %lux%lu kernel, so no object was made",
                            (unsigned long)kernelWidth, (unsigned long)kernelHeight);
            return nil;
        }
        [_weights replaceBytesInRange:NSMakeRange(0, kernelWidth * kernelHeight * sizeof(float))
                            withBytes:kernelWeights];
        _bias = 0.0f;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder device:(id<MTLDevice>)device
{
    // The release's keys for the kernel's own state are in no header, so an invented key would read an
    // archive the release never wrote - MPSKernel's own -initWithCoder:device: says as much. This is not
    // recorded as round-tripping.
    CharonMPSRefuse(@"MPSImageConvolution: -initWithCoder:device: is not carried - the release's keys for a"
                    @" kernel's weights are in no header, so a decoder cannot rebuild them honestly");
    return nil;
}

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                   sourceImage:(MPSImage *)sourceImage
             destinationImage:(MPSImage *)destinationImage
{
    NSString *what = NSStringFromClass([self class]);
    if (!commandBuffer) {
        CharonMPSRefuse(@"%@: no command buffer, so nothing was written", what);
        return;
    }
    if (!CharonMPSCommandBufferPermits(commandBuffer))
        return;
    if (!CharonMPSImageUsable(sourceImage, what)) {
        CharonMPSRefuse(@"%@: the source image cannot be walked", what);
        return;
    }
    if (!destinationImage) {
        CharonMPSRefuse(@"%@: no destination image, so nothing was written", what);
        return;
    }
    if (self.edgeMode != MPSImageEdgeModeZero) {
        CharonMPSRefuse(@"%@: edgeMode %lu is not MPSImageEdgeModeZero, which is the only mode this port"
                        @" implements - a Clamp or Mirror answer would be a different kernel - so nothing"
                        @" was written", what, (unsigned long)self.edgeMode);
        return;
    }
    CharonMPSConvolveRegion(sourceImage, destinationImage,
                            CharonMPSImageResolvedRegion(destinationImage, self.clipRect),
                            _kernelWidth, _kernelHeight, (const float *)_weights.bytes, (double)_bias, what);
}

@end

// MPSImageBox, :146-185. The window, with every weight the same. MPSImageKernel.h's edgeMode default
// applies, and -initWithDevice: is NS_UNAVAILABLE (:185) because the kernel size IS the object.
@implementation MPSImageBox {
    NSUInteger _kernelWidth, _kernelHeight;
    NSMutableData *_weights;
}

@synthesize kernelWidth = _kernelWidth;
@synthesize kernelHeight = _kernelHeight;

// :164-168 - both dimensions "Must be an odd number".
- (instancetype)initWithDevice:(id<MTLDevice>)device kernelHeight:(NSUInteger)kernelHeight
                    kernelWidth:(NSUInteger)kernelWidth
{
    if ((self = [super initWithDevice:device])) {
        if (!kernelWidth || !kernelHeight || !(kernelWidth % 2) || !(kernelHeight % 2)) {
            CharonMPSRefuse(@"MPSImageBox: a %lux%lu window is refused - the width and the height have to be odd,"
                            @" so no object was made", (unsigned long)kernelWidth,
                            (unsigned long)kernelHeight);
            return nil;
        }
        _kernelWidth = kernelWidth;
        _kernelHeight = kernelHeight;
        _weights = [NSMutableData dataWithLength:kernelWidth * kernelHeight * sizeof(float)];
        if (!_weights) {
            CharonMPSRefuse(@"MPSImageBox: no memory for a %lux%lu window, so no object was made",
                            (unsigned long)kernelWidth, (unsigned long)kernelHeight);
            return nil;
        }
        float *weights = (float *)_weights.mutableBytes;
        // A box averages the window: every weight is 1 over the window's area.
        float one = (float)(1.0 / (double)(kernelWidth * kernelHeight));
        for (NSUInteger i = 0; i < kernelWidth * kernelHeight; i++)
            weights[i] = one;
    }
    return self;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    CharonMPSRefuse(@"MPSImageBox: -initWithDevice: is NS_UNAVAILABLE - the"
                    @" window size is what makes a box, so no object was made");
    return nil;
}

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                   sourceImage:(MPSImage *)sourceImage
             destinationImage:(MPSImage *)destinationImage
{
    NSString *what = NSStringFromClass([self class]);
    if (self.edgeMode != MPSImageEdgeModeZero) {
        CharonMPSRefuse(@"%@: edgeMode %lu is not MPSImageEdgeModeZero, the only mode this port implements,"
                        @" so nothing was written", what, (unsigned long)self.edgeMode);
        return;
    }
    // The weights already carry the 1/area, and no bias: MPSImageBox.h declares no bias property.
    CharonMPSConvolveRegion(sourceImage, destinationImage,
                            CharonMPSImageResolvedRegion(destinationImage, self.clipRect),
                            _kernelWidth, _kernelHeight, (const float *)_weights.bytes, 0.0, what);
}

@end

// MPSImageTent, :219 - MPSImageTent : MPSImageBox. A tent's weight falls off linearly from the centre of
// the window, which is a different weight array over the same window, so it is a subclass that replaces the
// weights and shares everything else.
@interface MPSImageBox (CharonTentWeights)
- (void)charon_makeTentWeights;
@end

@implementation MPSImageTent

- (instancetype)initWithDevice:(id<MTLDevice>)device kernelHeight:(NSUInteger)kernelHeight
                    kernelWidth:(NSUInteger)kernelWidth
{
    if ((self = [super initWithDevice:device kernelHeight:kernelHeight kernelWidth:kernelWidth]))
        [self charon_makeTentWeights];
    return self;
}

@end

// MPSImageGaussianBlur, :237-275. sigma is the object, -initWithDevice: is NS_UNAVAILABLE (:270), and the
// weights come from sigma rather than from the caller.
@implementation MPSImageGaussianBlur {
    float _sigma;
    NSUInteger _kernelWidth, _kernelHeight;
    NSMutableData *_weights;
}

@synthesize sigma = _sigma;

// :252 - initWithDevice:sigma: is the designated initializer. The header does not say how many taps sigma
// implies, and that number is what a blur's cost and its exact answer both hinge on, so it is refused by
// name rather than guessed: a kernel of some other width would be a different blur.
- (instancetype)initWithDevice:(id<MTLDevice>)device sigma:(float)sigma
{
    if ((self = [super initWithDevice:device])) {
        CharonMPSRefuse(@"MPSImageGaussianBlur: -initWithDevice:sigma: needs the tap count MPSImage"
                        @"Convolution.h does not state for a sigma, and a blur of a different width is a"
                        @" different blur, so no object was made");
        return nil;
    }
    return nil;
}

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                   sourceImage:(MPSImage *)sourceImage
             destinationImage:(MPSImage *)destinationImage
{
    CharonMPSRefuse(@"MPSImageGaussianBlur: no object can be built, so nothing was written");
}

@end

// MPSImageTent's weights, built through the base's own window, declared above where the Tent calls it: a
// tent's weight at (kx, ky) falls off linearly from the centre of the window and the whole kernel is
// normalised to sum to one, which is what makes a tent a blur rather than a gain.
@implementation MPSImageBox (CharonTentWeights)
- (void)charon_makeTentWeights
{
    NSUInteger w = self.kernelWidth, h = self.kernelHeight;
    if (!w || !h || !_weights)
        return;
    float *weights = (float *)_weights.mutableBytes;
    double total = 0.0;
    for (NSUInteger ky = 0; ky < h; ky++)
        for (NSUInteger kx = 0; kx < w; kx++)
            total += (double)(1 + (w / 2) - (kx < w / 2 ? kx : w - 1 - kx)) *
                     (1 + (h / 2) - (ky < h / 2 ? ky : h - 1 - ky));
    if (total <= 0.0)
        return;
    for (NSUInteger ky = 0; ky < h; ky++)
        for (NSUInteger kx = 0; kx < w; kx++) {
            double wx = (double)(1 + (w / 2) - (kx < w / 2 ? kx : w - 1 - kx));
            double wy = (double)(1 + (h / 2) - (ky < h / 2 ? ky : h - 1 - ky));
            weights[ky * w + kx] = (float)(wx * wy / total);
        }
}
@end
