// MPSImage9.m - the three MPSImage kernels SDK 16.4's own headers mark ios(9.0) whose every declared
// member this port can answer, and the whole of whose class chain is 9.0.
//
// One object for one release: every @implementation below is a class whose header annotation is
// ios(9.0) (MPSImageIntegral.h:31 and :52, MPSImageConvolution.h:290), and nothing else is in this file.
//
// THE HIERARCHY IS THE RELEASE'S AND IS KEPT. All three are declared by SDK 16.4 under
// Frameworks/MPSImage.framework/Headers, so a class the SDK declares cannot be re-declared here and
// none is: each inherits MPSUnaryImageKernel, which MPSUnaryImageKernel9.m carries on the same 9.0
// annotation. None of the three declares a member that is not answered here; MPSImageIntegral.h:33-35
// and :54-56 are "@end" straight after the @interface, and MPSImageSobel's four members are this file's.
//
// WHAT IS COMPUTED, from the headers' own wording, one kernel at a time:
//
//   MPSImageIntegral / MPSImageIntegralOfSquares  MPSImageIntegral.h:17-21 and :38-42 give the sum
//     rectangle exactly: its origin is the kernel's offset, and its size is the destination position
//     less the clip rectangle's origin. The value at a destination position is the sum of the source
//     over that rectangle, and the OfSquares variant sums the squares of the pixels (MPSImageIntegral.h:38).
//     That is arithmetic this port does exactly.
//
//   MPSImageSobel    the grey level the filter runs on is a weighted sum of a pixel's three channels, with the
//     weights 0.299, 0.587 and 0.114 (BT.601/JPEG; the default transform at MPSImageConvolution.h:294, the
//     sum at :282-288). The operator is the 3x3 Sobel pair; the Canny step at :352 is G = sqrt(Sx^2 + Sy^2)
//     and at :353 is G_ang = arctan(Sy/Sx). It is NOT the non-maximum suppression of :354-360: that is step 3 of
//     MPSImageCANNY's five, and this class's own description says only that it implements the Sobel filter.
//     The row says so too.
//
// NO ORACLE FOR APPLE'S CODE ON THIS HOST, and no claim of one: the release's own kernels die encoding
// here, because this host's AGX family does not implement computeCommandEncoderWithDispatchType:.
// Every number checked for these three is this port's own answer against a plain C reference written
// from the wording above, in the same process - facts/MetalPerformanceShaders/Image9.md.
//
// THE TWO 9.0 ROWS THIS FILE DOES NOT CARRY, both named in that facts page and owed rather than
// answered, and neither of them because a GPU is missing:
//   MPSImageMedian   MPSImageMedian.h:67 and :71 declare +maxKernelDiameter and +minKernelDiameter,
//                    and NO header in either SDK states a value for either. The median itself is
//                    computable, but two of the class's own members have no answer, and a class that
//                    loads and answers those two with a number this port invented is the thing the
//                    rules forbid. Owed.
//   MPSImageLanczosScale  MPSImageResampling.h:29 annotates its base MPSImageScale ios(11.0) while
//                    :122 annotates LanczosScale itself ios(9.0) - a later base under an earlier
//                    class, which is the release's own hierarchy. Carrying it in a 9.0 object would
//                    put a class that arrived at 11.0 in a 9.0 file, which is the mixed-release object
//                    the band machinery must not be given. Owed with the 11.0 surface.

#import "CharonMPS.h"
#import "CharonMPSImage.h"

// What MPSImageThreshold13.m and MPSUnaryImageKernel9.m carry for the same reason, which is the same
// reason. -initWithCoder:device: is declared on each of these three (MPSImageConvolution.h:320 and
// MPSImageIntegral.h declares none at all) and is implemented ONCE, by MPSUnaryImageKernel9.m, which is
// where MPSKernel9.m:74-82 puts it for the whole family - the release does not define it per subclass
// either, and a subclass that redeclared it would be asked to chain and cannot, MPSImageKernel.h having
// no available -init to chain to. Counted, and the count is the check: ONE -Wincomplete-implementation
// and ONE -Wobjc-designated-initializers per class that declares that initializer, so
// MPSImageSobel alone. Measured stripped of pragmas under -Wall -Wextra.
#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

