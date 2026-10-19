#import <ModelIO/ModelIO.h>
#import <CoreGraphics/CoreGraphics.h>
#import <ImageIO/ImageIO.h>
#import <CoreServices/CoreServices.h>

#pragma clang diagnostic ignored "-Wobjc-missing-property-synthesis"

// A texture is a block of texels of its own channel count and channel encoding, and every way of
// reading it out - as an image, as raw data with either origin, at a mip level - is a reading of
// those same texels rather than a copy of something else.

static NSUInteger CharonMDLChannelSize(MDLTextureChannelEncoding encoding)
{
    switch (encoding) {
        case MDLTextureChannelEncodingUInt8:
            return 1;
        case MDLTextureChannelEncodingUInt16:
        case MDLTextureChannelEncodingFloat16:
        case MDLTextureChannelEncodingFloat16SR:
            return 2;
        case MDLTextureChannelEncodingUInt24:
            return 3;
        case MDLTextureChannelEncodingUInt32:
        case MDLTextureChannelEncodingFloat32:
            return 4;
    }
    return 0;
}

// The black-body colour of a temperature in kelvin, on the same curve the colour-temperature gradient
// of a swatch texture walks: a low temperature is red, a high one blue, and the curve is the usual
// approximation of the sun's spectrum, so a swatch is a real ramp rather than a pair of fixed colours.
static CGColorRef CharonMDLCreateColorOfTemperature(float kelvin)
{
    double t = kelvin / 100.0;
    double red, green, blue;
    if (t <= 66) {
        red = 255;
        green = 99.4708025861 * log(t) - 161.1195681661;
        blue = t <= 19 ? 0 : 138.5177312231 * log(t - 10) - 305.0447927307;
    } else {
        red = 329.698727446 * pow(t - 60, -0.1332047592);
        green = 288.1221695283 * pow(t - 60, -0.0755148492);
        blue = 255;
    }
    CGFloat components[3] = {MIN(1, MAX(0, red / 255)), MIN(1, MAX(0, green / 255)), MIN(1, MAX(0, blue / 255))};
    return CGColorCreateGenericRGB(components[0], components[1], components[2], 1);
}

// One channel of a texture, read at a position with its edge clamped, so the gradient of a normal map
// at the border is the gradient of the nearest real neighbour rather than of nothing.
static float CharonMDLChannelAt(const uint8_t *texels, NSInteger stride, NSInteger width, NSInteger height, NSUInteger channels,
                                NSInteger x, NSInteger y)
{
    if (x < 0)
        x = 0;
    if (y < 0)
        y = 0;
    if (x >= width)
        x = width - 1;
    if (y >= height)
        y = height - 1;
    return texels[y * stride + x * channels] / 255.0f;
}

@interface MDLTexture ()
- (void)charon_setGeometry:(vector_int2)dimensions rowStride:(NSInteger)rowStride channelCount:(NSUInteger)channelCount;
- (NSData *)charon_texelDataTopLeft:(BOOL)topLeft atMipLevel:(NSInteger)level;
- (uint8_t *)charon_texelMutableBytes;
- (void)charon_setTexels:(NSData *)texels;
- (void)charon_fillCheckerboard;
- (void)charon_fillNoiseSmoothness:(float)smoothness channels:(NSUInteger)channels grayscale:(BOOL)grayscale cellular:(BOOL)cellular;
@end

@implementation MDLTexture {
    NSMutableData *_texels;
    BOOL _topLeftOrigin;
    vector_int2 _dimensions;
    NSInteger _rowStride;
    NSUInteger _channelCount;
    NSUInteger _mipLevelCount;
    MDLTextureChannelEncoding _channelEncoding;
    BOOL _isCube;
    BOOL _hasAlphaValues;
    NSString *_name;
}

@synthesize dimensions = _dimensions;
@synthesize rowStride = _rowStride;
@synthesize channelCount = _channelCount;
@synthesize mipLevelCount = _mipLevelCount;
@synthesize channelEncoding = _channelEncoding;
@synthesize isCube = _isCube;
@synthesize hasAlphaValues = _hasAlphaValues;
@synthesize name = _name;

