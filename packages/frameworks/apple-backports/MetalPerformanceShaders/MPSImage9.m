#import "RevenantMPS.h"
#import "RevenantMPSImage.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

typedef struct {
    RevenantMPSImageLayout layout;
    unsigned char *pixels;
    NSUInteger width;
    NSUInteger height;
} RevenantMPSImageWindow;

static BOOL RevenantMPSWindowWalkable(MPSImage *a, MPSImage *b, NSString *what)
{
    if (!a || !b)
        return NO;
    if (a.width != b.width || a.height != b.height) {
        RevenantMPSRefuse(@"%@: the two images are %lux%lu and %lux%lu, and this walk reads one element of "
                        "each, so nothing was written",
                        what, (unsigned long)a.width, (unsigned long)a.height,
                        (unsigned long)b.width, (unsigned long)b.height);
        return NO;
    }
    if (RevenantMPSImageDataTypeOf(a.featureChannelFormat) != RevenantMPSImageDataTypeOf(b.featureChannelFormat)) {
        RevenantMPSRefuse(@"%@: the two images hold channel formats %lu and %lu, which are data types %d and "
                        "%d, and this walk reads one element of each, so nothing was written",
                        what, (unsigned long)a.featureChannelFormat, (unsigned long)b.featureChannelFormat,
                        (int)RevenantMPSImageDataTypeOf(a.featureChannelFormat),
                        (int)RevenantMPSImageDataTypeOf(b.featureChannelFormat));
        return NO;
    }
    if (a.featureChannels != b.featureChannels) {
        RevenantMPSRefuse(@"%@: the two images hold %lu and %lu feature channels, so nothing was written",
                        what, (unsigned long)a.featureChannels, (unsigned long)b.featureChannels);
        return NO;
    }
    return YES;
}

static BOOL RevenantMPSWindowOpen(RevenantMPSImageWindow *window, MPSImage *source, MTLRegion clip,
                                NSString *what)
{
    window->layout = RevenantMPSImageLayoutOf(source);
    window->pixels = NULL;
    window->width = window->height = 0;
    if (!RevenantMPSImageUsable(source, what))
        return NO;
    MTLRegion region = RevenantMPSImageResolvedRegion(source, clip);
    if (RevenantMPSImageRegionIsEmpty(region)) {
        RevenantMPSRefuse(@"%@: the clip rectangle leaves no pixel of a %lux%lu source, so nothing was written",
                        what, (unsigned long)source.width, (unsigned long)source.height);
        return NO;
    }
    window->width = region.size.width;
    window->height = region.size.height;
    window->layout.count = window->width * window->height * window->layout.channels;
    window->pixels = RevenantMPSImageReadRegion(source, &window->layout, region, what);
    return window->width ? window->pixels != NULL : YES;
}

static void RevenantMPSWindowClose(RevenantMPSImageWindow *window)
{
    free(window->pixels);
    window->pixels = NULL;
}

static double RevenantMPSWindowAt(const RevenantMPSImageWindow *window, NSInteger x, NSInteger y, NSUInteger channel)
{
    if (x < 0 || y < 0 || (NSUInteger)x >= window->width || (NSUInteger)y >= window->height)
        return 0.0;
    NSUInteger pixel = (NSUInteger)y * window->width + (NSUInteger)x;
    NSUInteger at = RevenantMPSImageIndex(&window->layout, pixel, channel);
    return at == (NSUInteger)-1 ? 0.0 : RevenantMPSImageLoad(window->pixels, &window->layout, at);
}

static BOOL RevenantMPSWalkWindowed(MPSImage *source, MPSImage *destination, MTLRegion clip,
                                  double (^kernel)(const RevenantMPSImageWindow *window, NSInteger x,
                                                   NSInteger y, NSUInteger channel),
                                  NSString *what)
{
    if (!RevenantMPSImageUsable(destination, what))
        return NO;
    if (!RevenantMPSWindowWalkable(source, destination, what))
        return NO;
    RevenantMPSImageWindow window;
    if (!RevenantMPSWindowOpen(&window, source, clip, what))
        return NO;
    MTLRegion region = RevenantMPSImageResolvedRegion(destination, clip);
    RevenantMPSImageLayout out = RevenantMPSImageLayoutOf(destination);
    NSUInteger w = region.size.width, h = region.size.height;
    out.count = w * h * out.channels;
    size_t bytes = (size_t)w * out.channels * h * out.elementSize;
    unsigned char *result = calloc(bytes ? bytes : 1, 1);
    if (!result) {
        RevenantMPSWindowClose(&window);
        RevenantMPSRefuse(@"%@: no memory for a %lux%lu answer, so nothing was written", what,
                        (unsigned long)w, (unsigned long)h);
        return NO;
    }
    for (NSUInteger y = 0; y < h; y++)
        for (NSUInteger x = 0; x < w; x++)
            for (NSUInteger c = 0; c < out.channels; c++) {
                NSUInteger pixel = y * w + x;
                NSUInteger to = RevenantMPSImageIndex(&out, pixel, c);
                if (to != (NSUInteger)-1)
                    RevenantMPSImageStore(result, &out, to, kernel(&window, (NSInteger)x, (NSInteger)y, c));
            }
    BOOL wrote = RevenantMPSImageWriteRegion(destination, &out, region, result, what);
    free(result);
    RevenantMPSWindowClose(&window);
    return wrote;
}