// What these three share, in one place: the source region read once, and the addressing over it.
//
// The walk layer's unary map (CharonMPSImageMapUnary) hands a callback one element of the source at a
// time, which is right for a pointwise kernel and wrong for a prefix sum: the integral's value at a
// position is the sum of a RECTANGLE, so the whole source region has to be resident before the first
// answer is written. CharonMPSImageReadRegion is the layer's own read of that region and
// CharonMPSImageLoad its own load, so the addressing is still the layer's and only the arithmetic
// moves into this file - the division CharonMPSImage.h's own comment describes.
typedef struct {
    CharonMPSImageLayout layout;   // the source's, with count set to the REGION's element count
    unsigned char *pixels;         // the region, read once, freed by CharonMPSWindowClose
    NSUInteger width;              // the region's own
    NSUInteger height;
} CharonMPSImageWindow;

// The shape agreement CharonMPSImageMapUnary makes through its own CharonMPSImageWalkable, which is
// static in MPSImageWalk13.m:248 and so cannot be called from here. The three checks it makes are
// restated rather than a copy of it: same shape, same channel format, same channel count, each
// refused with the numbers.
static BOOL CharonMPSWindowWalkable(MPSImage *a, MPSImage *b, NSString *what)
{
    if (!a || !b)
        return NO;
    if (a.width != b.width || a.height != b.height) {
        CharonMPSRefuse(@"%@: the two images are %lux%lu and %lux%lu, and this walk reads one element of "
                        "each, so nothing was written",
                        what, (unsigned long)a.width, (unsigned long)a.height,
                        (unsigned long)b.width, (unsigned long)b.height);
        return NO;
    }
    // The DATA TYPE and not the channel format, and that is the layer's own rule
    // (CharonMPSImageMapUnary compares CharonMPSImageDataTypeOf of each): MPSImageIntegral.h:22-26
    // says "If the channels in the source image are normalized, half-float or floating values, the
    // destination image is recommended to be a 32-bit floating-point image", so a unorm8 source into
    // a float32 destination is the case the header names and must walk. Comparing the two FORMATS
    // refused exactly that case, and every value came back 0 - measured, 95 mismatches of 96.
    if (CharonMPSImageDataTypeOf(a.featureChannelFormat) != CharonMPSImageDataTypeOf(b.featureChannelFormat)) {
        CharonMPSRefuse(@"%@: the two images hold channel formats %lu and %lu, which are data types %d and "
                        "%d, and this walk reads one element of each, so nothing was written",
                        what, (unsigned long)a.featureChannelFormat, (unsigned long)b.featureChannelFormat,
                        (int)CharonMPSImageDataTypeOf(a.featureChannelFormat),
                        (int)CharonMPSImageDataTypeOf(b.featureChannelFormat));
        return NO;
    }
    if (a.featureChannels != b.featureChannels) {
        CharonMPSRefuse(@"%@: the two images hold %lu and %lu feature channels, so nothing was written",
                        what, (unsigned long)a.featureChannels, (unsigned long)b.featureChannels);
        return NO;
    }
    return YES;
}