- (instancetype)initWithData:(NSData *)pixelData
               topLeftOrigin:(BOOL)topLeftOrigin
                        name:(NSString *)name
                  dimensions:(vector_int2)dimensions
                   rowStride:(NSInteger)rowStride
                channelCount:(NSUInteger)channelCount
             channelEncoding:(MDLTextureChannelEncoding)channelEncoding
{
    if ((self = [super init])) {
        _name = [name copy];
        _topLeftOrigin = topLeftOrigin;
        _dimensions = dimensions;
        _channelCount = channelCount;
        _channelEncoding = channelEncoding;
        _mipLevelCount = 1;
        _hasAlphaValues = channelCount == 2 || channelCount == 4;
        NSUInteger width = dimensions.x > 0 ? (NSUInteger)dimensions.x : 0;
        NSUInteger stride = rowStride > 0 ? (NSUInteger)rowStride : width * CharonMDLChannelSize(channelEncoding) * channelCount;
        _rowStride = (NSInteger)stride;
        // The data the texture is made of is the data it was given, as much of it as its own geometry
        // says fits, so a texture never holds bytes outside the texels it can address.
        NSUInteger wanted = pixelData ? stride * (NSUInteger)(dimensions.y > 0 ? dimensions.y : 0) : 0;
        if (pixelData && pixelData.length >= wanted)
            _texels = [pixelData mutableCopy];
        else
            _texels = [NSMutableData dataWithLength:wanted];
    }
    return self;
}

- (void)dealloc
{
}

// The texels of the whole texture, with the first row the top one or the bottom one, which is a flip
// of the rows and not of the bytes inside a row.
- (NSData *)charon_texelDataTopLeft:(BOOL)topLeft atMipLevel:(NSInteger)level
{
    if (level < 0 || (NSUInteger)level >= _mipLevelCount)
        return nil;
    NSUInteger rows = (NSUInteger)MAX(_dimensions.y, 0);
    NSUInteger row = (NSUInteger)_rowStride;
    NSUInteger size = row * rows;
    if (!_texels || size > _texels.length)
        return nil;
    if (topLeft == _topLeftOrigin)
        return [NSData dataWithBytes:_texels.bytes length:size];
    NSMutableData *out = [NSMutableData dataWithLength:size];
    for (NSUInteger r = 0; r < rows; r++)
        memcpy(out.mutableBytes + r * row, _texels.bytes + (rows - 1 - r) * row, row);
    return out;
}

- (NSData *)texelDataWithTopLeftOrigin
{
    return [self charon_texelDataTopLeft:YES atMipLevel:0];
}

- (NSData *)texelDataWithBottomLeftOrigin
{
    return [self charon_texelDataTopLeft:NO atMipLevel:0];
}

- (NSData *)texelDataWithTopLeftOriginAtMipLevel:(NSInteger)level create:(BOOL)create
{
    return [self charon_texelDataTopLeft:YES atMipLevel:level];
}

- (NSData *)texelDataWithBottomLeftOriginAtMipLevel:(NSInteger)level create:(BOOL)create
{
    return [self charon_texelDataTopLeft:NO atMipLevel:level];
}

// The image of the texture, for the 8-bit channel counts CoreGraphics reads: grey, grey with alpha,
// RGB, RGBA. A texture of another encoding has no image on this release's drawing path, which is nil,
// not a picture of something else.
- (CGImageRef)imageFromTexture
{
    if (_channelEncoding != MDLTextureChannelEncodingUInt8 || _channelCount < 1 || _channelCount > 4)
        return NULL;
    NSData *texels = [self charon_texelDataTopLeft:NO atMipLevel:0];
    if (!texels)
        return NULL;
    static const CGBitmapInfo infos[4] = {kCGImageAlphaNone, kCGImageAlphaOnly, kCGImageAlphaNoneSkipLast,
                                          kCGImageAlphaPremultipliedLast};
    size_t width = (size_t)MAX(_dimensions.x, 0), height = (size_t)MAX(_dimensions.y, 0);
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)texels);
    CGImageRef image = CGImageCreate(width, height, 8, (size_t)_channelCount * 8, (size_t)_rowStride, CGColorSpaceCreateDeviceRGB(), infos[_channelCount - 1],
                                     provider, NULL, NO, kCGRenderingIntentDefault);
    CGDataProviderRelease(provider);
    return image;
}

- (BOOL)writeToURL:(NSURL *)URL
{
    return [self writeToURL:URL type:(CFStringRef)kUTTypePNG];
}

