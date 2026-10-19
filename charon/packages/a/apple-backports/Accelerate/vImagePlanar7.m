// The interleaved-to-planar and planar-to-interleaved moves of iOS 7.0: eight conversions whose only work is
// where each channel lands, four of them between two sixteen-bit forms and four between an eight-bit one and
// 16Q12.
//
// Measured from the release's armv7 caches, 7.0 is the first held release that exports the eight, so this file
// holds the API of exactly one release.
//
// The formats and the two scalings are the ones the fixed-point group measured, and the facts file there
// carries the numbers: Pixel_16U is sixteen bits unsigned, 8 is eight bits unsigned, and 16Q12 is sixteen bits
// signed with twelve fractional bits. 8 to 16Q12 is `(value * 4096 + 127) / 255` in integer arithmetic and
// 16Q12 to 8 is `round(value / 4096 * 255)` clamped, both read off the host's own answers.
//
// What is left here is the layout, and the header's argument order names the channels: alpha first where
// there is one, and the destinations are in that order too.

#import "CharonVImageFixed.h"

#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wpointer-bool-conversion"
#pragma clang diagnostic ignored "-Wnonnull"

// 8 to 16Q12 and 16Q12 to 8, the two scalings this file shares with the fixed-point group. They are static
// here rather than shared, because the fixed-point group is a file of its own and a C function defined in a
// file that exports API symbols is left out of the bands that already have those symbols - so the two rules
// are written again here rather than called across.
static inline int16_t charon_8_to_q12(uint8_t value) { return (int16_t)(((uint32_t)value * 4096u + 127u) / 255u); }

static inline uint8_t charon_q12_to_8(int16_t value) { return (uint8_t)charon_sat((double)value * 255.0 / 4096.0, 0, 255); }

// One row of the caller's own two-byte values, read with the interleaved stride and written to as many
// destinations as there are channels.
static void charon_spread16(const vImage_Buffer *src, const vImage_Buffer *const *dests, vImagePixelCount channels)
{
    for (vImagePixelCount row = 0; row < src->height; row++) {
        const uint8_t *in = (const uint8_t *)src->data + row * src->rowBytes;
        for (vImagePixelCount channel = 0; channel < channels; channel++) {
            uint8_t *out = (uint8_t *)dests[channel]->data + row * dests[channel]->rowBytes;
            for (vImagePixelCount column = 0; column < src->width; column++) {
                uint16_t value;
                memcpy(&value, in + (column * channels + channel) * 2, sizeof value);
                memcpy(out + column * 2, &value, sizeof value);
            }
        }
    }
}

// And the other way: as many sources of two-byte values into one interleaved row.
static void charon_gather16(const vImage_Buffer *const *srcs, const vImage_Buffer *dest, vImagePixelCount channels)
{
    for (vImagePixelCount row = 0; row < dest->height; row++) {
        uint8_t *out = (uint8_t *)dest->data + row * dest->rowBytes;
        for (vImagePixelCount channel = 0; channel < channels; channel++) {
            const uint8_t *in = (const uint8_t *)srcs[channel]->data + row * srcs[channel]->rowBytes;
            for (vImagePixelCount column = 0; column < dest->width; column++) {
                uint16_t value;
                memcpy(&value, in + column * 2, sizeof value);
                memcpy(out + (column * channels + channel) * 2, &value, sizeof value);
            }
        }
    }
}

// The eight-bit source into 16Q12 destinations, which is the same spread with the scaling.
static void charon_spread8_to_q12(const vImage_Buffer *src, const vImage_Buffer *const *dests, vImagePixelCount channels)
{
    for (vImagePixelCount row = 0; row < src->height; row++) {
        const uint8_t *in = (const uint8_t *)src->data + row * src->rowBytes;
        for (vImagePixelCount channel = 0; channel < channels; channel++) {
            uint8_t *out = (uint8_t *)dests[channel]->data + row * dests[channel]->rowBytes;
            for (vImagePixelCount column = 0; column < src->width; column++) {
                int16_t value = charon_8_to_q12(in[column * channels + channel]);
                memcpy(out + column * 2, &value, sizeof value);
            }
        }
    }
}

// And 16Q12 sources into one interleaved eight-bit row.
static void charon_gather_q12_to_8(const vImage_Buffer *const *srcs, const vImage_Buffer *dest, vImagePixelCount channels)
{
    for (vImagePixelCount row = 0; row < dest->height; row++) {
        uint8_t *out = (uint8_t *)dest->data + row * dest->rowBytes;
        for (vImagePixelCount channel = 0; channel < channels; channel++) {
            const uint8_t *in = (const uint8_t *)srcs[channel]->data + row * srcs[channel]->rowBytes;
            for (vImagePixelCount column = 0; column < dest->width; column++) {
                int16_t value;
                memcpy(&value, in + column * 2, sizeof value);
                out[column * channels + channel] = charon_q12_to_8(value);
            }
        }
    }
}

