#import "RevenantVImageFixed.h"

#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wpointer-bool-conversion"
#pragma clang diagnostic ignored "-Wnonnull"

vImage_Error vImageConvert_16Q12to16U(const vImage_Buffer *src, const vImage_Buffer *dest, vImage_Flags flags)
{
    vImage_Error ready = revenant_fixed_ready(src, dest, flags);
    if (ready != kvImageNoError)
        return ready;
    for (vImagePixelCount row = 0; row < dest->height; row++) {
        const uint8_t *in = (const uint8_t *)src->data + row * src->rowBytes;
        uint8_t *out = (uint8_t *)dest->data + row * dest->rowBytes;
        for (vImagePixelCount column = 0; column < dest->width; column++) {
            int16_t value;
            uint16_t answer;
            memcpy(&value, in + column * 2, sizeof value);
            answer = (uint16_t)revenant_sat((double)value * 65535.0 / 4096.0, 0, 65535);
            memcpy(out + column * 2, &answer, sizeof answer);
        }
    }
    return kvImageNoError;
}

vImage_Error vImageConvert_16Q12to8(const vImage_Buffer *src, const vImage_Buffer *dest, vImage_Flags flags)
{
    vImage_Error ready = revenant_fixed_ready(src, dest, flags);
    if (ready != kvImageNoError)
        return ready;
    for (vImagePixelCount row = 0; row < dest->height; row++) {
        const uint8_t *in = (const uint8_t *)src->data + row * src->rowBytes;
        uint8_t *out = (uint8_t *)dest->data + row * dest->rowBytes;
        for (vImagePixelCount column = 0; column < dest->width; column++) {
            int16_t value;
            memcpy(&value, in + column * 2, sizeof value);
            out[column] = (uint8_t)revenant_sat((double)value * 255.0 / 4096.0, 0, 255);
        }
    }
    return kvImageNoError;
}

vImage_Error vImageConvert_16Q12toF(const vImage_Buffer *src, const vImage_Buffer *dest, vImage_Flags flags)
{
    vImage_Error ready = revenant_fixed_ready(src, dest, flags);
    if (ready != kvImageNoError)
        return ready;
    for (vImagePixelCount row = 0; row < dest->height; row++) {
        const uint8_t *in = (const uint8_t *)src->data + row * src->rowBytes;
        uint8_t *out = (uint8_t *)dest->data + row * dest->rowBytes;
        for (vImagePixelCount column = 0; column < dest->width; column++) {
            int16_t value;
            float answer;
            memcpy(&value, in + column * 2, sizeof value);
            answer = (float)value / 4096.0f;
            memcpy(out + column * 4, &answer, sizeof answer);
        }
    }
    return kvImageNoError;
}

vImage_Error vImageConvert_Fto16Q12(const vImage_Buffer *src, const vImage_Buffer *dest, vImage_Flags flags)
{
    vImage_Error ready = revenant_fixed_ready(src, dest, flags);
    if (ready != kvImageNoError)
        return ready;
    for (vImagePixelCount row = 0; row < dest->height; row++) {
        const uint8_t *in = (const uint8_t *)src->data + row * src->rowBytes;
        uint8_t *out = (uint8_t *)dest->data + row * dest->rowBytes;
        for (vImagePixelCount column = 0; column < dest->width; column++) {
            float value;
            int16_t answer;
            memcpy(&value, in + column * 4, sizeof value);
            answer = (int16_t)revenant_sat((double)value * 4096.0, -32768, 32767);
            memcpy(out + column * 2, &answer, sizeof answer);
        }
    }
    return kvImageNoError;
}

vImage_Error vImageConvert_8to16Q12(const vImage_Buffer *src, const vImage_Buffer *dest, vImage_Flags flags)
{
    vImage_Error ready = revenant_fixed_ready(src, dest, flags);
    if (ready != kvImageNoError)
        return ready;
    for (vImagePixelCount row = 0; row < dest->height; row++) {
        const uint8_t *in = (const uint8_t *)src->data + row * src->rowBytes;
        uint8_t *out = (uint8_t *)dest->data + row * dest->rowBytes;
        for (vImagePixelCount column = 0; column < dest->width; column++) {
            int16_t answer = (int16_t)(((uint32_t)in[column] * 4096u + 127u) / 255u);
            memcpy(out + column * 2, &answer, sizeof answer);
        }
    }
    return kvImageNoError;
}

vImage_Error vImageConvert_16Uto16Q12(const vImage_Buffer *src, const vImage_Buffer *dest, vImage_Flags flags)
{
    vImage_Error ready = revenant_fixed_ready(src, dest, flags);
    if (ready != kvImageNoError)
        return ready;
    for (vImagePixelCount row = 0; row < dest->height; row++) {
        const uint8_t *in = (const uint8_t *)src->data + row * src->rowBytes;
        uint8_t *out = (uint8_t *)dest->data + row * dest->rowBytes;
        for (vImagePixelCount column = 0; column < dest->width; column++) {
            uint16_t value;
            int16_t answer;
            memcpy(&value, in + column * 2, sizeof value);
            answer = (int16_t)((value + 8u) >> 4);
            memcpy(out + column * 2, &answer, sizeof answer);
        }
    }
    return kvImageNoError;
}

vImage_Error vImageConvert_16Uto16F(const vImage_Buffer *src, const vImage_Buffer *dest, vImage_Flags flags)
{
    vImage_Error ready = revenant_fixed_ready(src, dest, flags);
    if (ready != kvImageNoError)
        return ready;
    for (vImagePixelCount row = 0; row < dest->height; row++) {
        const uint8_t *in = (const uint8_t *)src->data + row * src->rowBytes;
        uint8_t *out = (uint8_t *)dest->data + row * dest->rowBytes;
        for (vImagePixelCount column = 0; column < dest->width; column++) {
            uint16_t value, answer;
            memcpy(&value, in + column * 2, sizeof value);
            answer = revenant_float_to_half((float)value / 65535.0f);
            memcpy(out + column * 2, &answer, sizeof answer);
        }
    }
    return kvImageNoError;
}
