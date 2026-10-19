// The 5/6/5 and 1/5/5/5 conversions of iOS 8.0, and the 5/5/5/1 spellings of the same two words.
//
// Measured from the release's armv7 caches, 8.0 is the first held release that exports the five and 7.1.2
// names none of them, so this file holds the API of exactly one release.
//
// Conversion.h gives the arithmetic of the two words on its own - expand a channel up to eight bits with
// (bits * 255 + half) / max and narrow one down with (bits * max + 127) / 255, and a one-bit alpha is that
// bit times 255 up and (bits + 127) / 255 down - and for the two conversions *between* a 5/6/5 word and a
// 1/5/5/5 or 5/5/5/1 word it says only "first at high bitdepth, then convert to lower bitdepth". That is
// what the three below are, and the composition is not a bit shift: the green of a 5/6/5 word is six bits
// and of a 1/5/5/5 or 5/5/5/1 word five, so the green goes up through a five-bit expansion and down
// through a six-bit narrowing, or the other way round. The host's answers are what the composition is
// measured against, case by case, in tests/backports/host/vimagepixels
// (facts/Accelerate/vImagePixels.md).

#import <Accelerate/Accelerate.h>
#include <string.h>

#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wpointer-bool-conversion"
#pragma clang diagnostic ignored "-Wnonnull"

static const vImage_Flags charon_pixels8_flags = kvImageDoNotTile | kvImageGetTempBufferSize | kvImagePrintDiagnosticsToConsole;

// The same checks the 7.0 file makes, and the same answers: a flag outside the set the header lists is
// kvImageUnknownFlagsBit, GetTempBufferSize does no work and answers zero, a NULL buffer is
// kvImageNullPointerArgument, and a destination larger than the source is
// kvImageRoiLargerThanInputBuffer, which is what the release answers although the header's comment above
// the 565 expansion names another code.
static vImage_Error charon_pixels8_ready(const vImage_Buffer *src, const vImage_Buffer *dest, vImage_Flags flags)
{
    if (flags & ~charon_pixels8_flags)
        return kvImageUnknownFlagsBit;
    if (flags & kvImageGetTempBufferSize)
        return 0;
    if (!src || !dest)
        return kvImageNullPointerArgument;
    if (src->width < dest->width || src->height < dest->height)
        return kvImageRoiLargerThanInputBuffer;
    return kvImageNoError;
}

static uint8_t charon_up5(uint32_t value) { return (uint8_t)((value * 255 + 15) / 31); }
static uint8_t charon_up6(uint32_t value) { return (uint8_t)((value * 255 + 31) / 63); }
static uint32_t charon_down5(uint32_t value) { return (value * 31 + 127) / 255; }
static uint32_t charon_down6(uint32_t value) { return (value * 63 + 127) / 255; }

vImage_Error vImageConvert_RGB565toRGB888(const vImage_Buffer *src, const vImage_Buffer *dest, vImage_Flags flags)
{
    vImage_Error ready = charon_pixels8_ready(src, dest, flags);
    if (ready != kvImageNoError)
        return ready;
    for (vImagePixelCount row = 0; row < dest->height; row++) {
        const uint8_t *in = (const uint8_t *)src->data + row * src->rowBytes;
        uint8_t *out = (uint8_t *)dest->data + row * dest->rowBytes;
        for (vImagePixelCount column = 0; column < dest->width; column++) {
            uint16_t packed;
            memcpy(&packed, in + column * 2, sizeof packed);
            out[column * 3 + 0] = charon_up5((packed >> 11) & 0x1F);
            out[column * 3 + 1] = charon_up6((packed >> 5) & 0x3F);
            out[column * 3 + 2] = charon_up5(packed & 0x1F);
        }
    }
    return kvImageNoError;
}

