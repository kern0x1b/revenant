#if defined(REVENANT_HOST_BUILD)
#define CIRenderDestination CIRenderDestinationRevenant
#define CIRenderTask CIRenderTaskRevenant
#define CIRenderInfo CIRenderInfoRevenant
#endif

#import <CoreImage/CoreImage.h>
#import <CoreVideo/CoreVideo.h>
#import <IOSurface/IOSurfaceRef.h>
#import <Metal/Metal.h>
#import "RevenantCIRenderDestination.h"
#if defined(REVENANT_HOST_BUILD)
#define GL_SILENCE_DEPRECATION
#import <OpenGL/gl.h>
#else
#import <OpenGLES/ES2/gl.h>
#endif
#if COREIMAGE_SUPPORTS_IOSURFACE
#import <IOSurface/IOSurfaceObjC.h>
#endif

static const OSType RevenantCIPixelFormatRGBA = 0x52474241;

typedef struct {
    NSUInteger x;
    NSUInteger y;
    NSUInteger width;
    NSUInteger height;
    CGAffineTransform transform;
} RevenantCIRegion;

static NSError *RevenantCIRenderError(NSInteger code, NSString *message)
{
    return [NSError errorWithDomain:@"RevenantCoreImageErrorDomain" code:code userInfo:@{NSLocalizedDescriptionKey: message}];
}

static BOOL RevenantCIFormatForPixelFormat(MTLPixelFormat pixelFormat, CIFormat *format)
{
    switch (pixelFormat) {
        case MTLPixelFormatBGRA8Unorm:
            *format = kCIFormatBGRA8;
            return YES;
        case MTLPixelFormatRGBA8Unorm:
            *format = kCIFormatRGBA8;
            return YES;
        default:
            return NO;
    }
}

static BOOL RevenantCIFormatForFourCC(OSType fourCC, CIFormat *format)
{
    if (fourCC == kCVPixelFormatType_32BGRA) {
        *format = kCIFormatBGRA8;
        return YES;
    }
    if (fourCC == RevenantCIPixelFormatRGBA) {
        *format = kCIFormatRGBA8;
        return YES;
    }
    return NO;
}

static NSUInteger RevenantCIBytesPerPixel(CIFormat format)
{
    if (format == kCIFormatBGRA8 || format == kCIFormatRGBA8) {
        return 4;
    }
    if (format == kCIFormatRGBAh) {
        return 8;
    }
    if (format == kCIFormatRGBAf) {
        return 16;
    }
    return 0;
}

static BOOL RevenantCIRegionMake(NSUInteger destinationWidth, NSUInteger destinationHeight, CGRect rect, CGPoint point, BOOL flipped, RevenantCIRegion *region)
{
    const NSInteger width = destinationWidth;
    const NSInteger height = destinationHeight;
    const NSInteger atX = floor(point.x);
    const NSInteger atY = floor(point.y);
    const NSInteger fromX = floor(rect.origin.x);
    const NSInteger fromY = floor(rect.origin.y);
    const NSInteger x0 = MAX(0, atX);
    const NSInteger x1 = MIN(width, atX + floor(rect.size.width));
    const NSInteger bottom = MAX(0, atY);
    const NSInteger top = MIN(height, atY + floor(rect.size.height));
    if (x1 <= x0 || top <= bottom) {
        return NO;
    }
    const CGFloat dx = (CGFloat)(atX - fromX - x0);
    region->x = x0;
    region->width = x1 - x0;
    region->height = top - bottom;
    if (flipped) {
        region->y = height - top;
        region->transform = CGAffineTransformMakeTranslation(dx, (CGFloat)(atY - fromY - bottom));
    } else {
        region->y = bottom;
        CGAffineTransform flip = CGAffineTransformConcat(CGAffineTransformMakeScale(1, -1), CGAffineTransformMakeTranslation(0, height));
        region->transform = CGAffineTransformConcat(flip, CGAffineTransformMakeTranslation(dx, (CGFloat)(fromY - atY - (height - top))));
    }
    return YES;
}