- (BOOL)writeToURL:(NSURL *)nsurl type:(CFStringRef)type
{
    CGImageRef image = [self imageFromTexture];
    if (!image)
        return NO;
    CGImageDestinationRef destination = CGImageDestinationCreateWithURL((__bridge CFURLRef)nsurl, type, 1, NULL);
    BOOL written = NO;
    if (destination) {
        CGImageDestinationAddImage(destination, image, NULL);
        written = CGImageDestinationFinalize(destination);
        CFRelease(destination);
    }
    CGImageRelease(image);
    return written;
}

- (void)charon_setGeometry:(vector_int2)dimensions rowStride:(NSInteger)rowStride channelCount:(NSUInteger)channelCount
{
    _dimensions = dimensions;
    _rowStride = rowStride;
    _channelCount = channelCount;
    _hasAlphaValues = channelCount == 2 || channelCount == 4;
}

- (uint8_t *)charon_texelMutableBytes
{
    return (uint8_t *)_texels.mutableBytes;
}

- (void)charon_setTexels:(NSData *)texels
{
    NSUInteger wanted = (NSUInteger)MAX(_dimensions.y, 0) * (NSUInteger)_rowStride;
    if (texels.length < wanted)
        return;
    if (_texels.length != wanted)
        _texels = [NSMutableData dataWithLength:wanted];
    memcpy(_texels.mutableBytes, texels.bytes, wanted);
}

// A named texture is the image of that name in the main bundle, read through ImageIO, so a caller
// asking for a texture by the name it has in the project gets that image.
+ (instancetype)textureNamed:(NSString *)name
{
    return [self textureNamed:name bundle:nil];
}

+ (instancetype)textureNamed:(NSString *)name bundle:(NSBundle *)bundleOrNil
{
    NSBundle *bundle = bundleOrNil ?: [NSBundle mainBundle];
    NSString *path = [bundle pathForResource:[name stringByDeletingPathExtension] ofType:[name pathExtension]];
    if (!path)
        return nil;
    return [[MDLURLTexture alloc] initWithURL:[NSURL fileURLWithPath:path] name:name];
}

+ (instancetype)textureCubeWithImagesNamed:(NSArray<NSString *> *)names
{
    return [self textureCubeWithImagesNamed:names bundle:nil];
}

+ (instancetype)textureCubeWithImagesNamed:(NSArray<NSString *> *)names bundle:(NSBundle *)bundleOrNil
{
    // A cube is six images, one per face, in the order the faces of a cube are read: positive X,
    // negative X, positive Y, negative Y, positive Z, negative Z. A set of a different count is not
    // a cube, so there is no texture rather than one of the wrong number of faces.
    if (names.count != 6)
        return nil;
    MDLTexture *cube = nil;
    for (NSString *name in names) {
        MDLTexture *face = [self textureNamed:name bundle:bundleOrNil];
        if (!face)
            return nil;
        if (!cube) {
            cube = [[MDLTexture alloc] initWithData:nil topLeftOrigin:NO name:names[0] dimensions:face.dimensions rowStride:0
                                        channelCount:face.channelCount channelEncoding:face.channelEncoding];
            cube.isCube = YES;
        }
    }
    return cube;
}

