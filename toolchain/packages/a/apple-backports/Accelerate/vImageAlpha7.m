#import <Accelerate/Accelerate.h>
#include <string.h>

#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wpointer-bool-conversion"
#pragma clang diagnostic ignored "-Wnonnull"

#define CHARON_ALPHA_SLOT (-1)

static const vImage_Flags charon_alpha_flags = kvImageDoNotTile | kvImageGetTempBufferSize;

static const int charon_alpha_rgb_to[3][4] = {
    { CHARON_ALPHA_SLOT, 0, 1, 2 },
    { 0, 1, 2, CHARON_ALPHA_SLOT },
    { 2, 1, 0, CHARON_ALPHA_SLOT },
};

static const int charon_alpha_rgba_to_rgb[3] = { 0, 1, 2 };
static const int charon_alpha_bgra_to_rgb[3] = { 2, 1, 0 };

static vImage_Error charon_alpha_ready(const vImage_Buffer *src, const vImage_Buffer *dest, vImage_Flags flags)
{
    if (flags & ~charon_alpha_flags)
        return kvImageUnknownFlagsBit;
    if (flags & kvImageGetTempBufferSize)
        return 0;
    if (!src || !dest)
        return kvImageNullPointerArgument;
    if (src->width < dest->width || src->height < dest->height)
        return kvImageRoiLargerThanInputBuffer;
    return kvImageNoError;
}

static uint16_t charon_alpha16_at(const uint8_t *in, vImagePixelCount column, int channel, int channels)
{
    uint16_t value;
    memcpy(&value, in + (column * channels + channel) * 2, sizeof value);
    return value;
}

static uint16_t charon_alpha16_premultiply(uint16_t value, uint16_t alpha)
{
    return (uint16_t)(((uint32_t)value * alpha + 32767u) / 65535u);
}

static vImage_Error charon_alpha16_widen(const vImage_Buffer *src, const vImage_Buffer *aSrc, Pixel_16U fill,
                                         const vImage_Buffer *dest, bool premultiply, const int *order,
                                         int src_channels, vImage_Flags flags)
{
    vImage_Error ready = charon_alpha_ready(src, dest, flags);
    if (ready != kvImageNoError)
        return ready;
    for (vImagePixelCount row = 0; row < dest->height; row++) {
        const uint8_t *in = (const uint8_t *)src->data + row * src->rowBytes;
        const uint8_t *alpha_in = aSrc ? (const uint8_t *)aSrc->data + row * aSrc->rowBytes : NULL;
        uint8_t *out = (uint8_t *)dest->data + row * dest->rowBytes;
        for (vImagePixelCount column = 0; column < dest->width; column++) {
            uint16_t alpha;
            if (alpha_in) {
                memcpy(&alpha, alpha_in + column * 2, sizeof alpha);
            } else {
                alpha = fill;
            }
            for (int slot = 0; slot < 4; slot++) {
                uint16_t value = order[slot] == CHARON_ALPHA_SLOT
                    ? alpha
                    : charon_alpha16_at(in, column, order[slot], src_channels);
                if (premultiply && order[slot] != CHARON_ALPHA_SLOT)
                    value = charon_alpha16_premultiply(value, alpha);
                memcpy(out + (column * 4 + slot) * 2, &value, sizeof value);
            }
        }
    }
    return kvImageNoError;
}

static vImage_Error charon_alpha16_narrow(const vImage_Buffer *src, const vImage_Buffer *dest, const int *order,
                                          vImage_Flags flags)
{
    vImage_Error ready = charon_alpha_ready(src, dest, flags);
    if (ready != kvImageNoError)
        return ready;
    for (vImagePixelCount row = 0; row < dest->height; row++) {
        const uint8_t *in = (const uint8_t *)src->data + row * src->rowBytes;
        uint8_t *out = (uint8_t *)dest->data + row * dest->rowBytes;
        for (vImagePixelCount column = 0; column < dest->width; column++) {
            for (int slot = 0; slot < 3; slot++) {
                uint16_t value = charon_alpha16_at(in, column, order[slot], 4);
                memcpy(out + (column * 3 + slot) * 2, &value, sizeof value);
            }
        }
    }
    return kvImageNoError;
}

vImage_Error vImageConvert_RGB16UtoARGB16U(const vImage_Buffer *rgbSrc, const vImage_Buffer *aSrc, Pixel_16U alpha,
                                           const vImage_Buffer *argbDest, bool premultiply, vImage_Flags flags)
{
    return charon_alpha16_widen(rgbSrc, aSrc, alpha, argbDest, premultiply, charon_alpha_rgb_to[0], 3, flags);
}

vImage_Error vImageConvert_RGB16UtoRGBA16U(const vImage_Buffer *rgbSrc, const vImage_Buffer *aSrc, Pixel_16U alpha,
                                           const vImage_Buffer *rgbaDest, bool premultiply, vImage_Flags flags)
{
    return charon_alpha16_widen(rgbSrc, aSrc, alpha, rgbaDest, premultiply, charon_alpha_rgb_to[1], 3, flags);
}

vImage_Error vImageConvert_RGB16UtoBGRA16U(const vImage_Buffer *rgbSrc, const vImage_Buffer *aSrc, Pixel_16U alpha,
                                           const vImage_Buffer *bgraDest, bool premultiply, vImage_Flags flags)
{
    return charon_alpha16_widen(rgbSrc, aSrc, alpha, bgraDest, premultiply, charon_alpha_rgb_to[2], 3, flags);
}

vImage_Error vImageConvert_RGBA16UtoRGB16U(const vImage_Buffer *rgbaSrc, const vImage_Buffer *rgbDest, vImage_Flags flags)
{
    return charon_alpha16_narrow(rgbaSrc, rgbDest, charon_alpha_rgba_to_rgb, flags);
}

vImage_Error vImageConvert_BGRA16UtoRGB16U(const vImage_Buffer *bgraSrc, const vImage_Buffer *rgbDest, vImage_Flags flags)
{
    return charon_alpha16_narrow(bgraSrc, rgbDest, charon_alpha_bgra_to_rgb, flags);
}
