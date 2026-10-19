#import <Accelerate/Accelerate.h>
#include <string.h>

#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wpointer-bool-conversion"
#pragma clang diagnostic ignored "-Wnonnull"

static const vImage_Flags revenant_pixel_flags = kvImageDoNotTile | kvImageGetTempBufferSize | kvImagePrintDiagnosticsToConsole;
static const vImage_Flags revenant_drop_flags = kvImageDoNotTile | kvImagePrintDiagnosticsToConsole;

static vImage_Error revenant_pixel_ready(const vImage_Buffer *src, const vImage_Buffer *dest, vImage_Flags flags,
                                       vImage_Flags allowed, vImage_Error tooSmall)
{
    if (flags & ~allowed)
        return kvImageUnknownFlagsBit;
    if (flags & kvImageGetTempBufferSize)
        return 0;
    if (!src || !dest)
        return kvImageNullPointerArgument;
    if (src->width < dest->width || src->height < dest->height)
        return tooSmall;
    return kvImageNoError;
}

vImage_Error vImageConvert_RGB565toBGRA8888(Pixel_8 alpha, const vImage_Buffer *src, const vImage_Buffer *dest,
                                            vImage_Flags flags)
{
    vImage_Error ready = revenant_pixel_ready(src, dest, flags, revenant_pixel_flags, kvImageRoiLargerThanInputBuffer);
    if (ready != kvImageNoError)
        return ready;
    for (vImagePixelCount row = 0; row < dest->height; row++) {
        const uint8_t *in = (const uint8_t *)src->data + row * src->rowBytes;
        uint8_t *out = (uint8_t *)dest->data + row * dest->rowBytes;
        for (vImagePixelCount column = 0; column < dest->width; column++) {
            uint16_t packed;
            memcpy(&packed, in + column * 2, sizeof packed);
            uint32_t red = (packed >> 11) & 0x1F, green = (packed >> 5) & 0x3F, blue = packed & 0x1F;
            out[column * 4 + 0] = (uint8_t)((blue * 255 + 15) / 31);
            out[column * 4 + 1] = (uint8_t)((green * 255 + 31) / 63);
            out[column * 4 + 2] = (uint8_t)((red * 255 + 15) / 31);
            out[column * 4 + 3] = alpha;
        }
    }
    return kvImageNoError;
}

static uint8_t revenant_expand5(uint32_t value) { return (uint8_t)((value * 255 + 15) / 31); }
static uint8_t revenant_expand6(uint32_t value) { return (uint8_t)((value * 255 + 31) / 63); }
static uint32_t revenant_narrow5(uint32_t value) { return (value * 31 + 127) / 255; }
static uint32_t revenant_narrow6(uint32_t value) { return (value * 63 + 127) / 255; }

vImage_Error vImageConvert_RGB565toRGBA8888(Pixel_8 alpha, const vImage_Buffer *src, const vImage_Buffer *dest,
                                            vImage_Flags flags)
{
    vImage_Error ready = revenant_pixel_ready(src, dest, flags, revenant_pixel_flags, kvImageRoiLargerThanInputBuffer);
    if (ready != kvImageNoError)
        return ready;
    for (vImagePixelCount row = 0; row < dest->height; row++) {
        const uint8_t *in = (const uint8_t *)src->data + row * src->rowBytes;
        uint8_t *out = (uint8_t *)dest->data + row * dest->rowBytes;
        for (vImagePixelCount column = 0; column < dest->width; column++) {
            uint16_t packed;
            memcpy(&packed, in + column * 2, sizeof packed);
            out[column * 4 + 0] = revenant_expand5((packed >> 11) & 0x1F);
            out[column * 4 + 1] = revenant_expand6((packed >> 5) & 0x3F);
            out[column * 4 + 2] = revenant_expand5(packed & 0x1F);
            out[column * 4 + 3] = alpha;
        }
    }
    return kvImageNoError;
}

vImage_Error vImageConvert_RGBA5551toRGBA8888(const vImage_Buffer *src, const vImage_Buffer *dest, vImage_Flags flags)
{
    vImage_Error ready = revenant_pixel_ready(src, dest, flags, revenant_pixel_flags, kvImageRoiLargerThanInputBuffer);
    if (ready != kvImageNoError)
        return ready;
    for (vImagePixelCount row = 0; row < dest->height; row++) {
        const uint8_t *in = (const uint8_t *)src->data + row * src->rowBytes;
        uint8_t *out = (uint8_t *)dest->data + row * dest->rowBytes;
        for (vImagePixelCount column = 0; column < dest->width; column++) {
            uint16_t packed;
            memcpy(&packed, in + column * 2, sizeof packed);
            out[column * 4 + 0] = revenant_expand5((packed >> 11) & 0x1F);
            out[column * 4 + 1] = revenant_expand5((packed >> 6) & 0x1F);
            out[column * 4 + 2] = revenant_expand5((packed >> 1) & 0x1F);
            out[column * 4 + 3] = (packed & 1) ? 255 : 0;
        }
    }
    return kvImageNoError;
}

