#import <Accelerate/Accelerate.h>
#include "CharonChannels.h"


static const vImage_Flags charon_channels7_permute_flags = kvImageDoNotTile | kvImageGetTempBufferSize;
static const vImage_Flags charon_channels7_pixel_flags = 0xFFFFFFFF;

static vImage_Error charon_channels7_ready(const vImage_Buffer *src, const vImage_Buffer *dest, vImage_Flags flags,
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

static vImage_Error charon_channels7_map(const uint8_t *map)
{
    if (CharonChannelsIsNull(map))
        return kvImageNullPointerArgument;
    for (int i = 0; i < 4; i++)
        if (map[i] > 3)
            return kvImageInvalidParameter;
    return kvImageNoError;
}

vImage_Error vImagePermuteChannels_ARGB16U(const vImage_Buffer *src, const vImage_Buffer *dest,
                                           const uint8_t permuteMap[4], vImage_Flags flags)
{
    vImage_Error ready = charon_channels7_ready(src, dest, flags, charon_channels7_permute_flags);
    if (ready != kvImageNoError)
        return ready;
    ready = charon_channels7_map(permuteMap);
    if (ready != kvImageNoError)
        return ready;
    for (vImagePixelCount row = 0; row < dest->height; row++)
        CharonChannelsPermuteRow((const uint8_t *)src->data + row * src->rowBytes,
                                 (uint8_t *)dest->data + row * dest->rowBytes, dest->width, permuteMap, 4, 2, NULL, 0);
    return kvImageNoError;
}

vImage_Error vImagePermuteChannelsWithMaskedInsert_ARGB16U(const vImage_Buffer *src, const vImage_Buffer *dest,
                                                          const uint8_t permuteMap[4], uint8_t copyMask,
                                                          const Pixel_ARGB_16U backgroundColor, vImage_Flags flags)
{
    vImage_Error ready = charon_channels7_ready(src, dest, flags, charon_channels7_permute_flags);
    if (ready != kvImageNoError)
        return ready;
    ready = charon_channels7_map(permuteMap);
    if (ready != kvImageNoError)
        return ready;
    for (vImagePixelCount row = 0; row < dest->height; row++)
        CharonChannelsPermuteRow((const uint8_t *)src->data + row * src->rowBytes,
                                 (uint8_t *)dest->data + row * dest->rowBytes, dest->width, permuteMap, 4, 2,
                                 (const uint8_t *)backgroundColor, copyMask);
    return kvImageNoError;
}

vImage_Error vImagePermuteChannelsWithMaskedInsert_ARGB8888(const vImage_Buffer *src, const vImage_Buffer *dest,
                                                           const uint8_t permuteMap[4], uint8_t copyMask,
                                                           const Pixel_8888 backgroundColor, vImage_Flags flags)
{
    vImage_Error ready = charon_channels7_ready(src, dest, flags, charon_channels7_permute_flags);
    if (ready != kvImageNoError)
        return ready;
    ready = charon_channels7_map(permuteMap);
    if (ready != kvImageNoError)
        return ready;
    for (vImagePixelCount row = 0; row < dest->height; row++)
        CharonChannelsPermuteRow((const uint8_t *)src->data + row * src->rowBytes,
                                 (uint8_t *)dest->data + row * dest->rowBytes, dest->width, permuteMap, 4, 1,
                                 (const uint8_t *)backgroundColor, copyMask);
    return kvImageNoError;
}

vImage_Error vImagePermuteChannelsWithMaskedInsert_ARGBFFFF(const vImage_Buffer *src, const vImage_Buffer *dest,
                                                           const uint8_t permuteMap[4], uint8_t copyMask,
                                                           const Pixel_FFFF backgroundColor, vImage_Flags flags)
{
    vImage_Error ready = charon_channels7_ready(src, dest, flags, charon_channels7_permute_flags);
    if (ready != kvImageNoError)
        return ready;
    ready = charon_channels7_map(permuteMap);
    if (ready != kvImageNoError)
        return ready;
    for (vImagePixelCount row = 0; row < dest->height; row++)
        CharonChannelsPermuteRow((const uint8_t *)src->data + row * src->rowBytes,
                                 (uint8_t *)dest->data + row * dest->rowBytes, dest->width, permuteMap, 4, 4,
                                 (const uint8_t *)backgroundColor, copyMask);
    return kvImageNoError;
}

vImage_Error vImageOverwriteChannelsWithPixel_ARGB16U(const Pixel_ARGB_16U the_pixel, const vImage_Buffer *src,
                                                      const vImage_Buffer *dest, uint8_t copyMask, vImage_Flags flags)
{
    vImage_Error ready = charon_channels7_ready(src, dest, flags, charon_channels7_pixel_flags);
    if (ready != kvImageNoError)
        return ready;
    for (vImagePixelCount row = 0; row < dest->height; row++)
        CharonChannelsOverwritePixelRow((const uint8_t *)src->data + row * src->rowBytes,
                                        (uint8_t *)dest->data + row * dest->rowBytes, dest->width,
                                        (const uint8_t *)the_pixel, 4, 2, copyMask);
    return kvImageNoError;
}
