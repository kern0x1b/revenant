// The packed twelve-bit unsigned conversions of iOS 7.0: `vImageConvert_12UTo16U` and its reverse.
//
// Measured from the release's armv7 caches, 7.0 is the first held release that exports the two, so this file
// holds the API of exactly one release.
//
// Twelve bits is one and a half bytes a pixel, so a row is **two pixels in three bytes** and a row of odd width
// has a half-pair at its end. The header prints the algorithm for both directions and it consumes exactly three
// bytes per two pixels, which leaves the odd case unanswered. Measured, over every width from 1 to 17, odd and
// even, by setting one source bit at a time and reading every destination pixel:
//
//   - **The layout is regular and the odd width needs no case of its own.** Pixel `p` of a row is the twelve
//     bits at bit offset `12 * p` of the row, counted from the high-order bit of its first byte. In triple terms
//     that is triple `p / 2`, offset `(p % 2) * 12` within the triple, big endian - the first pixel of a pair is
//     in the high twelve bits of the twenty-four, which is the header's `(srcRow[0] << 16) | (srcRow[1] << 8)
//     | srcRow[2]` read. A row of seventeen pixels is twenty-six bytes and pixel sixteen is the *first* pixel of
//     the last triple; a row of one pixel is three bytes and the low twelve bits of the last one are unused.
//   - **A row is `(width + 1) / 2 * 3` bytes**, so an odd width is padded up to a whole triple. The padding is
//     read but never written: with a single bit set anywhere, no destination bit outside its own pixel's
//     twelve is affected except through the scale, which is a function of that pixel alone.
//   - **The scales are the header's, exactly.** 12U to 16U is `(t * 65535 + (t << 4) + 2055) >> 12`, and every
//     one of the 4096 possible values answers it — 0, 16, 32, 48, 64, up to 65535 for 4095. 16U to 12U is
//     `(t * 4095 + 32767 + (t >> 4)) >> 16`, checked at every seventh value of 65536 and agreeing every time.
//     Both are written here in the header's own form rather than in a form of our own, because a form of our
//     own that happens to agree on the values we checked is not the same thing as the header's rule.
//
// **A single-bit map cannot measure either scale, and this band wasted a probe on it.** One source bit set at a
// time does not produce one destination bit: a twelve-to-sixteen expansion sets up to three, and a map that
// records one source bit per destination bit silently keeps only the last of them. The layout is what a
// single-bit map is good for, because there the correspondence really is one to one. The scales are swept as
// values, exhaustively, because that is what settles them. See facts/Accelerate/vImagePacked12U.md.

#import <Accelerate/Accelerate.h>
#include <string.h>

#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wpointer-bool-conversion"
#pragma clang diagnostic ignored "-Wnonnull"

static const vImage_Flags charon_packed_flags = kvImageDoNotTile | kvImageGetTempBufferSize;

// The refusals, in the order the rest of this library gives them: a flag outside the set the header lists, then
// GetTempBufferSize, then a NULL buffer, then a destination larger than the source.
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

// The bytes a row of `width` twelve-bit pixels takes: two pixels to a triple, and an odd pixel padded up to a
// whole one. Measured at every width from 1 to 17.
static size_t charon_packed_row_bytes(vImagePixelCount width)
{
    return (size_t)((width + 1) / 2 * 3);
}

// The twelve bits of pixel `column`, read big endian out of its triple: triple `column / 2`, and the low or the
// high half of it by `column % 2`.
static uint16_t charon_packed12_at(const uint8_t *row, vImagePixelCount column)
{
    const uint8_t *triple = row + (size_t)(column / 2) * 3;
    unsigned high = (unsigned)triple[0] << 16 | (unsigned)triple[1] << 8 | triple[2];
    unsigned value = column % 2 ? high & 0xfffu : (high >> 12) & 0xfffu;
    return (uint16_t)value;
}

// The same twelve bits, written. Only the pixel's own bits are touched, so the padding of an odd row's last
// triple is left as the caller had it.
static void charon_packed12_put(uint8_t *row, vImagePixelCount column, uint16_t value)
{
    uint8_t *triple = row + (size_t)(column / 2) * 3;
    unsigned pair = (unsigned)triple[0] << 16 | (unsigned)triple[1] << 8 | triple[2];
    // The two masks are twelve bits each, and they are each other's complement inside the twenty-four: an
    // even column writes the HIGH twelve and keeps the low twelve, an odd column the reverse. A version of
    // this line masked 0xf000 on the odd branch - four bits, not twelve - so writing pixel 1 destroyed three
    // quarters of pixel 0 and the differential saw the port write 0x00 where the host wrote 0x100, 0x300 and
    // 0x500. It is the same shape as the sub-byte group's 0x7d: a mask narrower than the field it is meant to
    // preserve, and the host's hexdump is what settled it.
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
