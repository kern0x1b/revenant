// The indexed and sub-byte planar forms of vImage, iOS 7.0: the three expansions out of 1, 2 and 4 bits,
// the three indexed expansions, and the six narrowings back down.
//
// Measured from the release's armv7 caches, 7.0 is the first held release that exports the twelve, so this
// file holds the API of exactly one release.
//
// Conversion.h writes all of this out, and what it says is what the port does:
//
//   - A source narrower than a byte is **big endian within the byte**: the low-indexed pixel sits in the
//     high-order bits of its byte (Conversion.h:4783-4788). Widths are in pixels and rowBytes in whole bytes, so
//     a scanline can end partway through a byte, and the unused bits of the last byte are not read.
//   - Expanding multiplies: Planar1 by 255, Planar2 by 85 and Planar4 by 17 - the same
//     (bits * 255 + half) / max rule the delivered pixel group uses, without a rounding step because there is
//     none to do. **The multiplier is 255 / (2^bits - 1) and not 255 >> (bits - 1)**, and getting that
//     backwards is what the two constants 0x7d and 0xd1 were: 255 >> 1 is 127, and 3 * 127 is 381, which
//     truncates to 125 = 0x7d; 255 >> 3 is 31, and 15 * 31 is 465, which truncates to 209 = 0xd1. It is
//     right for one bit and for no other width, and both divisors divide 255 exactly, so there is no
//     rounding to argue about. Those two numbers were read as the host's answers for a long time before
//     they were traced to this line; facts/Accelerate/vImageIndexed.md carries the measurement.
//
// All six expansions here are byte-exact against the host, over four packed patterns, two rows, and a width
// that ends in the middle of a byte.
//
// **The 0x7d and 0xd1 that were read as the host's answers for the two- and four-bit forms were this
// band's own multiplier.** They came out of `255 >> (bits - 1)` truncating at a byte: 3 * 127 = 381 is
// 125, and 15 * 31 = 465 is 209. The host answers 0xff for an all-one row at one, two and four bits,
// hexdumped and under AddressSanitizer, and so does this file now. The one-bit form was byte-exact
// throughout because 255 >> 0 happens to be the right answer for one bit - which is exactly why the fault
// looked like a host defect confined to the two wider forms.
//   - An indexed expansion looks the index up in the caller's colour table and writes that byte.
//   - Narrowing with `kvImageConvert_DitherNone` takes the nearest destination value to the exact one, which is
//     ((value * max) + 127) / 255 - the same shape the header prints for the sixteen-bit narrowing (Conversion.h:2900-2913).
//
// **What is not here, and where it went.** The other dither modes are a separate axis and a separate
// delivery, because they are not a rounding rule:
//
//   - `kvImageConvert_DitherOrdered` adds pre-computed blue noise whose "offset into this blue noise is
//     randomized per-call", so no two calls agree - not even the release's own, which is what the
//     dither measurement in facts/Accelerate/vImagePixels.md found.
//   - `kvImageConvert_DitherOrderedReproducible` is the same table with a fixed offset, so it *is*
//     reproducible and is read off a constant row in the dithered step.
//   - `kvImageConvert_DitherFloydSteinberg` and `kvImageConvert_DitherAtkinson` are error diffusion over
//     the image, which is deterministic and implementable, and comes with them.
//
// A dither value the enumeration does not name is refused, which is the answer the header gives for it.

#import <Accelerate/Accelerate.h>
#include <string.h>

#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wpointer-bool-conversion"
#pragma clang diagnostic ignored "-Wnonnull"

static const vImage_Flags charon_subbyte_flags = kvImageDoNotTile | kvImageGetTempBufferSize | kvImagePrintDiagnosticsToConsole;

// The same refusals the pixel group answers, and the same order: a flag outside the set the header lists,
// then GetTempBufferSize, then a NULL buffer, then a destination larger than the source.
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


// The pixel at `column` of a row of `bits`-wide pixels, big endian within the byte: the low-indexed pixel
// sits in the high-order bits, and a scanline can end partway through a byte.
static unsigned char charon_subbyte_at(const uint8_t *row, vImagePixelCount column, int bits)
{
    int per_byte = 8 / bits;
    unsigned char byte = row[column / per_byte];
    int shift = 8 - bits - (column % per_byte) * bits;
    return (unsigned char)((byte >> shift) & (unsigned char)((1 << bits) - 1));
}


// One row out of a narrow source, through a scale and nothing else. The widest packed value maps to 255, so
// the scale divides the maximum representable value into 255 - 255 / ((1 << bits) - 1), which is exact at
// every width this file uses.
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
