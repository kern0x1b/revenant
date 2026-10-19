// The channel moves of vImage that arrived at 16.0: the permute over half-precision four-channel buffers and
// the scalar fill of a half-precision planar one.
//
// Measured from the release's armv7 caches, 16.0 is the first held release that exports these two. Both the
// 7.0 and the 8.0 arrivals of the family are in vImageChannels7.m and vImageChannels8.m; one object, one
// release.
//
// **Neither of these needs CharonVImageFixed.h**, which is the header this family would otherwise want: a
// channel move and a fill move sixteen bits without looking at them, and a half-precision value that is
// copied is the same sixteen bits it was. Nothing here computes a half, so there is no rounding to get
// wrong - and that is the whole argument, measured rather than asserted by
// tests/backports/host/vimagechannels, which compares the sixteen bits of every half it moves.

#import <Accelerate/Accelerate.h>
#include "CharonChannels.h"


// **The flag set is measured per function, and the two functions of this file differ.** Asked of the host one
// bit at a time over all thirty-two (tests/backports/host/vimagechannels prints every one of them): the
// permute answers kvImageNoError for `kvImageDoNotTile` (0x10) and `kvImageGetTempBufferSize` (0x80) and
// kvImageUnknownFlagsBit for every other bit, and the fill answers kvImageNoError for every one of the
// thirty-two and has no flag refusal at all.
static const vImage_Flags charon_channels16_permute_flags = kvImageDoNotTile | kvImageGetTempBufferSize;
static const vImage_Flags charon_channels16_fill_flags = 0xFFFFFFFF;

static vImage_Error charon_channels16_ready(const vImage_Buffer *src, const vImage_Buffer *dest, vImage_Flags flags,
                                            vImage_Flags allowed)
{
    if (flags & ~allowed)
        return kvImageUnknownFlagsBit;
    if (flags & kvImageGetTempBufferSize)
        return 0;
    if (CharonChannelsIsNull(src) || CharonChannelsIsNull(dest))
        return kvImageNullPointerArgument;
    if (src->width < dest->width || src->height < dest->height)
        return kvImageRoiLargerThanInputBuffer;
    return kvImageNoError;
}

// The fill's check asks for the destination alone: it has no source argument, and a first version passed a
// NULL source through the shared check and answered kvImageNullPointerArgument on a legal call.
static vImage_Error charon_channels16_ready_dest(const vImage_Buffer *dest, vImage_Flags flags)
{
    if (flags & ~charon_channels16_fill_flags)
        return kvImageUnknownFlagsBit;
    if (flags & kvImageGetTempBufferSize)
        return 0;
    if (CharonChannelsIsNull(dest))
        return kvImageNullPointerArgument;
    return kvImageNoError;
}

vImage_Error vImagePermuteChannels_ARGB16F(const vImage_Buffer *src, const vImage_Buffer *dest,
                                           const uint8_t permuteMap[4], vImage_Flags flags)
{
    vImage_Error ready = charon_channels16_ready(src, dest, flags, charon_channels16_permute_flags);
    if (ready != kvImageNoError)
        return ready;
    if (CharonChannelsIsNull(permuteMap))
        return kvImageNullPointerArgument;
    for (int i = 0; i < 4; i++)
        if (permuteMap[i] > 3)
            return kvImageInvalidParameter;
    for (vImagePixelCount row = 0; row < dest->height; row++)
        CharonChannelsPermuteRow((const uint8_t *)src->data + row * src->rowBytes,
                                 (uint8_t *)dest->data + row * dest->rowBytes, dest->width, permuteMap, 4, 2, NULL, 0);
    return kvImageNoError;
}

vImage_Error vImageOverwriteChannelsWithScalar_Planar16F(Pixel_16F scalar, const vImage_Buffer *dest,
                                                         vImage_Flags flags)
{
    vImage_Error ready = charon_channels16_ready_dest(dest, flags);
    if (ready != kvImageNoError)
        return ready;
    for (vImagePixelCount row = 0; row < dest->height; row++)
        CharonChannelsFillRow((uint8_t *)dest->data + row * dest->rowBytes, dest->width, (const uint8_t *)&scalar, 2);
    return kvImageNoError;
}