#import <CoreImage/CoreImage.h>
#import <CoreVideo/CoreVideo.h>
#import <string.h>
#import <CoreGraphics/CoreGraphics.h>
#import <objc/runtime.h>

static const void *kCharonCIAccumulatorBufferKey = &kCharonCIAccumulatorBufferKey;

#pragma clang diagnostic ignored "-Wobjc-missing-property-synthesis"

@implementation CIImageAccumulator {
    NSMutableData *_pixels;
    CGRect _extent;
    CIFormat _format;
    NSInteger _rowBytes;
    NSUInteger _pixelWidth, _pixelHeight;
    CGColorSpaceRef _colorSpace;
    CIContext *_context;
}

@synthesize extent = _extent;
@synthesize format = _format;

static NSUInteger CharonCIAccumulatorBytesPerPixel(CIFormat format)
{
    if (format == kCIFormatA8 || format == kCIFormatL8 || format == kCIFormatR8)
        return 1;
    if (format == kCIFormatLA8 || format == kCIFormatRG8 || format == kCIFormatARGB8 ||
        format == kCIFormatRGBA8 || format == kCIFormatBGRA8)
        return 4;
    if (format == kCIFormatRGBAf || format == kCIFormatRGBAh)
        return 8;
    return 4;
}

static BOOL CharonCIAccumulatorIsBlueFirst(CIFormat format)
{
    return format == kCIFormatBGRA8;
}

- (instancetype)initWithExtent:(CGRect)extent format:(CIFormat)format
{
    return [self initWithExtent:extent format:format colorSpace:nil];
}

- (instancetype)initWithExtent:(CGRect)extent format:(CIFormat)format colorSpace:(CGColorSpaceRef)colorSpace
{
    format = CharonCIAccumulatorStoredFormat();
    if ((self = [super init])) {
        _extent = extent;
        _format = format;
        _colorSpace = colorSpace;
        _pixelWidth = (NSUInteger)floor(extent.size.width);
        _pixelHeight = (NSUInteger)floor(extent.size.height);
        _rowBytes = (NSInteger)(_pixelWidth * CharonCIAccumulatorBytesPerPixel(format));
        _pixels = [NSMutableData dataWithLength:(NSUInteger)(_rowBytes * _pixelHeight)];
    }
    return self;
}

- (void)dealloc
{
}

+ (CIImageAccumulator *)imageAccumulatorWithExtent:(CGRect)extent format:(CIFormat)format
{
    return [self imageAccumulatorWithExtent:extent format:format colorSpace:nil];
}

+ (CIImageAccumulator *)imageAccumulatorWithExtent:(CGRect)extent format:(CIFormat)format
                                      colorSpace:(CGColorSpaceRef)colorSpace
{
    return [[CIImageAccumulator alloc] initWithExtent:extent format:format colorSpace:colorSpace];
}

static CIFormat CharonCIAccumulatorStoredFormat(void)
{
    return kCIFormatBGRA8;
}

- (CIImage *)image
{
    if (!_pixelWidth || !_pixelHeight)
        return nil;
    CGRect whole = CGRectMake(0, 0, (CGFloat)_pixelWidth, (CGFloat)_pixelHeight);
    CGColorSpaceRef space = _colorSpace ?: CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(_pixels.mutableBytes, _pixelWidth, _pixelHeight, 8,
                                                 (size_t)_rowBytes, space, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    CIImage *image = nil;
    if (context) {
        CGImageRef made = CGBitmapContextCreateImage(context);
        if (made) {
            image = [CIImage imageWithCGImage:made];
            CGImageRelease(made);
            objc_setAssociatedObject(image, kCharonCIAccumulatorBufferKey, (__bridge id)context, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        CGContextRelease(context);
    }
    if (!_colorSpace)
        CGColorSpaceRelease(space);
    return image;
}

- (CIContext *)charon_context
{
    if (!_context) {
        NSMutableDictionary *options = [NSMutableDictionary dictionary];
        options[kCIContextWorkingColorSpace] = [NSNull null];
        options[kCIContextOutputPremultiplied] = @NO;
        if (_colorSpace)
            options[kCIContextWorkingColorSpace] = (__bridge id)_colorSpace;
        _context = [CIContext contextWithOptions:options];
    }
    return _context;
}

- (void)setImage:(CIImage *)image
{
    [self setImage:image dirtyRect:_extent];
}

- (void)setImage:(CIImage *)image dirtyRect:(CGRect)dirtyRect
{
    if (!image)
        return;
    CGRect rect = CGRectIntersection(dirtyRect, _extent);
    if (CGRectIsNull(rect) || CGRectIsEmpty(rect))
        return;
    CIContext *context = [self charon_context];
    if (!context)
        return;
    NSMutableData *row = [NSMutableData dataWithLength:(NSUInteger)(_rowBytes * _pixelHeight)];
    [context render:image toBitmap:row.mutableBytes rowBytes:_rowBytes bounds:rect format:kCIFormatRGBA8
            colorSpace:_colorSpace];
    if (CGRectGetMinX(rect) != floor(CGRectGetMinX(rect)) || CGRectGetMinY(rect) != floor(CGRectGetMinY(rect)) ||
        CGRectGetWidth(rect) != floor(CGRectGetWidth(rect)) || CGRectGetHeight(rect) != floor(CGRectGetHeight(rect)))
        return;
    size_t offsetX = (size_t)(CGRectGetMinX(rect) - CGRectGetMinX(_extent));
    size_t offsetY = (size_t)(CGRectGetMinY(rect) - CGRectGetMinY(_extent));
    size_t rows = (size_t)CGRectGetHeight(rect);
    size_t columns = (size_t)CGRectGetWidth(rect);
    if (offsetX + columns > (size_t)_pixelWidth || offsetY + rows > (size_t)_pixelHeight)
        return;
    uint8_t *from = row.mutableBytes;
    uint8_t *to = _pixels.mutableBytes;
    for (size_t y = 0; y < rows; y++) {
        for (size_t x = 0; x < columns; x++) {
            size_t inPixel = y * (size_t)_pixelWidth + x;
            size_t outPixel = (offsetY + y) * (size_t)_pixelWidth + (offsetX + x);
            uint8_t *src = from + inPixel * 4;
            uint8_t *dst = to + outPixel * 4;
            dst[0] = src[0];
            dst[1] = src[1];
            dst[2] = src[2];
            dst[3] = src[3];
        }
    }
}

- (void)clear
{
    memset(_pixels.mutableBytes, 0, _pixels.length);
}

@end

@implementation CIImageAccumulator (CharonPixels)

- (void)charon_setTexels:(NSData *)texels
{
    if (!_pixels || texels.length != _pixels.length)
        return;
    memcpy(_pixels.mutableBytes, texels.bytes, texels.length);
}

@end