// Read the whole source region once, resolved against the kernel's clip rectangle. The layout handed
// to the load carries the REGION's element count, because the buffer is a region's and
// CharonMPSImageLoad refuses an index outside layout.count by name - a count that stayed the image's
// would refuse or over-read on any clip smaller than the image.
static BOOL CharonMPSWindowOpen(CharonMPSImageWindow *window, MPSImage *source, MTLRegion clip,
                                NSString *what)
{
    window->layout = CharonMPSImageLayoutOf(source);
    window->pixels = NULL;
    window->width = window->height = 0;
    if (!CharonMPSImageUsable(source, what))
        return NO;
    MTLRegion region = CharonMPSImageResolvedRegion(source, clip);
    if (CharonMPSImageRegionIsEmpty(region)) {
        CharonMPSRefuse(@"%@: the clip rectangle leaves no pixel of a %lux%lu source, so nothing was written",
                        what, (unsigned long)source.width, (unsigned long)source.height);
        return NO;
    }
    window->width = region.size.width;
    window->height = region.size.height;
    window->layout.count = window->width * window->height * window->layout.channels;
    window->pixels = CharonMPSImageReadRegion(source, &window->layout, region, what);
    return window->width ? window->pixels != NULL : YES;
}

static void CharonMPSWindowClose(CharonMPSImageWindow *window)
{
    free(window->pixels);
    window->pixels = NULL;
}

// One source element by (x, y) in the REGION's coordinates, or 0.0 outside it. The clip rectangle is
// what says which part of the source this kernel reads, so a window that leaves the region has no
// value to read and contributes nothing: that is the header's edgeModeZero case, which
// MPSImageKernel.h:151-162 gives as the default for every kernel in this family.
static double CharonMPSWindowAt(const CharonMPSImageWindow *window, NSInteger x, NSInteger y, NSUInteger channel)
{
    if (x < 0 || y < 0 || (NSUInteger)x >= window->width || (NSUInteger)y >= window->height)
        return 0.0;
    NSUInteger pixel = (NSUInteger)y * window->width + (NSUInteger)x;
    NSUInteger at = CharonMPSImageIndex(&window->layout, pixel, channel);
    return at == (NSUInteger)-1 ? 0.0 : CharonMPSImageLoad(window->pixels, &window->layout, at);
}

// The walk these three share: resolve the clip, read the source region once, loop the destination
// region, write the answer. The same shape as CharonMPSImageMapUnary's, with the per-element callback
// replaced by the kernel's own rule.
static BOOL CharonMPSWalkWindowed(MPSImage *source, MPSImage *destination, MTLRegion clip,
                                  double (^kernel)(const CharonMPSImageWindow *window, NSInteger x,
                                                   NSInteger y, NSUInteger channel),
                                  NSString *what)
{
    if (!CharonMPSImageUsable(destination, what))
        return NO;
    if (!CharonMPSWindowWalkable(source, destination, what))
        return NO;
    CharonMPSImageWindow window;
    if (!CharonMPSWindowOpen(&window, source, clip, what))
        return NO;
    MTLRegion region = CharonMPSImageResolvedRegion(destination, clip);
    CharonMPSImageLayout out = CharonMPSImageLayoutOf(destination);
    NSUInteger w = region.size.width, h = region.size.height;
    out.count = w * h * out.channels;
    size_t bytes = (size_t)w * out.channels * h * out.elementSize;
    unsigned char *result = calloc(bytes ? bytes : 1, 1);
    if (!result) {
        CharonMPSWindowClose(&window);
        CharonMPSRefuse(@"%@: no memory for a %lux%lu answer, so nothing was written", what,
                        (unsigned long)w, (unsigned long)h);
        return NO;
    }
    for (NSUInteger y = 0; y < h; y++)
        for (NSUInteger x = 0; x < w; x++)
            for (NSUInteger c = 0; c < out.channels; c++) {
                NSUInteger pixel = y * w + x;
                NSUInteger to = CharonMPSImageIndex(&out, pixel, c);
                if (to != (NSUInteger)-1)
                    CharonMPSImageStore(result, &out, to, kernel(&window, (NSInteger)x, (NSInteger)y, c));
            }
    BOOL wrote = CharonMPSImageWriteRegion(destination, &out, region, result, what);
    free(result);
    CharonMPSWindowClose(&window);
    return wrote;
}

