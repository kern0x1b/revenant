// The channel moves of vImage that arrived at 7.0: the four-channel permute over sixteen bits per channel,
// the three masked inserts beside it, and the overwrite with one ARGB16U pixel.
//
// Measured from the release's armv7 caches, 7.0 is the first held release that exports these five, and this
// file holds the API of exactly that one release. The 8.0 and 16.0 arrivals of the same family are in
// vImageChannels8.m and vImageChannels16.m, which is the split the export trie asks for rather than one of
// convenience: one object, one release.
//
// The engine is CharonChannels.h's, and everything here is what Conversion.h says of these five:
// destination pixel x's run `i` is the source's run the map names; a masked insert takes the given pixel's
// run `i` where the copyMask bit for channel `i` is clear; and an overwrite with a pixel conserves the
// source's runs the mask covers. The loops are measured byte for byte against the host's own vImage, over
// five maps, all sixteen masks and both in place and not, in tests/backports/host/vimagechannels
// (facts/Accelerate/vImageChannels.md).

#import <Accelerate/Accelerate.h>
#include "CharonChannels.h"


// The refusals, measured rather than copied from a neighbour. **The flag set is `DoNotTile` and
// `GetTempBufferSize` and nothing else**, which is not what the tree's other vImage files accept: asked of
// the host one bit at a time, over all thirty-two, it answers kvImageNoError for 0x10 and 0x80 and
// kvImageUnknownFlagsBit for every other bit including 0x100, `kvImagePrintDiagnosticsToConsole`, which
// the files beside this one do accept (tests/backports/host/vimagechannels prints all thirty-two).
// GetTempBufferSize answers zero and does no work, which is what its own name says.

// **The flag set is measured per function and the three groups of this file differ.** Asked of the host one
// bit at a time over all thirty-two (tests/backports/host/vimagechannels prints every one of them):
//
//   - the permute and the three masked inserts answer kvImageNoError for `kvImageDoNotTile` (0x10) and
//     `kvImageGetTempBufferSize` (0x80) and kvImageUnknownFlagsBit for every other bit, including
//     0x100, `kvImagePrintDiagnosticsToConsole`, which the files beside this one do accept;
//   - the overwrite with a pixel answers kvImageNoError for **every one of the thirty-two bits** and has no
//     flag refusal at all, where its header lists two flags and nothing else.
//
// So the mask is a parameter of the shared check and each group passes its own. An earlier version had one
// constant for the file, which was wrong for two of its five functions. GetTempBufferSize answers zero and
// does no work wherever it is accepted, which is what its own name says.
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

// The map, which the header (Conversion.h:1711-1716) gives a range for: a map value above 3 is an error,
// kvImageInvalidParameter, and the port checks it here.
//
// **The copyMask has no range, whatever this header says.** It names kvImageInvalidParameter for a mask
// above 0x0F, and asked of the host over twelve values - 0x00, 0x01, 0x08, 0x0F, 0x10, 0x11, 0x1F, 0x20, 0x40,
// 0x80, 0xF0 and 0xFF - the host answers kvImageNoError for every one of them and writes the same bytes for
// the values above 0x0F as for 0x0F (tests/backports/host/vimagechannels prints all twelve and compares the
// bytes). So the port takes the mask as it is: the four channel bits are tested and the rest are carried,
// which is what the host does. An earlier version of this file refused a mask above 0x0F and was wrong.
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