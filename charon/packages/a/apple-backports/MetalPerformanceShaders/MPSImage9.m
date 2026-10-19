#import "CharonMPS.h"
#import "CharonMPSImage.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

typedef struct {
    CharonMPSImageLayout layout;
    unsigned char *pixels;
    NSUInteger width;
    NSUInteger height;
} CharonMPSImageWindow;

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

static double CharonMPSWindowAt(const CharonMPSImageWindow *window, NSInteger x, NSInteger y, NSUInteger channel)
{
    if (x < 0 || y < 0 || (NSUInteger)x >= window->width || (NSUInteger)y >= window->height)
        return 0.0;
    NSUInteger pixel = (NSUInteger)y * window->width + (NSUInteger)x;
    NSUInteger at = CharonMPSImageIndex(&window->layout, pixel, channel);
    return at == (NSUInteger)-1 ? 0.0 : CharonMPSImageLoad(window->pixels, &window->layout, at);
}

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

@implementation MPSImageSobel {
    float _charonTransformStorage[3];
    const float *_charonTransform;
}

@synthesize colorTransform = _charonTransform;

- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    static const float kDefault[3] = { 0.299f, 0.587f, 0.114f };
    return [self initWithDevice:device linearGrayColorTransform:kDefault];
}

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
    BOOL gray = sourceImage.featureChannels != destinationImage.featureChannels;
    const float *transform = _charonTransform;
    CharonMPSWalkWindowed(sourceImage, destinationImage, self.clipRect,
                          ^double(const CharonMPSImageWindow *window, NSInteger x, NSInteger y, NSUInteger channel) {
                              const BOOL luminance = gray && window->layout.channels >= 3;
                              const NSUInteger from = gray ? 0 : channel;
                              static const int kx[9] = { -1, 0, 1, -2, 0, 2, -1, 0, 1 };
                              static const int ky[9] = { -1, -2, -1, 0, 0, 0, 1, 2, 1 };
                              double gx = 0.0, gy = 0.0;
                              for (int j = 0; j < 3; j++)
                                  for (int i = 0; i < 3; i++) {
                                      double raw = CharonMPSWindowAt(window, x + i - 1, y + j - 1, from);
                                      double sample = luminance
                                          ? transform[0] * CharonMPSWindowAt(window, x + i - 1, y + j - 1, 0)
                                          + transform[1] * CharonMPSWindowAt(window, x + i - 1, y + j - 1, 1)
                                          + transform[2] * CharonMPSWindowAt(window, x + i - 1, y + j - 1, 2)
                                          : raw;
                                      gx += kx[j * 3 + i] * sample;
                                      gy += ky[j * 3 + i] * sample;
                                  }
                              return sqrt(gx * gx + gy * gy);
                          }, NSStringFromClass([self class]));
}

@end
