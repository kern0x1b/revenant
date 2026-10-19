#import <Accelerate/Accelerate.h>
#include "CharonChannels.h"


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
