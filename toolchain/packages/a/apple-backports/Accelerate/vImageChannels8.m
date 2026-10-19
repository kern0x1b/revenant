#import <Accelerate/Accelerate.h>
#include "CharonChannels.h"


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
