// The channel moves of vImage that arrived at 8.0: two extracts out of a four-channel buffer, two scalar
// fills of a planar one, and the three-channel eight-bit permute.
//
// Measured from the release's armv7 caches, 8.0 is the first held release that exports these five. The 7.0
// arrivals of the same family are in vImageChannels7.m and the 16.0 pair in vImageChannels16.m; one object,
// one release, which is what the export trie asks of a file.
//
// The engine is CharonChannels.h's and the arithmetic is Conversion.h's own statement in each case: an
// extract is a copy of one run out of four, a fill is the same value in every pixel, and the three-channel
// permute is the four-channel rule with three runs of one byte. The three-channel header adds a case the
// others do not have - **a NULL map is the identity** - which is measured here and not assumed.

#import <Accelerate/Accelerate.h>
#include "CharonChannels.h"


// **The flag set is measured per function and the three groups of this file differ.** Asked of the host one
// bit at a time over all thirty-two (tests/backports/host/vimagechannels prints every one of them):
//
//   - the two extracts answer kvImageNoError for `kvImageDoNotTile` (0x10), `kvImageGetTempBufferSize` (0x80)
//     and `kvImagePrintDiagnosticsToConsole` (0x100), and kvImageUnknownFlagsBit for every other bit;
//   - `vImagePermuteChannels_RGB888` takes the same two as the permute above, `DoNotTile` and
//     `GetTempBufferSize`, and refuses every other bit with kvImageUnknownFlagsBit;
//   - the two fills answer kvImageNoError for every one of the thirty-two bits and have no flag refusal.
//
// So the mask is a parameter of the shared check and each group passes its own.
static const vImage_Flags charon_channels8_extract_flags = kvImageDoNotTile | kvImageGetTempBufferSize
                                                           | kvImagePrintDiagnosticsToConsole;
static const vImage_Flags charon_channels8_rgb888_flags = kvImageDoNotTile | kvImageGetTempBufferSize;
static const vImage_Flags charon_channels8_fill_flags = 0xFFFFFFFF;

static vImage_Error charon_channels8_ready(const vImage_Buffer *src, const vImage_Buffer *dest, vImage_Flags flags,
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

// The fills have no source argument at all - Conversion.h gives them a scalar and a destination and
// nothing else - so their check asks for the destination alone. A first version passed a NULL source
// through the shared check and every fill answered kvImageNullPointerArgument on a call the header says is
// legal; the measured host answers kvImageNoError and writes the value (see the run).
static vImage_Error charon_channels8_ready_dest(const vImage_Buffer *dest, vImage_Flags flags)
{
    if (flags & ~charon_channels8_fill_flags)
        return kvImageUnknownFlagsBit;
    if (flags & kvImageGetTempBufferSize)
        return 0;
    if (CharonChannelsIsNull(dest))
        return kvImageNullPointerArgument;
    return kvImageNoError;
}

// The channel index, whose range the header gives: "kvImageInvalidParameter - channelIndex must be in the
// range [0,3]". It is a `long`, so the test is on the value and not on a truncated one.
static vImage_Error charon_channels8_channel(long channelIndex)
{
    return (channelIndex < 0 || channelIndex > 3) ? kvImageInvalidParameter : kvImageNoError;
}

vImage_Error vImageExtractChannel_ARGB16U(const vImage_Buffer *src, const vImage_Buffer *dest, long channelIndex,
                                          vImage_Flags flags)
{
    vImage_Error ready = charon_channels8_ready(src, dest, flags, charon_channels8_extract_flags);
    if (ready != kvImageNoError)
        return ready;
    ready = charon_channels8_channel(channelIndex);
    if (ready != kvImageNoError)
        return ready;
    for (vImagePixelCount row = 0; row < dest->height; row++)
        CharonChannelsExtractRow((const uint8_t *)src->data + row * src->rowBytes,
                                 (uint8_t *)dest->data + row * dest->rowBytes, dest->width, channelIndex, 4, 2);
    return kvImageNoError;
}

vImage_Error vImageExtractChannel_ARGBFFFF(const vImage_Buffer *src, const vImage_Buffer *dest, long channelIndex,
                                           vImage_Flags flags)
{
    vImage_Error ready = charon_channels8_ready(src, dest, flags, charon_channels8_extract_flags);
    if (ready != kvImageNoError)
        return ready;
    ready = charon_channels8_channel(channelIndex);
    if (ready != kvImageNoError)
        return ready;
    for (vImagePixelCount row = 0; row < dest->height; row++)
        CharonChannelsExtractRow((const uint8_t *)src->data + row * src->rowBytes,
                                 (uint8_t *)dest->data + row * dest->rowBytes, dest->width, channelIndex, 4, 4);
    return kvImageNoError;
}

vImage_Error vImageOverwriteChannelsWithScalar_Planar16U(Pixel_16U scalar, const vImage_Buffer *dest,
                                                         vImage_Flags flags)
{
    vImage_Error ready = charon_channels8_ready_dest(dest, flags);
    if (ready != kvImageNoError)
        return ready;
    for (vImagePixelCount row = 0; row < dest->height; row++)
        CharonChannelsFillRow((uint8_t *)dest->data + row * dest->rowBytes, dest->width, (const uint8_t *)&scalar, 2);
    return kvImageNoError;
}

vImage_Error vImageOverwriteChannelsWithScalar_Planar16S(Pixel_16S scalar, const vImage_Buffer *dest,
                                                         vImage_Flags flags)
{
    vImage_Error ready = charon_channels8_ready_dest(dest, flags);
    if (ready != kvImageNoError)
        return ready;
    for (vImagePixelCount row = 0; row < dest->height; row++)
        CharonChannelsFillRow((uint8_t *)dest->data + row * dest->rowBytes, dest->width, (const uint8_t *)&scalar, 2);
    return kvImageNoError;
}

vImage_Error vImagePermuteChannels_RGB888(const vImage_Buffer *src, const vImage_Buffer *dest,
                                          const uint8_t permuteMap[3], vImage_Flags flags)
{
    vImage_Error ready = charon_channels8_ready(src, dest, flags, charon_channels8_rgb888_flags);
    if (ready != kvImageNoError)
        return ready;
    // **A NULL map is a refusal here, and this header's comment says the opposite** (Conversion.h:9628-9632): it
    // says a NULL map leaves the destination as an identity order would. Measured on this Mac's own vImage, the host
    // dereferences the map and its process ends on SIGSEGV, leaving the destination untouched
    // (tests/backports/host/vimagechannels asks it in a child process so the measurement survives). So the
    // port refuses a NULL map the way the four-channel forms do rather than answering a header sentence the
    // release does not implement: a caller passing NULL has a bug either way, and a refusal is the answer
    // that is the same on both sides.
    if (CharonChannelsIsNull(permuteMap))
        return kvImageNullPointerArgument;
    const uint8_t *map = permuteMap;
    for (int i = 0; i < 3; i++)
        if (map[i] > 2)
            return kvImageInvalidParameter;
    for (vImagePixelCount row = 0; row < dest->height; row++)
        CharonChannelsPermuteRow((const uint8_t *)src->data + row * src->rowBytes,
                                 (uint8_t *)dest->data + row * dest->rowBytes, dest->width, map, 3, 1, NULL, 0);
    return kvImageNoError;
}
