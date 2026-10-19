// The two scalar fixed-point conversions iOS 10.0 added: 16Fto16Q12 and 16Q12to16F. Measured from the
// release's armv7 caches, 10.3.4 is the first held release that exports the two and 8.0 names neither, so
// this file holds the API of exactly one release. The arithmetic is the header's, the same as the 7.0
// file's beside it, and both mappings come out of the same host table:
//
//   16F to 16Q12  round(half * 4096), clamped to -32768 .. 32767
//   16Q12 to 16F  the half nearest value / 4096

#import "CharonVImageFixed.h"

#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wpointer-bool-conversion"
#pragma clang diagnostic ignored "-Wnonnull"

// 1.0 is 4096 and 0.5 is 2048 in the host's table, an infinity is 32767 and a negative one -32768.
vImage_Error vImageConvert_16Fto16Q12(const vImage_Buffer *src, const vImage_Buffer *dest, vImage_Flags flags)
{
    vImage_Error ready = charon_fixed_ready(src, dest, flags);
    if (ready != kvImageNoError)
        return ready;
    for (vImagePixelCount row = 0; row < dest->height; row++) {
        const uint8_t *in = (const uint8_t *)src->data + row * src->rowBytes;
        uint8_t *out = (uint8_t *)dest->data + row * dest->rowBytes;
        for (vImagePixelCount column = 0; column < dest->width; column++) {
            uint16_t half;
            int16_t answer;
            memcpy(&half, in + column * 2, sizeof half);
            answer = (int16_t)charon_sat((double)charon_half_to_float(half) * 4096.0, -32768, 32767);
            memcpy(out + column * 2, &answer, sizeof answer);
        }
    }
    return kvImageNoError;
}

// 4096 is 0x3C00, which is 1.0 as a half, and 32767 is 0x4800, which is 8.0 - the largest the range reaches.
vImage_Error vImageConvert_16Q12to16F(const vImage_Buffer *src, const vImage_Buffer *dest, vImage_Flags flags)
{
    vImage_Error ready = charon_fixed_ready(src, dest, flags);
    if (ready != kvImageNoError)
        return ready;
    for (vImagePixelCount row = 0; row < dest->height; row++) {
        const uint8_t *in = (const uint8_t *)src->data + row * src->rowBytes;
        uint8_t *out = (uint8_t *)dest->data + row * dest->rowBytes;
        for (vImagePixelCount column = 0; column < dest->width; column++) {
            int16_t value;
            uint16_t answer;
            memcpy(&value, in + column * 2, sizeof value);
            answer = charon_float_to_half((float)value / 4096.0f);
            memcpy(out + column * 2, &answer, sizeof answer);
        }
    }
    return kvImageNoError;
}
