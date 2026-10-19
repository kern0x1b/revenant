// The alpha placement moves of iOS 7.0: three sixteen-bit channels into four with an alpha the caller names,
// and four into three without one.
//
// Measured from the release's armv7 caches, 7.0 is the first held release that exports the six, so this file
// holds the API of exactly one release. One of the six, vImageConvert_ARGB16UtoRGB16U, is carried in the
// planar group already; these are the other five.
//
// **What is left here is which channel lands where, and the header's argument order names the channels.** The
// five rows are one loop over one table: `order[slot]` says which source channel the destination slot at
// `slot` takes, and -1 says "the alpha", which is the caller's plane if there is one and the caller's value if
// there is not. Measured, not assumed:
//
//   - A NULL alpha buffer is not a refusal. The header marks only the source and the destination non-NULL, and
//     the host then writes the `alpha` argument into the alpha slot: 0x1234 there, over three fills of 0x1234,
//     0x1234 and 0x1234 for ARGB, RGBA and BGRA alike.
//   - With a plane, the plane's own value is the alpha: 0x2000 in, 0x2000 out, in all three orders.
//   - `premultiply` scales the three colour slots by the alpha and leaves the alpha slot alone: an alpha of
//     0x2000 over 0x1000, 0x4000 and 0x8000 gives 512, 2048 and 4096, and 0x2000 is still 0x2000. The
//     sixteen-bit form is the alpha as a fraction of 65535, so the rule is value * alpha / 65535.
//   - Dropping the alpha is a drop, not a rescale: 0x2111, 0x3222 and 0x4333 in an ARGB row come out as 8465,
//     12834 and 17203 in an RGB row, unmoved.
//
// The three orders are BGRA, ARGB and RGBA, and a destination of three channels is always R, G, B in that
// order whatever the source called them - which is the only reason the two four-to-three rows are one row
// between them rather than two.
//
// What is not here: the same ten moves over 32-bit float, which are `vImageConvert_RGBFFFtoARGBFFFF` and its
// five siblings in `vImageAlphaF.m`, a file of their own because the multiply is a float multiply and the
// rounding of the sixteen-bit one has no float counterpart to share.

#import <Accelerate/Accelerate.h>
#include <string.h>

#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wpointer-bool-conversion"
#pragma clang diagnostic ignored "-Wnonnull"

// The alpha slot's marker in the tables above: a destination slot that has no channel in the source.
#define CHARON_ALPHA_SLOT (-1)

static const vImage_Flags charon_alpha_flags = kvImageDoNotTile | kvImageGetTempBufferSize;

// Where each destination slot takes its value from, and how many slots the destination has. The slots are in
// memory order, not in name order: ARGB16U puts the alpha first and BGRA16U puts blue first, so the two tables
// differ in which slot the -1 sits in and, for BGRA, in which source channel the first slot takes. -1 is the
// alpha, which has no channel in a three-channel source.
//
// Measured, over three fills of the same value and one plane:
//
//   order         slot 0        slot 1        slot 2        slot 3
//   ARGB16U       the alpha     red 0x1000    green 0x4000   blue 0x8000
//   RGBA16U       red 0x1000    green 0x4000   blue 0x8000    the alpha
//   BGRA16U       blue 0x8000   green 0x4000   red 0x1000     the alpha
static const int charon_alpha_rgb_to[3][4] = {
    { CHARON_ALPHA_SLOT, 0, 1, 2 },   // ARGB16U
    { 0, 1, 2, CHARON_ALPHA_SLOT },   // RGBA16U
    { 2, 1, 0, CHARON_ALPHA_SLOT },   // BGRA16U
};

// Four channels in, three out. A destination of three channels is always R, G, B in that order, so the two
// rows differ only in where the source keeps its colours: RGBA16U has them first and BGRA16U has blue first.
static const int charon_alpha_rgba_to_rgb[3] = { 0, 1, 2 };
static const int charon_alpha_bgra_to_rgb[3] = { 2, 1, 0 };

// The refusals, in the order the other files in this library give them: a flag outside the set the header
// lists, then GetTempBufferSize, then a NULL buffer, then a destination larger than the source.
static vImage_Error charon_alpha_ready(const vImage_Buffer *src, const vImage_Buffer *dest, vImage_Flags flags)
{
    if (flags & ~charon_alpha_flags)
        return kvImageUnknownFlagsBit;
    if (flags & kvImageGetTempBufferSize)
        return 0;
    if (!src || !dest)
        return kvImageNullPointerArgument;
    if (src->width < dest->width || src->height < dest->height)
        return kvImageRoiLargerThanInputBuffer;
    return kvImageNoError;
}

// One sixteen-bit channel of one row, read through the interleaved stride. The stride is the source's own
// channel count and not the destination's: the three widen rows read a three-channel source into a four-channel
// destination, and the two narrow rows read four into three. Passing the wrong one reads a neighbouring pixel.
static uint16_t charon_alpha16_at(const uint8_t *in, vImagePixelCount column, int channel, int channels)
{
    uint16_t value;
    memcpy(&value, in + (column * channels + channel) * 2, sizeof value);
    return value;
}