vImage_Error vImageConvert_RGB565toARGB1555(const vImage_Buffer *src, const vImage_Buffer *dest, int dither,
                                               vImage_Flags flags)
{
    vImage_Error ready = charon_pixels8_ready(src, dest, flags);
    // The dither the header gives this call is recorded and not used: a dither of zero is the answer the
    // facts file measures against the host, and the host's own dither is a noise source no header
    // publishes (facts/Accelerate/vImagePixels.md).
    (void)dither;
    if (ready != kvImageNoError)
        return ready;
    for (vImagePixelCount row = 0; row < dest->height; row++) {
        const uint8_t *in = (const uint8_t *)src->data + row * src->rowBytes;
        uint8_t *out = (uint8_t *)dest->data + row * dest->rowBytes;
        for (vImagePixelCount column = 0; column < dest->width; column++) {
            uint16_t packed;
            uint16_t argb;
            memcpy(&packed, in + column * 2, sizeof packed);
            argb = (uint16_t)((1u << 15) | (charon_down5(charon_up5((packed >> 11) & 0x1F)) << 10) |
                              (charon_down5(charon_up6((packed >> 5) & 0x3F)) << 5) | charon_down5(charon_up5(packed & 0x1F)));
            memcpy(out + column * 2, &argb, sizeof argb);
        }
    }
    return kvImageNoError;
}

vImage_Error vImageConvert_ARGB1555toRGB565(const vImage_Buffer *src, const vImage_Buffer *dest, vImage_Flags flags)
{
    vImage_Error ready = charon_pixels8_ready(src, dest, flags);
    if (ready != kvImageNoError)
        return ready;
    for (vImagePixelCount row = 0; row < dest->height; row++) {
        const uint8_t *in = (const uint8_t *)src->data + row * src->rowBytes;
        uint8_t *out = (uint8_t *)dest->data + row * dest->rowBytes;
        for (vImagePixelCount column = 0; column < dest->width; column++) {
            uint16_t argb;
            uint16_t rgb;
            memcpy(&argb, in + column * 2, sizeof argb);
            rgb = (uint16_t)((charon_down5(charon_up5((argb >> 10) & 0x1F)) << 11) |
                             (charon_down6(charon_up5((argb >> 5) & 0x1F)) << 5) | charon_down5(charon_up5(argb & 0x1F)));
            memcpy(out + column * 2, &rgb, sizeof rgb);
        }
    }
    return kvImageNoError;
}

vImage_Error vImageConvert_RGB565toRGBA5551(const vImage_Buffer *src, const vImage_Buffer *dest, int dither,
                                                vImage_Flags flags)
{
    vImage_Error ready = charon_pixels8_ready(src, dest, flags);
    (void)dither;   // the header's dither, recorded and not used: see vImageConvert_RGB565toARGB1555 above
    if (ready != kvImageNoError)
        return ready;
    for (vImagePixelCount row = 0; row < dest->height; row++) {
        const uint8_t *in = (const uint8_t *)src->data + row * src->rowBytes;
        uint8_t *out = (uint8_t *)dest->data + row * dest->rowBytes;
        for (vImagePixelCount column = 0; column < dest->width; column++) {
            uint16_t packed;
            uint16_t rgba;
            memcpy(&packed, in + column * 2, sizeof packed);
            rgba = (uint16_t)((charon_down5(charon_up5((packed >> 11) & 0x1F)) << 11) |
                              (charon_down5(charon_up6((packed >> 5) & 0x3F)) << 6) |
                              (charon_down5(charon_up5(packed & 0x1F)) << 1) | 1u);
            memcpy(out + column * 2, &rgba, sizeof rgba);
        }
    }
    return kvImageNoError;
}

vImage_Error vImageConvert_RGBA5551toRGB565(const vImage_Buffer *src, const vImage_Buffer *dest, vImage_Flags flags)
{
    vImage_Error ready = charon_pixels8_ready(src, dest, flags);
    if (ready != kvImageNoError)
        return ready;
    for (vImagePixelCount row = 0; row < dest->height; row++) {
        const uint8_t *in = (const uint8_t *)src->data + row * src->rowBytes;
        uint8_t *out = (uint8_t *)dest->data + row * dest->rowBytes;
        for (vImagePixelCount column = 0; column < dest->width; column++) {
            uint16_t rgba;
            uint16_t rgb;
            memcpy(&rgba, in + column * 2, sizeof rgba);
            rgb = (uint16_t)((charon_down5(charon_up5((rgba >> 11) & 0x1F)) << 11) |
                             (charon_down6(charon_up5((rgba >> 6) & 0x1F)) << 5) | charon_down5(charon_up5((rgba >> 1) & 0x1F)));
            memcpy(out + column * 2, &rgb, sizeof rgb);
        }
    }
    return kvImageNoError;
}