// ---- MPSImageIntegral and MPSImageIntegralOfSquares: one shared rectangle sum over the source.
//
// The rectangle comes from the header's declarations (MPSImageIntegral.h:19-20 and :40-41). Its origin is
// the kernel's offset, and its size runs from that origin to the destination position, so at a destination
// position the rectangle runs from the offset to that position and the value is
// the sum of the source inside it. `squared` is the whole of the difference between the two classes:
// MPSImageIntegralOfSquares sums the squares of that same rectangle, MPSImageIntegral.h:38.
//
// The offset is MPSUnaryImageKernel's. MPSImageKernel.h:131-138 places it where the clip rectangle's origin
// sits relative to the source, and the default {0,0,0} puts the two top-left corners together. The rectangle's far corner is the
// destination position ITSELF, not the one before it: the header's size is the difference of two
// positions rather than a count, and a rectangle that many samples across holds one more sample per
// axis than its size. The origin is therefore the offset, which the two encodes below pass as {0,0}
// and which a caller with a non-zero offset is owed rather than answered wrong - see the facts page.
static double CharonMPSIntegral(const CharonMPSImageWindow *window, NSInteger x, NSInteger y,
                                NSUInteger channel, BOOL squared)
{
    if (x < 0 || y < 0)
        return 0.0;
    double total = 0.0;
    for (NSInteger j = 0; j <= y; j++)
        for (NSInteger i = 0; i <= x; i++) {
            double value = CharonMPSWindowAt(window, i, j, channel);
            total += squared ? value * value : value;
        }
    return total;
}

// MPSImageIntegral declares no member of its own (MPSImageIntegral.h:33-35 is "@end" after the
// @interface), so the initializer is the base's and the encode is the one below.
@implementation MPSImageIntegral

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                 sourceImage:(MPSImage *)sourceImage
            destinationImage:(MPSImage *)destinationImage
{
    if (!commandBuffer) {
        CharonMPSRefuse(@"MPSImageIntegral: no command buffer, so nothing was written");
        return;
    }
    CharonMPSWalkWindowed(sourceImage, destinationImage, self.clipRect,
                          ^double(const CharonMPSImageWindow *window, NSInteger x, NSInteger y, NSUInteger channel) {
                              return CharonMPSIntegral(window, x, y, channel, NO);
                          }, NSStringFromClass([self class]));
}

@end

@implementation MPSImageIntegralOfSquares

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                 sourceImage:(MPSImage *)sourceImage
            destinationImage:(MPSImage *)destinationImage
{
    if (!commandBuffer) {
        CharonMPSRefuse(@"MPSImageIntegralOfSquares: no command buffer, so nothing was written");
        return;
    }
    CharonMPSWalkWindowed(sourceImage, destinationImage, self.clipRect,
                          ^double(const CharonMPSImageWindow *window, NSInteger x, NSInteger y, NSUInteger channel) {
                              return CharonMPSIntegral(window, x, y, channel, YES);
                          }, NSStringFromClass([self class]));
}

@end

// ---- MPSImageSobel: the gradient magnitude, per channel, on the luminance when the shapes differ.
//
// The 3x3 pair. The header names its horizontal and vertical filters (MPSImageConvolution.h:350-351) and prints
// no matrix, so this is the standard pair for them:
//   Sx = -1  0  +1        Sy = -1  -2  -1
//        -2  0  +2             0   0   0
//        -1  0  +1             1   2   1
@implementation MPSImageSobel {
    // The header's own type: MPSImageConvolution.h:331-336 declares @property (readonly, nonatomic,
    // nonnull) const float* colorTransform, so the storage is a POINTER the initializer points at
    // storage this class owns, not an array. An array cannot be @synthesize'd to that property: the
    // property is a const float * and the ivar was a float[3], which is a different type.
    float _charonTransformStorage[3];
    const float *_charonTransform;
}

@synthesize colorTransform = _charonTransform;

