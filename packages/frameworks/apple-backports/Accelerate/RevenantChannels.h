#pragma once

#import <Accelerate/Accelerate.h>
#include <string.h>

#define REVENANT_CHANNELS_MAX_CHANNELS 4
#define REVENANT_CHANNELS_MAX_BYTES 4

static inline int RevenantChannelsIsNull(const void *pointer)
{
    const void *volatile checked = pointer;
    return checked == NULL;
}

static inline void RevenantChannelsPermuteRow(const uint8_t *srcRow, uint8_t *destRow, vImagePixelCount width,
                                            const uint8_t *map, int channels, int bytes, const uint8_t *insert,
                                            uint8_t copyMask)
{
    for (vImagePixelCount x = 0; x < width; x++) {
        uint8_t source[REVENANT_CHANNELS_MAX_CHANNELS * REVENANT_CHANNELS_MAX_BYTES];
        uint8_t result[REVENANT_CHANNELS_MAX_CHANNELS * REVENANT_CHANNELS_MAX_BYTES];
        size_t pixel = (size_t)channels * bytes;
        memcpy(source, srcRow + (size_t)x * pixel, pixel);
        for (int channel = 0; channel < channels; channel++) {
            const uint8_t *from = source + (size_t)map[channel] * bytes;
            uint8_t *to = result + (size_t)channel * bytes;
            if (insert && (copyMask & (uint8_t)(0x8 >> channel)))
                memcpy(to, insert + (size_t)channel * bytes, (size_t)bytes);
            else
                memcpy(to, from, (size_t)bytes);
        }
        memcpy(destRow + (size_t)x * pixel, result, pixel);
    }
}

static inline void RevenantChannelsExtractRow(const uint8_t *srcRow, uint8_t *destRow, vImagePixelCount width,
                                            long channelIndex, int channels, int bytes)
{
    for (vImagePixelCount x = 0; x < width; x++)
        memcpy(destRow + (size_t)x * bytes,
               srcRow + ((size_t)x * (size_t)channels + (size_t)channelIndex) * (size_t)bytes, (size_t)bytes);
}

static inline void RevenantChannelsFillRow(uint8_t *destRow, vImagePixelCount width, const uint8_t *value, int bytes)
{
    for (vImagePixelCount x = 0; x < width; x++)
        memcpy(destRow + (size_t)x * bytes, value, (size_t)bytes);
}

static inline void RevenantChannelsOverwritePixelRow(const uint8_t *srcRow, uint8_t *destRow, vImagePixelCount width,
                                                   const uint8_t *pixel, int channels, int bytes, uint8_t copyMask)
{
    for (vImagePixelCount x = 0; x < width; x++) {
        uint8_t source[REVENANT_CHANNELS_MAX_CHANNELS * REVENANT_CHANNELS_MAX_BYTES];
        size_t run = (size_t)channels * bytes;
        memcpy(source, srcRow + (size_t)x * run, run);
        for (int channel = 0; channel < channels; channel++) {
            uint8_t *to = destRow + (size_t)x * run + (size_t)channel * bytes;
            if (copyMask & (uint8_t)(0x8 >> channel))
                memcpy(to, pixel + (size_t)channel * bytes, (size_t)bytes);
            else
                memcpy(to, source + (size_t)channel * bytes, (size_t)bytes);
        }
    }
}
