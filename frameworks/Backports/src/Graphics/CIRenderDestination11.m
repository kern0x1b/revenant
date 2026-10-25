#if defined(REVENANT_HOST_BUILD)
#define CIRenderDestination CIRenderDestinationRevenant
#define CIRenderTask CIRenderTaskRevenant
#define CIRenderInfo CIRenderInfoRevenant
#endif

#import <CoreImage/CoreImage.h>
#import <Metal/Metal.h>
#import "RevenantCIRenderDestination.h"

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

- (CIRenderTask *)revenant_renderImage:(CIImage *)image context:(CIContext *)context error:(NSError **)error
{
    id<MTLTexture> texture = _texture ?: (_textureProvider ? _textureProvider() : nil);
    CIFormat format = _bitmapFormat;
    NSUInteger rowBytes = _bytesPerRow;
    void *bytes = _bitmapData;
    NSMutableData *scratch = nil;
    if (!bytes) {
        if (!texture || !RevenantCIFormatForPixelFormat(_pixelFormat, &format)) {
            if (error)
                *error = RevenantCIRenderError(1, @"the destination's pixel format has no CoreImage format");
            return nil;
        }
        rowBytes = _width * 4;
        scratch = [NSMutableData dataWithLength:rowBytes * _height];
        bytes = scratch.mutableBytes;
    }
    CGRect bounds = CGRectMake(0, 0, _width, _height);
    CIImage *source = image;
    if (!_flipped) {
        source = [source imageByApplyingTransform:CGAffineTransformConcat(CGAffineTransformMakeScale(1, -1), CGAffineTransformMakeTranslation(0, _height))];
    }
    CGColorSpaceRef colorSpace = _colorSpace;
    CGColorSpaceRef srgb = NULL;
    if (!colorSpace) {
        srgb = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
        colorSpace = srgb;
    }
    NSDate *started = [NSDate date];
    if (_alphaMode == CIRenderDestinationAlphaUnpremultiplied) {
        if (format != kCIFormatBGRA8 && format != kCIFormatRGBA8) {
            if (srgb) {
                CGColorSpaceRelease(srgb);
            }
            if (error)
                *error = RevenantCIRenderError(3, @"unpremultiplied rendering needs an 8-bit BGRA or RGBA destination");
            return nil;
        }
        NSMutableData *floats = [NSMutableData dataWithLength:_width * _height * 4 * sizeof(float)];
        [context render:source toBitmap:floats.mutableBytes rowBytes:(NSInteger)(_width * 4 * sizeof(float)) bounds:bounds format:kCIFormatRGBAf colorSpace:colorSpace];
        RevenantCIUnpremultiply(floats.mutableBytes, bytes, _width, _height, rowBytes, format == kCIFormatBGRA8);
    } else {
        [context render:source toBitmap:bytes rowBytes:(NSInteger)rowBytes bounds:bounds format:format colorSpace:colorSpace];
    }
    if (_alphaMode == CIRenderDestinationAlphaNone) {
        RevenantCIMakeOpaque(bytes, _width, _height, rowBytes);
    }
    if (srgb) {
        CGColorSpaceRelease(srgb);
    }
    if (texture) {
        [texture replaceRegion:MTLRegionMake2D(0, 0, _width, _height) mipmapLevel:0 withBytes:bytes bytesPerRow:rowBytes];
    }
    CIRenderInfo *info = [[CIRenderInfo alloc] initWithKernelExecutionTime:-[started timeIntervalSinceNow] passCount:1 pixelsProcessed:(NSInteger)(_width * _height)];
    return [[CIRenderTask alloc] initWithInfo:info];
}

@end
