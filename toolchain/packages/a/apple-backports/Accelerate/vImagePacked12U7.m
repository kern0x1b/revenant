#import <Accelerate/Accelerate.h>
#include <string.h>

#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wpointer-bool-conversion"
#pragma clang diagnostic ignored "-Wnonnull"

static const vImage_Flags charon_packed_flags = kvImageDoNotTile | kvImageGetTempBufferSize;

static vImage_Error charon_packed_ready(const vImage_Buffer *src, const vImage_Buffer *dest, vImage_Flags flags)
{
    if (flags & ~charon_packed_flags)
        return kvImageUnknownFlagsBit;
    if (flags & kvImageGetTempBufferSize)
        return 0;
    if (!src || !dest)
        return kvImageNullPointerArgument;
    if (src->width < dest->width || src->height < dest->height)
        return kvImageRoiLargerThanInputBuffer;
    return kvImageNoError;
}

static size_t charon_packed_row_bytes(vImagePixelCount width)
{
    return (size_t)((width + 1) / 2 * 3);
}

static uint16_t charon_packed12_at(const uint8_t *row, vImagePixelCount column)
{
    const uint8_t *triple = row + (size_t)(column / 2) * 3;
    unsigned high = (unsigned)triple[0] << 16 | (unsigned)triple[1] << 8 | triple[2];
    unsigned value = column % 2 ? high & 0xfffu : (high >> 12) & 0xfffu;
    return (uint16_t)value;
}

static void charon_packed12_put(uint8_t *row, vImagePixelCount column, uint16_t value)
{
    uint8_t *triple = row + (size_t)(column / 2) * 3;
    unsigned pair = (unsigned)triple[0] << 16 | (unsigned)triple[1] << 8 | triple[2];
    pair = column % 2 ? ((pair & 0xfff000u) | (value & 0xfffu))
                      : ((pair & 0x000fffu) | (((unsigned)value & 0xfffu) << 12));
    triple[0] = (uint8_t)(pair >> 16);
    triple[1] = (uint8_t)(pair >> 8);
    triple[2] = (uint8_t)pair;
}

vImage_Error vImageConvert_12UTo16U(const vImage_Buffer *src, const vImage_Buffer *dest, vImage_Flags flags)
{
    vImage_Error ready = charon_packed_ready(src, dest, flags);
    if (ready != kvImageNoError)
        return ready;
    for (vImagePixelCount row = 0; row < dest->height; row++) {
        const uint8_t *in = (const uint8_t *)src->data + row * src->rowBytes;
        uint8_t *out = (uint8_t *)dest->data + row * dest->rowBytes;
        for (vImagePixelCount column = 0; column < dest->width; column++) {
            uint32_t t = charon_packed12_at(in, column);
            uint16_t value = (uint16_t)((t * 65535u + (t << 4) + 2055u) >> 12);
            memcpy(out + column * 2, &value, sizeof value);
        }
    }
    return kvImageNoError;
}

vImage_Error vImageConvert_16UTo12U(const vImage_Buffer *src, const vImage_Buffer *dest, vImage_Flags flags)
{
    vImage_Error ready = charon_packed_ready(src, dest, flags);
    if (ready != kvImageNoError)
        return ready;
    for (vImagePixelCount row = 0; row < dest->height; row++) {
        const uint8_t *in = (const uint8_t *)src->data + row * src->rowBytes;
        uint8_t *out = (uint8_t *)dest->data + row * dest->rowBytes;
        for (vImagePixelCount column = 0; column < dest->width; column++) {
            uint16_t raw;
            memcpy(&raw, in + column * 2, sizeof raw);
            uint32_t t = raw;
            charon_packed12_put(out, column, (uint16_t)((t * 4095u + 32767u + (t >> 4)) >> 16));
        }
    }
    return kvImageNoError;
}