static void RevenantCICopyRegion(const void *source, NSUInteger sourceRowBytes, void *destination, NSUInteger destinationRowBytes, const RevenantCIRegion *region, NSUInteger bytesPerPixel)
{
    const uint8_t *from = source;
    uint8_t *to = destination;
    for (NSUInteger row = 0; row < region->height; row++) {
        memcpy(to + (region->y + row) * destinationRowBytes + region->x * bytesPerPixel, from + row * sourceRowBytes, region->width * bytesPerPixel);
    }
}

static void RevenantCIMakeOpaque(void *data, NSUInteger width, NSUInteger height, NSUInteger rowBytes)
{
    for (NSUInteger row = 0; row < height; row++) {
        uint8_t *pixels = (uint8_t *)data + row * rowBytes;
        for (NSUInteger column = 0; column < width; column++) {
            pixels[column * 4 + 3] = 255;
        }
    }
}

static void RevenantCIUnpremultiply(const float *floats, void *data, NSUInteger width, NSUInteger height, NSUInteger rowBytes, BOOL bgra)
{
    for (NSUInteger row = 0; row < height; row++) {
        const float *source = floats + row * width * 4;
        uint8_t *target = (uint8_t *)data + row * rowBytes;
        for (NSUInteger column = 0; column < width; column++) {
            const float *in = source + column * 4;
            uint8_t straight[3];
            for (int channel = 0; channel < 3; channel++) {
                float value = in[3] > 0 ? floorf(in[channel] / in[3] * 255) : 0;
                straight[channel] = value < 0 ? 0 : value > 255 ? 255 : (uint8_t)value;
            }
            float alpha = roundf(in[3] * 255);
            uint8_t *out = target + column * 4;
            out[0] = bgra ? straight[2] : straight[0];
            out[1] = straight[1];
            out[2] = bgra ? straight[0] : straight[2];
            out[3] = alpha < 0 ? 0 : alpha > 255 ? 255 : (uint8_t)alpha;
        }
    }
}

@implementation CIRenderInfo {
    NSTimeInterval _kernelExecutionTime;
    NSInteger _passCount;
    NSInteger _pixelsProcessed;
}

@synthesize kernelExecutionTime = _kernelExecutionTime;
@synthesize passCount = _passCount;
@synthesize pixelsProcessed = _pixelsProcessed;

- (instancetype)initWithKernelExecutionTime:(NSTimeInterval)kernelExecutionTime passCount:(NSInteger)passCount pixelsProcessed:(NSInteger)pixelsProcessed
{
    if ((self = [super init])) {
        _kernelExecutionTime = kernelExecutionTime;
        _passCount = passCount;
        _pixelsProcessed = pixelsProcessed;
    }
    return self;
}

- (NSTimeInterval)kernelCompileTime
{
    return 0;
}

@end

@implementation CIRenderTask {
    CIRenderInfo *_info;
}

- (instancetype)initWithInfo:(CIRenderInfo *)info
{
    if ((self = [super init])) {
        _info = info;
    }
    return self;
}

- (CIRenderInfo *)waitUntilCompletedAndReturnError:(NSError **)error
{
    return _info;
}

@end

@implementation CIRenderDestination {
    NSUInteger _width;
    NSUInteger _height;
    MTLPixelFormat _pixelFormat;
    id<MTLTexture> _texture;
    id<MTLCommandBuffer> _commandBuffer;
    id<MTLTexture> (^_textureProvider)(void);
    void *_bitmapData;
    NSUInteger _bytesPerRow;
    CIFormat _bitmapFormat;
    CVPixelBufferRef _pixelBuffer;
    IOSurfaceRef _surface;
    GLuint _glTexture;
    GLenum _glTarget;
    CIRenderDestinationAlphaMode _alphaMode;
    BOOL _flipped;
    BOOL _dithered;
    BOOL _clamped;
    CGColorSpaceRef _colorSpace;
    CIBlendKernel *_blendKernel;
    BOOL _blendsInDestinationColorSpace;
}