static double RevenantMPSIntegral(const RevenantMPSImageWindow *window, NSInteger x, NSInteger y,
                                NSUInteger channel, BOOL squared)
{
    if (x < 0 || y < 0)
        return 0.0;
    double total = 0.0;
    for (NSInteger j = 0; j <= y; j++)
        for (NSInteger i = 0; i <= x; i++) {
            double value = RevenantMPSWindowAt(window, i, j, channel);
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
        RevenantMPSRefuse(@"MPSImageIntegral: no command buffer, so nothing was written");
        return;
    }
    RevenantMPSWalkWindowed(sourceImage, destinationImage, self.clipRect,
                          ^double(const RevenantMPSImageWindow *window, NSInteger x, NSInteger y, NSUInteger channel) {
                              return RevenantMPSIntegral(window, x, y, channel, NO);
                          }, NSStringFromClass([self class]));
}

@end

@implementation MPSImageIntegralOfSquares

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                 sourceImage:(MPSImage *)sourceImage
            destinationImage:(MPSImage *)destinationImage
{
    if (!commandBuffer) {
        RevenantMPSRefuse(@"MPSImageIntegralOfSquares: no command buffer, so nothing was written");
        return;
    }
    RevenantMPSWalkWindowed(sourceImage, destinationImage, self.clipRect,
                          ^double(const RevenantMPSImageWindow *window, NSInteger x, NSInteger y, NSUInteger channel) {
                              return RevenantMPSIntegral(window, x, y, channel, YES);
                          }, NSStringFromClass([self class]));
}

@end

@implementation MPSImageSobel {
    float _revenantTransformStorage[3];
    const float *_revenantTransform;
}

@synthesize colorTransform = _revenantTransform;

- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    static const float kDefault[3] = { 0.299f, 0.587f, 0.114f };
    return [self initWithDevice:device linearGrayColorTransform:kDefault];
}

- (instancetype)initWithDevice:(id<MTLDevice>)device linearGrayColorTransform:(const float *)transform
{
    if ((self = [super initWithDevice:device])) {
        _revenantTransformStorage[0] = 0.299f;
        _revenantTransformStorage[1] = 0.587f;
        _revenantTransformStorage[2] = 0.114f;
        if (transform)
            for (NSUInteger i = 0; i < 3; i++)
                _revenantTransformStorage[i] = transform[i];
        _revenantTransform = _revenantTransformStorage;
    }
    return self;
}

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                 sourceImage:(MPSImage *)sourceImage
            destinationImage:(MPSImage *)destinationImage
{
    if (!commandBuffer) {
        RevenantMPSRefuse(@"MPSImageSobel: no command buffer, so nothing was written");
        return;
    }
    BOOL gray = sourceImage.featureChannels != destinationImage.featureChannels;
    const float *transform = _revenantTransform;
    RevenantMPSWalkWindowed(sourceImage, destinationImage, self.clipRect,
                          ^double(const RevenantMPSImageWindow *window, NSInteger x, NSInteger y, NSUInteger channel) {
                              const BOOL luminance = gray && window->layout.channels >= 3;
                              const NSUInteger from = gray ? 0 : channel;
                              static const int kx[9] = { -1, 0, 1, -2, 0, 2, -1, 0, 1 };
                              static const int ky[9] = { -1, -2, -1, 0, 0, 0, 1, 2, 1 };
                              double gx = 0.0, gy = 0.0;
                              for (int j = 0; j < 3; j++)
                                  for (int i = 0; i < 3; i++) {
                                      double raw = RevenantMPSWindowAt(window, x + i - 1, y + j - 1, from);
                                      double sample = luminance
                                          ? transform[0] * RevenantMPSWindowAt(window, x + i - 1, y + j - 1, 0)
                                          + transform[1] * RevenantMPSWindowAt(window, x + i - 1, y + j - 1, 1)
                                          + transform[2] * RevenantMPSWindowAt(window, x + i - 1, y + j - 1, 2)
                                          : raw;
                                      gx += kx[j * 3 + i] * sample;
                                      gy += ky[j * 3 + i] * sample;
                                  }
                              return sqrt(gx * gx + gy * gy);
                          }, NSStringFromClass([self class]));
}

@end