// value * alpha / 65535, in the sixteen-bit integer the destination is. The alpha is a fraction of 65535 and
// the product is rounded to nearest, which the host's own answers decide: 0xffff * 0x8000 is 32767.5, and the
// host writes 32768 - the host differential in tests/backports/host/vimagealpha carries that one case.
static uint16_t charon_alpha16_premultiply(uint16_t value, uint16_t alpha)
{
    return (uint16_t)(((uint32_t)value * alpha + 32767u) / 65535u);
}

// Three channels in, four out: the caller's plane or value as the alpha, optionally premultiplied.
static vImage_Error charon_alpha16_widen(const vImage_Buffer *src, const vImage_Buffer *aSrc, Pixel_16U fill,
                                         const vImage_Buffer *dest, bool premultiply, const int *order,
                                         int src_channels, vImage_Flags flags)
{
    vImage_Error ready = charon_alpha_ready(src, dest, flags);
    if (ready != kvImageNoError)
        return ready;
    for (vImagePixelCount row = 0; row < dest->height; row++) {
        const uint8_t *in = (const uint8_t *)src->data + row * src->rowBytes;
        const uint8_t *alpha_in = aSrc ? (const uint8_t *)aSrc->data + row * aSrc->rowBytes : NULL;
        uint8_t *out = (uint8_t *)dest->data + row * dest->rowBytes;
        for (vImagePixelCount column = 0; column < dest->width; column++) {
            uint16_t alpha;
            if (alpha_in) {
                memcpy(&alpha, alpha_in + column * 2, sizeof alpha);
            } else {
                alpha = fill;
            }
            for (int slot = 0; slot < 4; slot++) {
                uint16_t value = order[slot] == CHARON_ALPHA_SLOT
                    ? alpha
                    : charon_alpha16_at(in, column, order[slot], src_channels);
                if (premultiply && order[slot] != CHARON_ALPHA_SLOT)
                    value = charon_alpha16_premultiply(value, alpha);
                memcpy(out + (column * 4 + slot) * 2, &value, sizeof value);
            }
        }
    }
    return kvImageNoError;
}

// Four channels in, three out: the alpha is dropped and the colours are not touched.
static vImage_Error charon_alpha16_narrow(const vImage_Buffer *src, const vImage_Buffer *dest, const int *order,
                                          vImage_Flags flags)
{
    vImage_Error ready = charon_alpha_ready(src, dest, flags);
    if (ready != kvImageNoError)
        return ready;
    for (vImagePixelCount row = 0; row < dest->height; row++) {
        const uint8_t *in = (const uint8_t *)src->data + row * src->rowBytes;
        uint8_t *out = (uint8_t *)dest->data + row * dest->rowBytes;
        for (vImagePixelCount column = 0; column < dest->width; column++) {
            for (int slot = 0; slot < 3; slot++) {
                uint16_t value = charon_alpha16_at(in, column, order[slot], 4);
                memcpy(out + (column * 3 + slot) * 2, &value, sizeof value);
            }
        }
    }
    return kvImageNoError;
}

vImage_Error vImageConvert_RGB16UtoARGB16U(const vImage_Buffer *rgbSrc, const vImage_Buffer *aSrc, Pixel_16U alpha,
                                           const vImage_Buffer *argbDest, bool premultiply, vImage_Flags flags)
{
    return charon_alpha16_widen(rgbSrc, aSrc, alpha, argbDest, premultiply, charon_alpha_rgb_to[0], 3, flags);
}

vImage_Error vImageConvert_RGB16UtoRGBA16U(const vImage_Buffer *rgbSrc, const vImage_Buffer *aSrc, Pixel_16U alpha,
                                           const vImage_Buffer *rgbaDest, bool premultiply, vImage_Flags flags)
{
    return charon_alpha16_widen(rgbSrc, aSrc, alpha, rgbaDest, premultiply, charon_alpha_rgb_to[1], 3, flags);
}

vImage_Error vImageConvert_RGB16UtoBGRA16U(const vImage_Buffer *rgbSrc, const vImage_Buffer *aSrc, Pixel_16U alpha,
                                           const vImage_Buffer *bgraDest, bool premultiply, vImage_Flags flags)
{
    return charon_alpha16_widen(rgbSrc, aSrc, alpha, bgraDest, premultiply, charon_alpha_rgb_to[2], 3, flags);
}

vImage_Error vImageConvert_RGBA16UtoRGB16U(const vImage_Buffer *rgbaSrc, const vImage_Buffer *rgbDest, vImage_Flags flags)
{
    return charon_alpha16_narrow(rgbaSrc, rgbDest, charon_alpha_rgba_to_rgb, flags);
}

vImage_Error vImageConvert_BGRA16UtoRGB16U(const vImage_Buffer *bgraSrc, const vImage_Buffer *rgbDest, vImage_Flags flags)
{
    return charon_alpha16_narrow(bgraSrc, rgbDest, charon_alpha_bgra_to_rgb, flags);
}