@synthesize width = _width;
@synthesize height = _height;
@synthesize alphaMode = _alphaMode;
@synthesize flipped = _flipped;
@synthesize dithered = _dithered;
@synthesize clamped = _clamped;
@synthesize blendKernel = _blendKernel;
@synthesize blendsInDestinationColorSpace = _blendsInDestinationColorSpace;

- (void)dealloc
{
    if (_colorSpace) {
        CGColorSpaceRelease(_colorSpace);
    }
    if (_pixelBuffer) {
        CVPixelBufferRelease(_pixelBuffer);
    }
    if (_surface) {
        CFRelease(_surface);
    }
}

- (instancetype)initWithMTLTexture:(id<MTLTexture>)texture commandBuffer:(id<MTLCommandBuffer>)commandBuffer
{
    if ((self = [super init])) {
        _texture = texture;
        _commandBuffer = commandBuffer;
        _width = texture.width;
        _height = texture.height;
        _pixelFormat = texture.pixelFormat;
        [self revenant_applyDefaults];
    }
    return self;
}

- (instancetype)initWithWidth:(NSUInteger)width height:(NSUInteger)height pixelFormat:(MTLPixelFormat)pixelFormat commandBuffer:(id<MTLCommandBuffer>)commandBuffer mtlTextureProvider:(id<MTLTexture> (^)(void))block
{
    if ((self = [super init])) {
        _width = width;
        _height = height;
        _pixelFormat = pixelFormat;
        _commandBuffer = commandBuffer;
        _textureProvider = [block copy];
        [self revenant_applyDefaults];
    }
    return self;
}

- (instancetype)initWithBitmapData:(void *)data width:(NSUInteger)width height:(NSUInteger)height bytesPerRow:(NSUInteger)bytesPerRow format:(CIFormat)format
{
    if ((self = [super init])) {
        _bitmapData = data;
        _width = width;
        _height = height;
        _bytesPerRow = bytesPerRow;
        _bitmapFormat = format;
        [self revenant_applyDefaults];
    }
    return self;
}

- (instancetype)initWithPixelBuffer:(CVPixelBufferRef)pixelBuffer
{
    if ((self = [super init])) {
        _pixelBuffer = CVPixelBufferRetain(pixelBuffer);
        _width = CVPixelBufferGetWidth(pixelBuffer);
        _height = CVPixelBufferGetHeight(pixelBuffer);
        [self revenant_applyDefaults];
    }
    return self;
}

#if COREIMAGE_SUPPORTS_IOSURFACE
- (instancetype)initWithIOSurface:(IOSurface *)surface
{
    if ((self = [super init])) {
        _surface = (IOSurfaceRef)CFRetain((__bridge IOSurfaceRef)surface);
        _width = IOSurfaceGetWidth(_surface);
        _height = IOSurfaceGetHeight(_surface);
        [self revenant_applyDefaults];
    }
    return self;
}
#endif

- (instancetype)initWithGLTexture:(unsigned int)texture target:(unsigned int)target width:(NSUInteger)width height:(NSUInteger)height
{
    if ((self = [super init])) {
        _glTexture = texture;
        _glTarget = target;
        _width = width;
        _height = height;
        [self revenant_applyDefaults];
    }
    return self;
}

- (void)revenant_applyDefaults
{
    _alphaMode = CIRenderDestinationAlphaPremultiplied;
    _flipped = YES;
    _clamped = YES;
}

- (CGColorSpaceRef)colorSpace
{
    return _colorSpace;
}

- (void)setColorSpace:(CGColorSpaceRef)colorSpace
{
    if (colorSpace) {
        CGColorSpaceRetain(colorSpace);
    }
    if (_colorSpace) {
        CGColorSpaceRelease(_colorSpace);
    }
    _colorSpace = colorSpace;
}

