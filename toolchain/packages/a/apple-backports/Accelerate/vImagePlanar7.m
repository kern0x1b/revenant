#import "CharonVImageFixed.h"

#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wpointer-bool-conversion"
#pragma clang diagnostic ignored "-Wnonnull"

static inline int16_t charon_8_to_q12(uint8_t value) { return (int16_t)(((uint32_t)value * 4096u + 127u) / 255u); }

static inline uint8_t charon_q12_to_8(int16_t value) { return (uint8_t)charon_sat((double)value * 255.0 / 4096.0, 0, 255); }

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