vImage_Error vImageConvert_ARGB16UtoPlanar16U(const vImage_Buffer *argbSrc, const vImage_Buffer *aDest,
                                             const vImage_Buffer *rDest, const vImage_Buffer *gDest,
                                             const vImage_Buffer *bDest, vImage_Flags flags)
{
    vImage_Error ready = charon_fixed_ready(argbSrc, aDest, flags);
    if (ready != kvImageNoError)
        return ready;
    {
        const vImage_Buffer *dests[4] = {aDest, rDest, gDest, bDest};
        charon_spread16(argbSrc, dests, 4);
    }
    return kvImageNoError;
}

vImage_Error vImageConvert_RGB16UtoPlanar16U(const vImage_Buffer *rgbSrc, const vImage_Buffer *rDest,
                                            const vImage_Buffer *gDest, const vImage_Buffer *bDest, vImage_Flags flags)
{
    vImage_Error ready = charon_fixed_ready(rgbSrc, rDest, flags);
    if (ready != kvImageNoError)
        return ready;
    {
        const vImage_Buffer *dests[3] = {rDest, gDest, bDest};
        charon_spread16(rgbSrc, dests, 3);
    }
    return kvImageNoError;
}

vImage_Error vImageConvert_Planar16UtoARGB16U(const vImage_Buffer *aSrc, const vImage_Buffer *rSrc,
                                              const vImage_Buffer *gSrc, const vImage_Buffer *bSrc,
                                              const vImage_Buffer *argbDest, vImage_Flags flags)
{
    vImage_Error ready = charon_fixed_ready(aSrc, argbDest, flags);
    if (ready != kvImageNoError)
        return ready;
    {
        const vImage_Buffer *srcs[4] = {aSrc, rSrc, gSrc, bSrc};
        charon_gather16(srcs, argbDest, 4);
    }
    return kvImageNoError;
}

vImage_Error vImageConvert_Planar16UtoRGB16U(const vImage_Buffer *rSrc, const vImage_Buffer *gSrc,
                                             const vImage_Buffer *bSrc, const vImage_Buffer *rgbDest, vImage_Flags flags)
{
    vImage_Error ready = charon_fixed_ready(rSrc, rgbDest, flags);
    if (ready != kvImageNoError)
        return ready;
    {
        const vImage_Buffer *srcs[3] = {rSrc, gSrc, bSrc};
        charon_gather16(srcs, rgbDest, 3);
    }
    return kvImageNoError;
}

vImage_Error vImageConvert_ARGB8888toPlanar16Q12(const vImage_Buffer *src, const vImage_Buffer *alpha,
                                                 const vImage_Buffer *red, const vImage_Buffer *green,
                                                 const vImage_Buffer *blue, vImage_Flags flags)
{
    vImage_Error ready = charon_fixed_ready(src, red, flags);
    if (ready != kvImageNoError)
        return ready;
    {
        const vImage_Buffer *dests[4] = {alpha, red, green, blue};
        charon_spread8_to_q12(src, dests, 4);
    }
    return kvImageNoError;
}

vImage_Error vImageConvert_RGB888toPlanar16Q12(const vImage_Buffer *src, const vImage_Buffer *red,
                                                const vImage_Buffer *green, const vImage_Buffer *blue,
                                                vImage_Flags flags)
{
    vImage_Error ready = charon_fixed_ready(src, red, flags);
    if (ready != kvImageNoError)
        return ready;
    {
        const vImage_Buffer *dests[3] = {red, green, blue};
        charon_spread8_to_q12(src, dests, 3);
    }
    return kvImageNoError;
}

vImage_Error vImageConvert_Planar16Q12toARGB8888(const vImage_Buffer *alpha, const vImage_Buffer *red,
                                                  const vImage_Buffer *green, const vImage_Buffer *blue,
                                                  const vImage_Buffer *dest, vImage_Flags flags)
{
    vImage_Error ready = charon_fixed_ready(red, dest, flags);
    if (ready != kvImageNoError)
        return ready;
    {
        const vImage_Buffer *srcs[4] = {alpha, red, green, blue};
        charon_gather_q12_to_8(srcs, dest, 4);
    }
    return kvImageNoError;
}

vImage_Error vImageConvert_Planar16Q12toRGB888(const vImage_Buffer *red, const vImage_Buffer *green,
                                                const vImage_Buffer *blue, const vImage_Buffer *dest, vImage_Flags flags)
{
    vImage_Error ready = charon_fixed_ready(red, dest, flags);
    if (ready != kvImageNoError)
        return ready;
    {
        const vImage_Buffer *srcs[3] = {red, green, blue};
        charon_gather_q12_to_8(srcs, dest, 3);
    }
    return kvImageNoError;
}