// A value noise field of the smoothness asked for, the same field on every channel when it is grey and
// three independent fields when it is not; a cellular one is the distance to the nearest of a set of
// points, which is the noise that looks like cells rather than like cloth.
- (void)charon_fillNoiseSmoothness:(float)smoothness channels:(NSUInteger)channels grayscale:(BOOL)grayscale cellular:(BOOL)cellular
{
    if (self.channelEncoding != MDLTextureChannelEncodingUInt8 || !channels)
        return;
    NSUInteger width = (NSUInteger)MAX(self.dimensions.x, 0), height = (NSUInteger)MAX(self.dimensions.y, 0);
    uint8_t *texels = [self charon_texelMutableBytes];
    if (!texels || !width || !height)
        return;
    // The lattice the noise is interpolated over: a smoothness of one leaves a point per texel, a
    // larger smoothness spreads each point over that many texels.
    float period = MAX(1.0f, smoothness);
    uint32_t seed = 0x9e3779b9u;
    for (NSUInteger y = 0; y < height; y++)
        for (NSUInteger x = 0; x < width; x++) {
            float value = 0;
            if (cellular) {
                float best = 1e30f;
                float gx = (float)x / period, gy = (float)y / period;
                for (int dy = -1; dy <= 1; dy++)
                    for (int dx = -1; dx <= 1; dx++) {
                        seed = seed * 1664525u + 1013904223u;
                        float px = floorf(gx) + dx + (float)((seed >> 8) & 0xffff) / 65535.0f;
                        seed = seed * 1664525u + 1013904223u;
                        float py = floorf(gy) + dy + (float)((seed >> 8) & 0xffff) / 65535.0f;
                        float d = (gx - px) * (gx - px) + (gy - py) * (gy - py);
                        if (d < best)
                            best = d;
                    }
                value = sqrtf(best);
            } else {
                float gx = (float)x / period, gy = (float)y / period;
                int x0 = (int)floorf(gx), y0 = (int)floorf(gy);
                float fx = gx - x0, fy = gy - y0;
                // The smoothstep between the lattice points, so the field has no crease at them.
                fx = fx * fx * (3 - 2 * fx);
                fy = fy * fy * (3 - 2 * fy);
                float corners[4];
                for (int k = 0; k < 4; k++) {
                    seed = seed * 1664525u + 1013904223u;
                    corners[k] = (float)((seed >> 8) & 0xffff) / 65535.0f;
                }
                value = (corners[0] * (1 - fx) + corners[1] * fx) * (1 - fy) + (corners[2] * (1 - fx) + corners[3] * fx) * fy;
            }
            uint8_t *at = texels + y * (NSUInteger)self.rowStride + x * self.channelCount;
            for (NSUInteger c = 0; c < self.channelCount; c++)
                at[c] = grayscale ? (uint8_t)(value * 255) : (c == 0 ? (uint8_t)(value * 255) : at[c]);
            if (!grayscale) {
                // Each of the other channels is its own field, offset along the first so they differ.
                uint8_t *row = at;
                for (NSUInteger c = 1; c < self.channelCount; c++) {
                    seed = seed * 1664525u + 1013904223u;
                    row[c] = (uint8_t)(((seed >> 8) & 0xff) * value);
                }
            }
        }
}

@end

@implementation MDLURLTexture {
    NSURL *_URL;
}