- (BOOL)revenant_resolveFormat:(CIFormat *)format error:(NSError **)error
{
    if (_bitmapData) {
        if (!RevenantCIBytesPerPixel(_bitmapFormat)) {
            if (error)
                *error = RevenantCIRenderError(2, @"the bitmap format has no CoreImage pixel size");
            return NO;
        }
        *format = _bitmapFormat;
        return YES;
    }
    if (_pixelBuffer) {
        if (!RevenantCIFormatForFourCC(CVPixelBufferGetPixelFormatType(_pixelBuffer), format)) {
            if (error)
                *error = RevenantCIRenderError(4, @"the pixel buffer's pixel format has no CoreImage format");
            return NO;
        }
        return YES;
    }
    if (_surface) {
        if (!RevenantCIFormatForFourCC(IOSurfaceGetPixelFormat(_surface), format)) {
            if (error)
                *error = RevenantCIRenderError(4, @"the surface's pixel format has no CoreImage format");
            return NO;
        }
        return YES;
    }
    if (_glTexture) {
        if (_glTarget != GL_TEXTURE_2D) {
            if (error)
                *error = RevenantCIRenderError(5, @"only GL_TEXTURE_2D destinations are supported");
            return NO;
        }
        *format = kCIFormatRGBA8;
        return YES;
    }
    if (!RevenantCIFormatForPixelFormat(_pixelFormat, format)) {
        if (error)
            *error = RevenantCIRenderError(1, @"the destination's pixel format has no CoreImage format");
        return NO;
    }
    if (!_texture && !_textureProvider) {
        if (error)
            *error = RevenantCIRenderError(9, @"the destination has no texture");
        return NO;
    }
    return YES;
}

- (BOOL)revenant_writeRegion:(const RevenantCIRegion *)region format:(CIFormat)format pixels:(const void *)pixels rowBytes:(NSUInteger)rowBytes texture:(id<MTLTexture>)texture error:(NSError **)error
{
    const NSUInteger bytesPerPixel = RevenantCIBytesPerPixel(format);
    if (_bitmapData) {
        RevenantCICopyRegion(pixels, rowBytes, _bitmapData, _bytesPerRow, region, bytesPerPixel);
        return YES;
    }
    if (_pixelBuffer) {
        if (CVPixelBufferLockBaseAddress(_pixelBuffer, 0) != kCVReturnSuccess) {
            if (error)
                *error = RevenantCIRenderError(7, @"the pixel buffer cannot be locked");
            return NO;
        }
        RevenantCICopyRegion(pixels, rowBytes, CVPixelBufferGetBaseAddress(_pixelBuffer), CVPixelBufferGetBytesPerRow(_pixelBuffer), region, bytesPerPixel);
        CVPixelBufferUnlockBaseAddress(_pixelBuffer, 0);
        return YES;
    }
    if (_surface) {
        if (IOSurfaceLock(_surface, 0, NULL) != KERN_SUCCESS) {
            if (error)
                *error = RevenantCIRenderError(8, @"the surface cannot be locked");
            return NO;
        }
        RevenantCICopyRegion(pixels, rowBytes, IOSurfaceGetBaseAddress(_surface), IOSurfaceGetBytesPerRow(_surface), region, bytesPerPixel);
        IOSurfaceUnlock(_surface, 0, NULL);
        return YES;
    }
    if (_glTexture) {
        GLint previous = 0;
        glGetIntegerv(GL_TEXTURE_BINDING_2D, &previous);
        glBindTexture(GL_TEXTURE_2D, _glTexture);
        glTexSubImage2D(GL_TEXTURE_2D, 0, (GLint)region->x, (GLint)region->y, (GLsizei)region->width, (GLsizei)region->height, GL_RGBA, GL_UNSIGNED_BYTE, pixels);
        glBindTexture(GL_TEXTURE_2D, previous);
        return YES;
    }
    [texture replaceRegion:MTLRegionMake2D(region->x, region->y, region->width, region->height) mipmapLevel:0 withBytes:pixels bytesPerRow:rowBytes];
    return YES;
}