vImage_Error vImageConvert_RGBA8888toRGB565(const vImage_Buffer *src, const vImage_Buffer *dest, vImage_Flags flags)
{
    vImage_Error ready = revenant_pixel_ready(src, dest, flags, revenant_pixel_flags, kvImageRoiLargerThanInputBuffer);
    if (ready != kvImageNoError)
        return ready;
    for (vImagePixelCount row = 0; row < dest->height; row++) {
        const uint8_t *in = (const uint8_t *)src->data + row * src->rowBytes;
        uint8_t *out = (uint8_t *)dest->data + row * dest->rowBytes;
        for (vImagePixelCount column = 0; column < dest->width; column++) {
            uint16_t packed = (uint16_t)((revenant_narrow5(in[column * 4 + 0]) << 11) |
                                         (revenant_narrow6(in[column * 4 + 1]) << 5) | revenant_narrow5(in[column * 4 + 2]));
            memcpy(out + column * 2, &packed, sizeof packed);
        }
    }
    return kvImageNoError;
}

vImage_Error vImageConvert_RGBA8888toRGBA5551(const vImage_Buffer *src, const vImage_Buffer *dest, vImage_Flags flags)
{
    vImage_Error ready = revenant_pixel_ready(src, dest, flags, revenant_pixel_flags, kvImageRoiLargerThanInputBuffer);
    if (ready != kvImageNoError)
        return ready;
    for (vImagePixelCount row = 0; row < dest->height; row++) {
        const uint8_t *in = (const uint8_t *)src->data + row * src->rowBytes;
        uint8_t *out = (uint8_t *)dest->data + row * dest->rowBytes;
        for (vImagePixelCount column = 0; column < dest->width; column++) {
            uint16_t packed = (uint16_t)((revenant_narrow5(in[column * 4 + 0]) << 11) |
                                         (revenant_narrow5(in[column * 4 + 1]) << 6) | (revenant_narrow5(in[column * 4 + 2]) << 1) |
                                         ((in[column * 4 + 3] + 127) / 255));
            memcpy(out + column * 2, &packed, sizeof packed);
        }
    }
    return kvImageNoError;
}

vImage_Error vImageConvert_BGRA8888toRGB565(const vImage_Buffer *src, const vImage_Buffer *dest, vImage_Flags flags)
{
    vImage_Error ready = revenant_pixel_ready(src, dest, flags, revenant_pixel_flags, kvImageRoiLargerThanInputBuffer);
    if (ready != kvImageNoError)
        return ready;
    for (vImagePixelCount row = 0; row < dest->height; row++) {
        const uint8_t *in = (const uint8_t *)src->data + row * src->rowBytes;
        uint8_t *out = (uint8_t *)dest->data + row * dest->rowBytes;
        for (vImagePixelCount column = 0; column < dest->width; column++) {
            uint32_t blue = in[column * 4 + 0], green = in[column * 4 + 1], red = in[column * 4 + 2];
            uint16_t packed = (uint16_t)((((red * 31 + 127) / 255) << 11) | (((green * 63 + 127) / 255) << 5)
                                         | ((blue * 31 + 127) / 255));
            memcpy(out + column * 2, &packed, sizeof packed);
        }
    }
    return kvImageNoError;
}

vImage_Error vImageConvert_ARGB16UtoRGB16U(const vImage_Buffer *argbSrc, const vImage_Buffer *rgbDest, vImage_Flags flags)
{
    vImage_Error ready = revenant_pixel_ready(argbSrc, rgbDest, flags, revenant_drop_flags, kvImageRoiLargerThanInputBuffer);
    if (ready != kvImageNoError)
        return ready;
    for (vImagePixelCount row = 0; row < rgbDest->height; row++) {
        const uint8_t *in = (const uint8_t *)argbSrc->data + row * argbSrc->rowBytes;
        uint8_t *out = (uint8_t *)rgbDest->data + row * rgbDest->rowBytes;
        for (vImagePixelCount column = 0; column < rgbDest->width; column++)
            memmove(out + column * 6, in + column * 8 + 2, 6);
    }
    return kvImageNoError;
}

vImage_Error vImageConvert_ARGBFFFFtoRGBFFF(const vImage_Buffer *src, const vImage_Buffer *dest, vImage_Flags flags)
{
    vImage_Error ready = revenant_pixel_ready(src, dest, flags, revenant_drop_flags, kvImageRoiLargerThanInputBuffer);
    if (ready != kvImageNoError)
        return ready;
    for (vImagePixelCount row = 0; row < dest->height; row++) {
        const uint8_t *in = (const uint8_t *)src->data + row * src->rowBytes;
        uint8_t *out = (uint8_t *)dest->data + row * dest->rowBytes;
        for (vImagePixelCount column = 0; column < dest->width; column++)
            memmove(out + column * 12, in + column * 16 + 4, 12);
    }
    return kvImageNoError;
}