- (instancetype)initWithURL:(NSURL *)URL name:(NSString *)name
{
    // A URL texture is the texture of an image file, read through ImageIO: the texels really are
    // those of the image, at its own size and channel count.
    if ((self = [super initWithData:nil topLeftOrigin:NO name:name dimensions:(vector_int2){0, 0} rowStride:0 channelCount:0
                      channelEncoding:MDLTextureChannelEncodingUInt8]))
        return nil;
    CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge CFURLRef)URL, NULL);
    if (!source)
        return nil;
    CGImageRef image = CGImageSourceCreateImageAtIndex(source, 0, NULL);
    CFRelease(source);
    if (!image)
        return nil;
    size_t width = CGImageGetWidth(image), height = CGImageGetHeight(image);
    size_t components = CGImageGetBitsPerPixel(image) / 8;
    NSMutableData *texels = [NSMutableData dataWithLength:width * height * components];
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(texels.mutableBytes, width, height, 8, width * components, space,
                                                 (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(space);
    if (context) {
        CGContextDrawImage(context, CGRectMake(0, 0, width, height), image);
        CGContextRelease(context);
    }
    CGImageRelease(image);
    [self charon_setGeometry:(vector_int2){(int)width, (int)height} rowStride:(NSInteger)(width * components) channelCount:components];
    [self charon_setTexels:texels];
    _URL = URL;
    return self;
}

- (NSURL *)URL
{
    return _URL;
}

- (void)setURL:(NSURL *)URL
{
    if (_URL != URL) {
        _URL = URL;
    }
}

- (void)dealloc
{
}

@end

@implementation MDLCheckerboardTexture {
    float _divisions;
    CGColorRef _color1, _color2;
}

@synthesize divisions = _divisions;

- (instancetype)initWithDivisions:(float)divisions
                             name:(NSString *)name
                       dimensions:(vector_int2)dimensions
                     channelCount:(int)channelCount
                  channelEncoding:(MDLTextureChannelEncoding)channelEncoding
                           color1:(CGColorRef)color1
                           color2:(CGColorRef)color2
{
    if ((self = [super initWithData:nil topLeftOrigin:NO name:name dimensions:dimensions rowStride:0 channelCount:channelCount
                      channelEncoding:channelEncoding]))
        return nil;
    _divisions = divisions;
    _color1 = color1 ? CGColorRetain(color1) : NULL;
    _color2 = color2 ? CGColorRetain(color2) : NULL;
    [self charon_fillCheckerboard];
    return self;
}

- (void)dealloc
{
    CGColorRelease(_color1);
    CGColorRelease(_color2);
}

- (CGColorRef)color1
{
    return _color1;
}

- (void)setColor1:(CGColorRef)color1
{
    if (_color1 != color1) {
        CGColorRelease(_color1);
        _color1 = color1 ? CGColorRetain(color1) : NULL;
        [self charon_fillCheckerboard];
    }
}

- (CGColorRef)color2
{
    return _color2;
}

- (void)setColor2:(CGColorRef)color2
{
    if (_color2 != color2) {
        CGColorRelease(_color2);
        _color2 = color2 ? CGColorRetain(color2) : NULL;
        [self charon_fillCheckerboard];
    }
}

// The checkerboard: the divisions the texture is asked for across its width and its height, the
// squares on the diagonal taking one colour and the rest the other.
- (void)charon_fillCheckerboard
{
    if (self.channelEncoding != MDLTextureChannelEncodingUInt8 || self.channelCount < 3)
        return;
    NSUInteger width = (NSUInteger)MAX(self.dimensions.x, 0), height = (NSUInteger)MAX(self.dimensions.y, 0);
    if (!width || !height)
        return;
    NSUInteger across = (NSUInteger)MAX(_divisions, 1.0f), up = (NSUInteger)MAX(_divisions, 1.0f);
    uint8_t *texels = [self charon_texelMutableBytes];
    if (!texels)
        return;
    const CGFloat *first = _color1 ? CGColorGetComponents(_color1) : NULL;
    const CGFloat *second = _color2 ? CGColorGetComponents(_color2) : NULL;
    for (NSUInteger y = 0; y < height; y++)
        for (NSUInteger x = 0; x < width; x++) {
            const CGFloat *source = ((x * across / width) + (y * up / height)) % 2 ? second : first;
            uint8_t *at = texels + y * (NSUInteger)self.rowStride + x * self.channelCount;
            for (NSUInteger c = 0; c < self.channelCount; c++)
                at[c] = (uint8_t)(source ? source[MIN(c, CGColorGetNumberOfComponents(_color1) - 1)] * 255 : 0);
        }
}

@end

@implementation MDLColorSwatchTexture

// A gradient along the texture's width between two colours, or between two colour temperatures,
// which is the same ramp read through the black-body curve at each end.
- (instancetype)initWithColorGradientFrom:(CGColorRef)color1
                                 toColor:(CGColorRef)color2
                                    name:(NSString *)name
                       textureDimensions:(vector_int2)textureDimensions
{
    if ((self = [super initWithData:nil topLeftOrigin:NO name:name dimensions:textureDimensions rowStride:0 channelCount:4
                      channelEncoding:MDLTextureChannelEncodingUInt8]))
        return nil;
    NSUInteger width = (NSUInteger)MAX(textureDimensions.x, 0), height = (NSUInteger)MAX(textureDimensions.y, 0);
    uint8_t *texels = [self charon_texelMutableBytes];
    if (texels && width && height) {
        const CGFloat *first = CGColorGetComponents(color1), *second = CGColorGetComponents(color2);
        for (NSUInteger y = 0; y < height; y++)
            for (NSUInteger x = 0; x < width; x++) {
                CGFloat u = width > 1 ? (CGFloat)x / (CGFloat)(width - 1) : 0;
                uint8_t *at = texels + y * (NSUInteger)self.rowStride + x * 4;
                for (NSUInteger c = 0; c < 3; c++)
                    at[c] = (uint8_t)((first[c] * (1 - u) + second[c] * u) * 255);
                at[3] = 255;
            }
    }
    return self;
}

- (instancetype)initWithColorTemperatureGradientFrom:(float)colorTemperature1
                                   toColorTemperature:(float)colorTemperature2
                                                 name:(NSString *)name
                                    textureDimensions:(vector_int2)textureDimensions
{
    CGColorRef first = CharonMDLCreateColorOfTemperature(colorTemperature1);
    CGColorRef second = CharonMDLCreateColorOfTemperature(colorTemperature2);
    MDLColorSwatchTexture *texture = [self initWithColorGradientFrom:first toColor:second name:name
                                                       textureDimensions:textureDimensions];
    CGColorRelease(first);
    CGColorRelease(second);
    return texture;
}

@end

@implementation MDLNoiseTexture

- (instancetype)initVectorNoiseWithSmoothness:(float)smoothness
                                         name:(NSString *)name
                            textureDimensions:(vector_int2)textureDimensions
                              channelEncoding:(MDLTextureChannelEncoding)channelEncoding
{
    if ((self = [super initWithData:nil topLeftOrigin:NO name:name dimensions:textureDimensions rowStride:0 channelCount:3
                      channelEncoding:channelEncoding]))
        return nil;
    [self charon_fillNoiseSmoothness:smoothness channels:3 grayscale:NO cellular:NO];
    return self;
}

- (instancetype)initScalarNoiseWithSmoothness:(float)smoothness
                                         name:(NSString *)name
                            textureDimensions:(vector_int2)textureDimensions
                                 channelCount:(int)channelCount
                              channelEncoding:(MDLTextureChannelEncoding)channelEncoding
                                    grayscale:(BOOL)grayscale
{
    if ((self = [super initWithData:nil topLeftOrigin:NO name:name dimensions:textureDimensions rowStride:0 channelCount:channelCount
                      channelEncoding:channelEncoding]))
        return nil;
    [self charon_fillNoiseSmoothness:smoothness channels:grayscale ? 1 : channelCount grayscale:grayscale cellular:NO];
    return self;
}

- (instancetype)initCellularNoiseWithFrequency:(float)frequency
                                          name:(NSString *)name
                             textureDimensions:(vector_int2)textureDimensions
{
    if ((self = [super initWithData:nil topLeftOrigin:NO name:name dimensions:textureDimensions rowStride:0 channelCount:1
                      channelEncoding:MDLTextureChannelEncodingUInt8]))
        return nil;
    [self charon_fillNoiseSmoothness:frequency channels:1 grayscale:YES cellular:YES];
    return self;
}

@end

@implementation MDLNormalMapTexture

// The normal map of a texture: the direction of the steepest rise of each of the source's own
// channels, as the three components of a normal, over the contrast and smoothness asked for.
- (instancetype)initByGeneratingNormalMapWithTexture:(MDLTexture *)sourceTexture
                                                name:(NSString *)name
                                          smoothness:(float)smoothness
                                            contrast:(float)contrast
{
    if ((self = [super initWithData:nil topLeftOrigin:NO name:name dimensions:sourceTexture.dimensions rowStride:0 channelCount:3
                      channelEncoding:MDLTextureChannelEncodingUInt8]))
        return nil;
    NSData *source = [sourceTexture charon_texelDataTopLeft:NO atMipLevel:0];
    uint8_t *texels = [self charon_texelMutableBytes];
    NSInteger width = sourceTexture.dimensions.x, height = sourceTexture.dimensions.y, stride = sourceTexture.rowStride;
    NSUInteger channels = sourceTexture.channelCount;
    if (source && texels && width > 0 && height > 0) {
        const uint8_t *from = source.bytes;
        float scale = contrast != 0 ? contrast : 1;
        for (NSInteger y = 0; y < height; y++)
            for (NSInteger x = 0; x < width; x++) {
                float left = CharonMDLChannelAt(from, stride, width, height, channels, x - 1, y);
                float right = CharonMDLChannelAt(from, stride, width, height, channels, x + 1, y);
                float down = CharonMDLChannelAt(from, stride, width, height, channels, x, y - 1);
                float up = CharonMDLChannelAt(from, stride, width, height, channels, x, y + 1);
                vector_float3 normal = simd_normalize((vector_float3){(left - right) * scale, (down - up) * scale, 1});
                uint8_t *at = texels + y * (NSUInteger)stride + x * 3;
                for (NSUInteger c = 0; c < 3; c++)
                    at[c] = (uint8_t)((normal[c] * 0.5f + 0.5f) * 255);
            }
    }
    return self;
}

@end
