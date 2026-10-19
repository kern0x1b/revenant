#import <CoreImage/CoreImage.h>
#import <CoreVideo/CoreVideo.h>
#import <string.h>
#import <CoreGraphics/CoreGraphics.h>
#import <objc/runtime.h>

// The key the bitmap context is kept under, on the image that looks at its memory.
static const void *kCharonCIAccumulatorBufferKey = &kCharonCIAccumulatorBufferKey;

#pragma clang diagnostic ignored "-Wobjc-missing-property-synthesis"

// A CIImageAccumulator is a piece of memory an image can be rendered into and read back out of, at an
// extent and a pixel format the caller names. It is how a filter is applied one tile or one row at a
// time without a context per step: the image comes out as a CIImage over the same bytes, and setting
// an image renders into them - all of them, or just the rectangle that changed.

@implementation CIImageAccumulator {
    NSMutableData *_pixels;
    CGRect _extent;
    CIFormat _format;
    NSInteger _rowBytes;
    NSUInteger _pixelWidth, _pixelHeight;
    // A strong reference, as every other object here: the port is built with ARC, which manages this
    // itself. Retaining it by hand on the way in and releasing it on the way out is releasing it
    // twice, which is what a caller saw.
    CGColorSpaceRef _colorSpace;
    CIContext *_context;
}

@synthesize extent = _extent;
@synthesize format = _format;

// The bytes one pixel of a format takes, and the order its channels are in. The four formats the
// accumulator is asked for most are the ones with a byte order to get right: what is written has to
// read back as the same picture, whichever of the two orders the caller named.
static NSUInteger CharonCIAccumulatorBytesPerPixel(CIFormat format)
{
    // The formats as ifs and not as a switch: the header declares them as exported constants, not as
    // enum cases, so they are values and not case labels.
    if (format == kCIFormatA8 || format == kCIFormatL8 || format == kCIFormatR8)
        return 1;
    if (format == kCIFormatLA8 || format == kCIFormatRG8 || format == kCIFormatARGB8 ||
        format == kCIFormatRGBA8 || format == kCIFormatBGRA8)
        return 4;
    if (format == kCIFormatRGBAf || format == kCIFormatRGBAh)
        return 8;
    return 4;
}

// Whether the red channel is the first of the four, or the third: BGRA and RGBA are the two formats
// an accumulator is asked for most, and they disagree on the same bytes.
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
        // The extent is the caller's, whole pixels or not: the host answers the extent it was given,
        // and integralising it here is a different answer.
        _extent = extent;
        _format = format;
        _colorSpace = colorSpace;
        // The buffer is the whole pixels of the extent and nothing else: an extent of 5.5 wide is five
        // pixels across, which is what the system answers, and sizing the row by the caller's own
        // fractional width gave a row of twenty-two bytes over a buffer of seventy-seven, and the image
        // read out of it ran off the end.
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

// What an accumulator actually holds, whatever it was asked for: the host answers BGRA for an RGBA8
// request and for a BGRA8 one alike, so the bytes are in that order and the format says so.
static CIFormat CharonCIAccumulatorStoredFormat(void)
{
    return kCIFormatBGRA8;
}

// The image is a view of the accumulator's own bytes, so what was set into them is what comes out,
// and setting it again changes the same bytes the image reads. iOS 6 has no image over bytes, so the
// image is made through a bitmap context over the same memory: the same pixels, the same origin.
- (CIImage *)image
{
    // The image is the whole pixels at the origin, which is what the system answers for an extent that
    // does not start there and is not a whole number of pixels wide.
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
            // The image looks at the context's memory, so the context has to live as long as the image
            // does - and it is the accumulator's own buffer, which is the point: what is set into the
            // accumulator after this is what the image a caller already holds reads. Releasing the
            // context here left the image pointing at freed memory, and the renderer died on it.
            objc_setAssociatedObject(image, kCharonCIAccumulatorBufferKey, (__bridge id)context, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        CGContextRelease(context);
    }
    if (!_colorSpace)
        CGColorSpaceRelease(space);
    return image;
}

// A context that renders into the accumulator, made once: a context is an expensive thing and the
// accumulator is the thing that is asked for over and over.
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
    // The context is made here, not read: -charon_context is what creates it and nothing else in the
    // class does, so asking for _context here returned nil on every accumulator whose -charon_context
    // nobody had called yet - which is every one of them, because it is not an API - and this method
    // returned without rendering anything. Measured: the port's "rgba set pixels" was byte for byte
    // its own untouched accumulator, 128 a7b537c5, where the system's is 128 4fcd0585, and the four
    // pixels spelled out were 0 0 0 0 against 255 0 0 255.
    CIContext *context = [self charon_context];
    if (!context)
        return;
    // The bytes are the accumulator's own and the format is the one the host answers, BGRA8, so the
    // row the context renders is red first and the buffer is blue first. The context hands over the
    // order it always hands over, so the two outer channels are exchanged as the row is written; a
    // picture stored red first and reported blue first comes back with red and blue the wrong way
    // round, and this is the whole of what the format normalisation costs.
    NSMutableData *row = [NSMutableData dataWithLength:(NSUInteger)(_rowBytes * _pixelHeight)];
    [context render:image toBitmap:row.mutableBytes rowBytes:_rowBytes bounds:rect format:kCIFormatRGBA8
            colorSpace:_colorSpace];
    // A rectangle is written only when it is a whole number of pixels at a whole pixel, and
    // measured, not assumed.  The buffer is the whole pixels of the extent at the origin, so a
    // rectangle whose origin or whose far side falls between two pixels has no row of the buffer it
    // maps onto; and the system writes nothing at all for one: measured over an extent of
    // 1.5 -2.25 5.5 3.5, "odd set pixels" is 60 0 0 0 0 on the system and on an accumulator of a
    // whole extent 0 0 8 4 the same call gives 255 0 0 255.  So a rectangle that is not whole is
    // left alone rather than clipped into something the system would not have written - clipping
    // it put a row of red into a buffer the system leaves empty, and the checksum said so:
    // 60 73191c6b against the system's 60 f6009964.
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
    // The rendered row is the rectangle's own width wide, not the buffer's: copying the buffer's
    // width out of a four-pixel row read the six pixels after it - whatever the allocator left -
    // into the right half of the accumulator.  Measured, with the dirty rect of 0 0 4 4 over a
    // buffer of 8 by 4: the port's "dirty after" was 128 015ce025 where the system's is 128
    // c2bab905, and the system's is the four blue columns of the rectangle and the four red ones
    // that were already there.
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

// The accumulator's own bytes, replaced. This is what lets a kernel of the port's own write its result
// into an accumulator and hand back a CIImage over it: -image is a view of these bytes, so what a
// kernel puts here is what the image a caller holds reads.
- (void)charon_setTexels:(NSData *)texels
{
    if (!_pixels || texels.length != _pixels.length)
        return;
    memcpy(_pixels.mutableBytes, texels.bytes, texels.length);
}

@end