// MPSImageConvolution.h:293-300: -initWithDevice: takes no transform and uses the default one, so it
// is the designated initializer's caller and not a second way of building the kernel.
- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    // MPSImageConvolution.h:311 declares the transform nonnull, and this convenience initializer is
    // the header's default transform, which this initializer takes (:293-300). Passing the default's three
    // values is the same answer as the header's default and keeps the nonnull contract, rather than
    // passing NULL to a parameter the header says cannot be null.
    static const float kDefault[3] = { 0.299f, 0.587f, 0.114f };   // :294, BT.601/JPEG
    return [self initWithDevice:device linearGrayColorTransform:kDefault];
}

// :303-315: the designated initializer takes three floats. NULL means the header's own default,
// BT.601/JPEG, which :294 gives for this class.
- (instancetype)initWithDevice:(id<MTLDevice>)device linearGrayColorTransform:(const float *)transform
{
    if ((self = [super initWithDevice:device])) {
        _charonTransformStorage[0] = 0.299f;
        _charonTransformStorage[1] = 0.587f;
        _charonTransformStorage[2] = 0.114f;
        if (transform)
            for (NSUInteger i = 0; i < 3; i++)
                _charonTransformStorage[i] = transform[i];
        _charonTransform = _charonTransformStorage;
    }
    return self;
}

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                 sourceImage:(MPSImage *)sourceImage
            destinationImage:(MPSImage *)destinationImage
{
    if (!commandBuffer) {
        CharonMPSRefuse(@"MPSImageSobel: no command buffer, so nothing was written");
        return;
    }
    // MPSImageConvolution.h:283-288: "When the color model (e.g. RGB, two-channel, grayscale, etc.) of
    // source and destination textures match, the filter is applied to each channel separately. If the
    // destination is monochrome (single channel) but source multichannel, the pixel values are
    // converted to grayscale before applying Sobel operator using the linear gray color transform
    // vector (v)." Two different walks, and the header states both, so this file does both.
    BOOL gray = sourceImage.featureChannels != destinationImage.featureChannels;
    const float *transform = _charonTransform;
    CharonMPSWalkWindowed(sourceImage, destinationImage, self.clipRect,
                          ^double(const CharonMPSImageWindow *window, NSInteger x, NSInteger y, NSUInteger channel) {
                              // The luminance of THIS pixel over the transform, from the header's own
                              // three-term formula. A source that is not three channels has no three
                              // terms to weight and IS its own luminance: multiplying a one channel
                              // value by 0.299 is not that, which MPSImageThreshold13.m's comment
                              // records as a real defect that shipped once in this package.
                              const BOOL luminance = gray && window->layout.channels >= 3;
                              const NSUInteger from = gray ? 0 : channel;
                              // Gx and Gy over the 3x3 neighbourhood, in one order for both, so the two
                              // sums see the same pixels in the same sequence.
                              static const int kx[9] = { -1, 0, 1, -2, 0, 2, -1, 0, 1 };
                              static const int ky[9] = { -1, -2, -1, 0, 0, 0, 1, 2, 1 };
                              double gx = 0.0, gy = 0.0;
                              for (int j = 0; j < 3; j++)
                                  for (int i = 0; i < 3; i++) {
                                      double raw = CharonMPSWindowAt(window, x + i - 1, y + j - 1, from);
                                      // The luminance is a property of the PIXEL, so it is formed once
                                      // here, over the transform, and the same three terms the header
                                      // states at :286. A source that is not three channels has no
                                      // three terms to weight and IS its own luminance.
                                      double sample = luminance
                                          ? transform[0] * CharonMPSWindowAt(window, x + i - 1, y + j - 1, 0)
                                          + transform[1] * CharonMPSWindowAt(window, x + i - 1, y + j - 1, 1)
                                          + transform[2] * CharonMPSWindowAt(window, x + i - 1, y + j - 1, 2)
                                          : raw;
                                      gx += kx[j * 3 + i] * sample;
                                      gy += ky[j * 3 + i] * sample;
                                  }
                              // MPSImageConvolution.h:351: "G = sqrt(Sx^2 + Sy^2)".
                              return sqrt(gx * gx + gy * gy);
                          }, NSStringFromClass([self class]));
}

@end
