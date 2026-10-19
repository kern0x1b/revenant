#import <Accelerate/Accelerate.h>
#include <string.h>

#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wpointer-bool-conversion"
#pragma clang diagnostic ignored "-Wnonnull"

static const vImage_Flags charon_subbyte_flags = kvImageDoNotTile | kvImageGetTempBufferSize | kvImagePrintDiagnosticsToConsole;

static vImage_Error charon_subbyte_ready(const vImage_Buffer *src, const vImage_Buffer *dest, vImage_Flags flags)
{
    if (flags & ~charon_subbyte_flags)
        return kvImageUnknownFlagsBit;
    if (flags & kvImageGetTempBufferSize)
        return 0;
    if (!src || !dest)
        return kvImageNullPointerArgument;
    if (src->width < dest->width || src->height < dest->height)
        return kvImageRoiLargerThanInputBuffer;
    return kvImageNoError;
}


static unsigned char charon_subbyte_at(const uint8_t *row, vImagePixelCount column, int bits)
{
    int per_byte = 8 / bits;
    unsigned char byte = row[column / per_byte];
    int shift = 8 - bits - (column % per_byte) * bits;
    return (unsigned char)((byte >> shift) & (unsigned char)((1 << bits) - 1));
}


static void charon_subbyte_expand_row(const uint8_t *in, uint8_t *out, vImagePixelCount width, int bits)
{
    int scale = 255 / ((1 << bits) - 1);
    for (vImagePixelCount column = 0; column < width; column++) {
        out[column] = (uint8_t)(charon_subbyte_at(in, column, bits) * scale);
    }
}


vImage_Error vImageConvert_Planar1toPlanar8(const vImage_Buffer *src, const vImage_Buffer *dest, vImage_Flags flags)
{
    vImage_Error ready = charon_subbyte_ready(src, dest, flags);
    if (ready != kvImageNoError)
        return ready;
    for (vImagePixelCount row = 0; row < dest->height; row++) {
        charon_subbyte_expand_row((const uint8_t *)src->data + row * src->rowBytes, (uint8_t *)dest->data + row * dest->rowBytes,
                                  dest->width, 1);
    }
    return kvImageNoError;
}





vImage_Error vImageConvert_Planar2toPlanar8(const vImage_Buffer *src, const vImage_Buffer *dest, vImage_Flags flags)
{
    vImage_Error ready = charon_subbyte_ready(src, dest, flags);
    if (ready != kvImageNoError)
        return ready;
    for (vImagePixelCount row = 0; row < dest->height; row++) {
        charon_subbyte_expand_row((const uint8_t *)src->data + row * src->rowBytes, (uint8_t *)dest->data + row * dest->rowBytes,
                                  dest->width, 2);
    }
    return kvImageNoError;
}

vImage_Error vImageConvert_Planar4toPlanar8(const vImage_Buffer *src, const vImage_Buffer *dest, vImage_Flags flags)
{
    vImage_Error ready = charon_subbyte_ready(src, dest, flags);
    if (ready != kvImageNoError)
        return ready;
    for (vImagePixelCount row = 0; row < dest->height; row++) {
        charon_subbyte_expand_row((const uint8_t *)src->data + row * src->rowBytes, (uint8_t *)dest->data + row * dest->rowBytes,
                                  dest->width, 4);
    }
    return kvImageNoError;
}

vImage_Error vImageConvert_Indexed1toPlanar8(const vImage_Buffer *src, const vImage_Buffer *dest, const Pixel_8 colors[2],
                                            vImage_Flags flags)
{
    vImage_Error ready = charon_subbyte_ready(src, dest, flags);
    if (ready != kvImageNoError)
        return ready;
    if (!colors)
        return kvImageNullPointerArgument;
    for (vImagePixelCount row = 0; row < dest->height; row++) {
        const uint8_t *in = (const uint8_t *)src->data + row * src->rowBytes;
        uint8_t *out = (uint8_t *)dest->data + row * dest->rowBytes;
        for (vImagePixelCount column = 0; column < dest->width; column++) {
            out[column] = colors[charon_subbyte_at(in, column, 1)];
        }
    }
    return kvImageNoError;
}
vImage_Error vImageConvert_Indexed2toPlanar8(const vImage_Buffer *src, const vImage_Buffer *dest, const Pixel_8 colors[4],
                                            vImage_Flags flags)
{
    vImage_Error ready = charon_subbyte_ready(src, dest, flags);
    if (ready != kvImageNoError)
        return ready;
    if (!colors)
        return kvImageNullPointerArgument;
    for (vImagePixelCount row = 0; row < dest->height; row++) {
        const uint8_t *in = (const uint8_t *)src->data + row * src->rowBytes;
        uint8_t *out = (uint8_t *)dest->data + row * dest->rowBytes;
        for (vImagePixelCount column = 0; column < dest->width; column++) {
            out[column] = colors[charon_subbyte_at(in, column, 2)];
        }
    }
    return kvImageNoError;
}

vImage_Error vImageConvert_Indexed4toPlanar8(const vImage_Buffer *src, const vImage_Buffer *dest, const Pixel_8 colors[16],
                                            vImage_Flags flags)
{
    vImage_Error ready = charon_subbyte_ready(src, dest, flags);
    if (ready != kvImageNoError)
        return ready;
    if (!colors)
        return kvImageNullPointerArgument;
    for (vImagePixelCount row = 0; row < dest->height; row++) {
        const uint8_t *in = (const uint8_t *)src->data + row * src->rowBytes;
        uint8_t *out = (uint8_t *)dest->data + row * dest->rowBytes;
        for (vImagePixelCount column = 0; column < dest->width; column++) {
            out[column] = colors[charon_subbyte_at(in, column, 4)];
        }
    }
    return kvImageNoError;
}