- (CIRenderTask *)revenant_renderImage:(CIImage *)image context:(CIContext *)context error:(NSError **)error
{
    return [self revenant_renderImage:image fromRect:CGRectMake(0, 0, _width, _height) atPoint:CGPointZero context:context error:error];
}

- (CIRenderTask *)revenant_renderImage:(CIImage *)image fromRect:(CGRect)rect atPoint:(CGPoint)point context:(CIContext *)context error:(NSError **)error
{
    NSDate *started = [NSDate date];
    CIFormat format = kCIFormatRGBA8;
    if (![self revenant_resolveFormat:&format error:error]) {
        return nil;
    }
    if (_alphaMode == CIRenderDestinationAlphaUnpremultiplied && format != kCIFormatBGRA8 && format != kCIFormatRGBA8) {
        if (error)
            *error = RevenantCIRenderError(3, @"unpremultiplied rendering needs an 8-bit BGRA or RGBA destination");
        return nil;
    }
    id<MTLTexture> texture = nil;
    if (!_bitmapData && !_pixelBuffer && !_surface && !_glTexture) {
        texture = _texture ?: (_textureProvider ? _textureProvider() : nil);
        if (!texture) {
            if (error)
                *error = RevenantCIRenderError(9, @"the destination has no texture");
            return nil;
        }
    }
    RevenantCIRegion region;
    if (RevenantCIRegionMake(_width, _height, rect, point, _flipped, &region)) {
        const NSUInteger bytesPerPixel = RevenantCIBytesPerPixel(format);
        const NSUInteger rowBytes = region.width * bytesPerPixel;
        NSMutableData *pixels = [NSMutableData dataWithLength:rowBytes * region.height];
        CGRect bounds = CGRectMake(0, 0, region.width, region.height);
        CIImage *source = [image imageByApplyingTransform:region.transform];
        CGColorSpaceRef colorSpace = _colorSpace;
        CGColorSpaceRef srgb = NULL;
        if (!colorSpace) {
            srgb = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
            colorSpace = srgb;
        }
        if (_alphaMode == CIRenderDestinationAlphaUnpremultiplied) {
            NSMutableData *floats = [NSMutableData dataWithLength:region.width * region.height * 4 * sizeof(float)];
            [context render:source toBitmap:floats.mutableBytes rowBytes:(NSInteger)(region.width * 4 * sizeof(float)) bounds:bounds format:kCIFormatRGBAf colorSpace:colorSpace];
            RevenantCIUnpremultiply(floats.mutableBytes, pixels.mutableBytes, region.width, region.height, rowBytes, format == kCIFormatBGRA8);
        } else {
            [context render:source toBitmap:pixels.mutableBytes rowBytes:(NSInteger)rowBytes bounds:bounds format:format colorSpace:colorSpace];
        }
        if (_alphaMode == CIRenderDestinationAlphaNone && bytesPerPixel == 4) {
            RevenantCIMakeOpaque(pixels.mutableBytes, region.width, region.height, rowBytes);
        }
        if (srgb) {
            CGColorSpaceRelease(srgb);
        }
        if (![self revenant_writeRegion:&region format:format pixels:pixels.mutableBytes rowBytes:rowBytes texture:texture error:error]) {
            return nil;
        }
    }
    CIRenderInfo *info = [[CIRenderInfo alloc] initWithKernelExecutionTime:-[started timeIntervalSinceNow] passCount:1 pixelsProcessed:(NSInteger)(_width * _height)];
    return [[CIRenderTask alloc] initWithInfo:info];
}

- (BOOL)revenant_prepareRenderWithError:(NSError **)error
{
    CIFormat format = kCIFormatRGBA8;
    return [self revenant_resolveFormat:&format error:error];
}

@end
