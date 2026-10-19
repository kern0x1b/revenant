#import "CharonVImageFixed.h"

#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wpointer-bool-conversion"
#pragma clang diagnostic ignored "-Wnonnull"

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
