#import "RevenantMPS.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, RevenantMPSTextureElement) {
    RevenantMPSTextureElementUnorm8,
    RevenantMPSTextureElementUnorm16,
    RevenantMPSTextureElementFloat16,
    RevenantMPSTextureElementFloat32,
};

static inline BOOL RevenantMPSTextureFormat(MTLPixelFormat pixel, NSUInteger *channels, RevenantMPSTextureElement *element)
{
    NSUInteger count;
    RevenantMPSTextureElement kind;
    switch (pixel) {
    case MTLPixelFormatR8Unorm:      kind = RevenantMPSTextureElementUnorm8;  count = 1; break;
    case MTLPixelFormatRG8Unorm:     kind = RevenantMPSTextureElementUnorm8;  count = 2; break;
    case MTLPixelFormatRGBA8Unorm:
    case MTLPixelFormatBGRA8Unorm:   kind = RevenantMPSTextureElementUnorm8;  count = 4; break;
    case MTLPixelFormatR16Unorm:     kind = RevenantMPSTextureElementUnorm16; count = 1; break;
    case MTLPixelFormatRG16Unorm:    kind = RevenantMPSTextureElementUnorm16; count = 2; break;
    case MTLPixelFormatRGBA16Unorm:  kind = RevenantMPSTextureElementUnorm16; count = 4; break;
    case MTLPixelFormatR16Float:     kind = RevenantMPSTextureElementFloat16; count = 1; break;
    case MTLPixelFormatRG16Float:    kind = RevenantMPSTextureElementFloat16; count = 2; break;
    case MTLPixelFormatRGBA16Float:  kind = RevenantMPSTextureElementFloat16; count = 4; break;
    case MTLPixelFormatR32Float:     kind = RevenantMPSTextureElementFloat32; count = 1; break;
    case MTLPixelFormatRG32Float:    kind = RevenantMPSTextureElementFloat32; count = 2; break;
    case MTLPixelFormatRGBA32Float:  kind = RevenantMPSTextureElementFloat32; count = 4; break;
    default: return NO;
    }
    if (channels)
        *channels = count;
    if (element)
        *element = kind;
    return YES;
}

static inline size_t RevenantMPSTextureElementSize(RevenantMPSTextureElement element)
{
    switch (element) {
    case RevenantMPSTextureElementUnorm8:   return 1;
    case RevenantMPSTextureElementFloat32:  return 4;
    default:                                return 2;
    }
}

static inline BOOL RevenantMPSTexturePixelShape(MTLPixelFormat pixel, NSUInteger *channels, size_t *elementSize)
{
    RevenantMPSTextureElement element;
    NSUInteger count;
    if (!RevenantMPSTextureFormat(pixel, &count, &element))
        return NO;
    if (channels)
        *channels = count;
    if (elementSize)
        *elementSize = RevenantMPSTextureElementSize(element);
    return YES;
}

static inline double RevenantMPSTextureClampUnit(double value)
{
    return value < 0.0 ? 0.0 : (value > 1.0 ? 1.0 : value);
}

static inline double RevenantMPSTextureLoad(const void *bytes, RevenantMPSTextureElement element, size_t index)
{
    switch (element) {
    case RevenantMPSTextureElementUnorm8:
        return ((const uint8_t *)bytes)[index] / 255.0;
    case RevenantMPSTextureElementUnorm16:
        return ((const uint16_t *)bytes)[index] / 65535.0;
    case RevenantMPSTextureElementFloat16:
        return (double)RevenantMPSHalfToFloat(((const uint16_t *)bytes)[index]);
    case RevenantMPSTextureElementFloat32: {
        float value;
        memcpy(&value, (const unsigned char *)bytes + index * sizeof(float), sizeof(float));
        return (double)value;
    }
    }
    return 0.0;
}

static inline void RevenantMPSTextureStore(void *bytes, RevenantMPSTextureElement element, size_t index, double value)
{
    switch (element) {
    case RevenantMPSTextureElementUnorm8:
        ((uint8_t *)bytes)[index] = (uint8_t)lround(RevenantMPSTextureClampUnit(value) * 255.0);
        break;
    case RevenantMPSTextureElementUnorm16:
        ((uint16_t *)bytes)[index] = (uint16_t)lround(RevenantMPSTextureClampUnit(value) * 65535.0);
        break;
    case RevenantMPSTextureElementFloat16:
        ((uint16_t *)bytes)[index] = RevenantMPSFloatToHalf((float)value);
        break;
    case RevenantMPSTextureElementFloat32: {
        float stored = (float)value;
        memcpy((unsigned char *)bytes + index * sizeof(float), &stored, sizeof(float));
        break;
    }
    }
}

static inline MTLRegion RevenantMPSResolvedRegion(NSUInteger width, NSUInteger height, MTLRegion clip)
{
    NSInteger ox = (NSInteger)clip.origin.x, oy = (NSInteger)clip.origin.y;
    NSInteger sw = (NSInteger)clip.size.width, sh = (NSInteger)clip.size.height;
    if (ox < 0) ox = 0;
    if (oy < 0) oy = 0;
    if ((NSUInteger)ox > width) ox = (NSInteger)width;
    if ((NSUInteger)oy > height) oy = (NSInteger)height;
    NSUInteger right = width, bottom = height;
    if (sw > 0) {
        NSInteger end = ox + sw;
        if (end < (NSInteger)right) right = (NSUInteger)end;
    }
    if (sh > 0) {
        NSInteger end = oy + sh;
        if (end < (NSInteger)bottom) bottom = (NSUInteger)end;
    }
    if (right < (NSUInteger)ox) right = (NSUInteger)ox;
    if (bottom < (NSUInteger)oy) bottom = (NSUInteger)oy;
    return MTLRegionMake2D((NSUInteger)ox, (NSUInteger)oy, right - (NSUInteger)ox, bottom - (NSUInteger)oy);
}

static inline BOOL RevenantMPSTextureRead(id<MTLTexture> texture, NSUInteger level, NSUInteger width, NSUInteger height,
                                        NSUInteger channels, size_t elementSize, void *buffer)
{
    size_t stride = width * channels * elementSize;
    if (level >= texture.mipmapLevelCount)
        return NO;
    [texture getBytes:buffer bytesPerRow:stride fromRegion:MTLRegionMake2D(0, 0, width, height) mipmapLevel:level];
    return YES;
}

static inline BOOL RevenantMPSTextureWrite(id<MTLTexture> texture, NSUInteger level, NSUInteger width, NSUInteger height,
                                         NSUInteger channels, size_t elementSize, const void *buffer)
{
    size_t stride = width * channels * elementSize;
    if (level >= texture.mipmapLevelCount)
        return NO;
    [texture replaceRegion:MTLRegionMake2D(0, 0, width, height) mipmapLevel:level withBytes:buffer bytesPerRow:stride];
    return YES;
}

NS_ASSUME_NONNULL_END
