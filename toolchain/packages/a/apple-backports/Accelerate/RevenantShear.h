#pragma once

#import <Accelerate/Accelerate.h>
#include "CharonChannels.h"
#include "CharonResampling.h"
#include "CharonVImageFixed.h"

enum CharonPixelType {
    CharonARGB16U, CharonARGB16S, CharonPlanar16U, CharonPlanar16S, CharonPlanar16F, CharonPlanarF,
    CharonCbCr8, CharonCbCr16U, CharonCbCr16S, CharonCbCr16F, CharonCbCrF, CharonARGB16F, CharonARGBFFFF,
    CharonXRGB2101010W
};

static inline unsigned CharonChannels(enum CharonPixelType type)
{
    switch (type) {
    case CharonARGB16U: case CharonARGB16S: case CharonARGB16F: case CharonARGBFFFF: return 4;
    case CharonCbCr8: case CharonCbCr16U: case CharonCbCr16S: case CharonCbCr16F: case CharonCbCrF: return 2;
    case CharonXRGB2101010W: return 4;
    default: return 1;
    }
}

static inline size_t CharonBytesPerPixel(enum CharonPixelType type)
{
    switch (type) {
    case CharonARGB16U: case CharonARGB16S: case CharonARGB16F: return 8;
    case CharonARGBFFFF: return 16;
    case CharonPlanar16U: case CharonPlanar16S: case CharonPlanar16F: return 2;
    case CharonPlanarF: return 4;
    case CharonCbCr8: return 2;
    case CharonCbCr16U: case CharonCbCr16S: case CharonCbCr16F: return 4;
    case CharonCbCrF: return 8;
    case CharonXRGB2101010W: return 4;
    default: return 1;
    }
}

static inline double CharonChannelAt(const void *row, vImagePixelCount pixel, unsigned channel,
                                     enum CharonPixelType type)
{
    switch (type) {
    case CharonARGB16U: return (double)((const uint16_t *)row)[pixel * 4 + channel];
    case CharonARGB16S: return (double)((const int16_t *)row)[pixel * 4 + channel];
    case CharonPlanar16U: return (double)((const uint16_t *)row)[pixel];
    case CharonPlanar16S: return (double)((const int16_t *)row)[pixel];
    case CharonCbCr8: return (double)((const uint8_t *)row)[pixel * 2 + channel];
    case CharonCbCr16U: return (double)((const uint16_t *)row)[pixel * 2 + channel];
    case CharonCbCr16S: return (double)((const int16_t *)row)[pixel * 2 + channel];
    case CharonCbCr16F: return (double)charon_half_to_float(((const uint16_t *)row)[pixel * 2 + channel]);
    case CharonPlanar16F: return (double)charon_half_to_float(((const uint16_t *)row)[pixel]);
    case CharonARGB16F: return (double)charon_half_to_float(((const uint16_t *)row)[pixel * 4 + channel]);
    case CharonXRGB2101010W: return (double)((((const uint32_t *)row)[pixel] >> (channel * 10)) & 0x3FFu);
    case CharonPlanarF: return (double)((const float *)row)[pixel];
    case CharonCbCrF: return (double)((const float *)row)[pixel * 2 + channel];
    case CharonARGBFFFF: return (double)((const float *)row)[pixel * 4 + channel];
    default: return 0.0;
    }
}

static inline double CharonSaturate(double value, enum CharonPixelType type)
{
    switch (type) {
    case CharonARGB16U: case CharonPlanar16U: case CharonCbCr16U: case CharonXRGB2101010W:
        return value < 0.0 ? 0.0 : (value > 65535.0 ? 65535.0 : value);
    case CharonCbCr8:
        return value < 0.0 ? 0.0 : (value > 255.0 ? 255.0 : value);
    case CharonARGB16S: case CharonPlanar16S: case CharonCbCr16S:
        return value < -32768.0 ? -32768.0 : (value > 32767.0 ? 32767.0 : value);
    default:
        return value;
    }
}

#define CHARON_ROUND_HALF_UP(v) ((v) >= 0.0 ? floor((v) + 0.5) : ceil((v) - 0.5))

static inline void CharonChannelPut(void *row, vImagePixelCount pixel, unsigned channel, double value,
                                    enum CharonPixelType type)
{
    switch (type) {
    case CharonARGB16U: ((uint16_t *)row)[pixel * 4 + channel] = (uint16_t)CHARON_ROUND_HALF_UP(CharonSaturate(value, type)); break;
    case CharonARGB16S: ((int16_t *)row)[pixel * 4 + channel] = (int16_t)CHARON_ROUND_HALF_UP(CharonSaturate(value, type)); break;
    case CharonPlanar16U: ((uint16_t *)row)[pixel] = (uint16_t)CHARON_ROUND_HALF_UP(CharonSaturate(value, type)); break;
    case CharonPlanar16S: ((int16_t *)row)[pixel] = (int16_t)CHARON_ROUND_HALF_UP(CharonSaturate(value, type)); break;
    case CharonCbCr8: ((uint8_t *)row)[pixel * 2 + channel] = (uint8_t)CHARON_ROUND_HALF_UP(CharonSaturate(value, type)); break;
    case CharonCbCr16U: ((uint16_t *)row)[pixel * 2 + channel] = (uint16_t)CHARON_ROUND_HALF_UP(CharonSaturate(value, type)); break;
    case CharonCbCr16S: ((int16_t *)row)[pixel * 2 + channel] = (int16_t)CHARON_ROUND_HALF_UP(CharonSaturate(value, type)); break;
    case CharonCbCr16F: ((uint16_t *)row)[pixel * 2 + channel] = charon_float_to_half((float)value); break;
    case CharonPlanar16F: ((uint16_t *)row)[pixel] = charon_float_to_half((float)value); break;
    case CharonARGB16F: ((uint16_t *)row)[pixel * 4 + channel] = charon_float_to_half((float)value); break;
    case CharonXRGB2101010W: {
        uint32_t word = ((uint32_t *)row)[pixel], shift = channel * 10;
        word = (word & ~(0x3FFu << shift))
             | ((((uint32_t)CHARON_ROUND_HALF_UP(CharonSaturate(value, type))) & 0x3FFu) << shift);
        ((uint32_t *)row)[pixel] = word;
        break;
    }
    case CharonPlanarF: ((float *)row)[pixel] = (float)value; break;
    case CharonCbCrF: ((float *)row)[pixel * 2 + channel] = (float)value; break;
    case CharonARGBFFFF: ((float *)row)[pixel * 4 + channel] = (float)value; break;
    default: break;
    }
}

static inline void CharonShearBackU16(double *out, const uint16_t *values, unsigned channels)
{
    for (unsigned channel = 0; channel < channels; channel++)
        out[channel] = (double)values[channel];
}

static inline void CharonShearBackS16(double *out, const int16_t *values, unsigned channels)
{
    for (unsigned channel = 0; channel < channels; channel++)
        out[channel] = (double)values[channel];
}

static inline void CharonShearBackU8(double *out, const uint8_t *values, unsigned channels)
{
    for (unsigned channel = 0; channel < channels; channel++)
        out[channel] = (double)values[channel];
}

static inline void CharonShearBackF16(double *out, const uint16_t *values, unsigned channels)
{
    for (unsigned channel = 0; channel < channels; channel++)
        out[channel] = (double)charon_half_to_float(values[channel]);
}

static inline unsigned CharonShearFlags(enum CharonPixelType type)
{
    switch (type) {
    case CharonARGB16F: case CharonCbCr16F: case CharonPlanar16F:
        return (unsigned)(kvImageBackgroundColorFill | kvImageEdgeExtend | kvImageDoNotTile
                          | kvImageHighQualityResampling | kvImageGetTempBufferSize
                          | kvImagePrintDiagnosticsToConsole | kvImageUseFP16Accumulator);
    default:
        return 0xFFFFFFFFu;
    }
}

static inline vImage_Error CharonShearReady(const vImage_Buffer *src, const vImage_Buffer *dest,
                                            const CharonResampleFilter *ours, int horizontal,
                                            vImagePixelCount offsetX, vImagePixelCount offsetY)
{
    if (CharonChannelsIsNull(src) || CharonChannelsIsNull(dest))
        return kvImageNullPointerArgument;
    if (!ours || !ours->row)
        return kvImageInvalidParameter;
    vImagePixelCount cross0 = horizontal ? offsetY : offsetX;
    vImagePixelCount dstCross = horizontal ? dest->height : dest->width;
    vImagePixelCount srcCross = horizontal ? src->height : src->width;
    if (cross0 + dstCross > srcCross)
        return kvImageBufferSizeMismatch;
    return kvImageNoError;
}

static inline vImage_Error CharonShearRun(const vImage_Buffer *src, const vImage_Buffer *dest,
                                          const CharonResampleFilter *filter, enum CharonPixelType type,
                                          int horizontal, double translate, double slope,
                                          vImagePixelCount offsetX, vImagePixelCount offsetY,
                                          const double *backColor, vImage_Flags flags)
{
    if (flags & ~CharonShearFlags(type))
        return kvImageUnknownFlagsBit;
    unsigned channels = CharonChannels(type);
    vImagePixelCount srcAlong = horizontal ? src->width : src->height;
    vImagePixelCount dstAlong = horizontal ? dest->width : dest->height;
    vImagePixelCount dstCross = horizontal ? dest->height : dest->width;
    vImagePixelCount along0 = horizontal ? offsetX : offsetY;
    vImagePixelCount cross0 = horizontal ? offsetY : offsetX;
    double reciprocal = filter->reciprocal;
    int extend = (flags & kvImageEdgeExtend) ? 1 : 0;

    double rowSum[CharonResampleMaxPhases];
    for (unsigned phase = 0; phase < filter->phases; phase++)
        rowSum[phase] = CharonResampleRowSum(filter, phase);

    const size_t pixelBytes = CharonBytesPerPixel(type);
#define CHARON_SHEAR_AT(img, along_, cross_) \
    ((uint8_t *)(img)->data + (size_t)(horizontal ? (cross_) : (along_)) * (img)->rowBytes \
     + (size_t)(horizontal ? (along_) : (cross_)) * pixelBytes)

    long long step = CharonResampleStep(filter);
    long long position = 0;
    if (!horizontal) {
        double oneMinusReciprocal = 1.0 - reciprocal;
        double scaled = (double)dstAlong * oneMinusReciprocal;
        scaled = scaled + reciprocal * translate;
        scaled = scaled + (double)filter->taps * -0.5;
        position = CharonResampleQ32((scaled + 1.0) * 4294967296.0);
    }

    for (vImagePixelCount cross = 0; cross < dstCross; cross++) {
        long sourceCross = (long)cross0 + (long)cross;
        if (horizontal) {
            double perRow = reciprocal * slope;
            double scaled = (double)((long)cross + 1 - (long)dstCross) * perRow;
            scaled = scaled - reciprocal * translate;
            scaled = scaled + (double)filter->taps * -0.5;
            position = CharonResampleQ32((scaled + 1.0) * 4294967296.0);
        } else if (slope != 0.0) {
            double scaled = ((double)cross + 0.5) * slope * reciprocal;
            scaled = scaled + (double)dstAlong * (1.0 - reciprocal);
            scaled = scaled + reciprocal * translate;
            scaled = scaled + (double)filter->taps * -0.5;
            position = CharonResampleQ32((scaled + 1.0) * 4294967296.0);
        }
        for (vImagePixelCount along = 0; along < dstAlong; along++) {
            unsigned phase;
            long base;
            CharonResamplePhase(filter, position, &phase, &base);
            base += (long)along0;
            const int16_t *row = filter->row + (size_t)phase * filter->width;
            long first = base - (long)filter->centre;
            double divisor = rowSum[phase];
            for (unsigned channel = 0; channel < channels; channel++) {
                double accumulator = 0.0;
                for (unsigned k = 0; k < filter->width; k++) {
                    long at = first + (long)k;
                    long weight = row[k];
                    if (!weight)
                        continue;
                    double value;
                    if (at < 0 || at >= (long)srcAlong) {
                        if (!extend) {
                            value = backColor[channel];
                        } else {
                            at = at < 0 ? 0 : (srcAlong ? (long)srcAlong - 1 : 0);
                            value = CharonChannelAt(CHARON_SHEAR_AT(src, at, sourceCross), 0, channel, type);
                        }
                    } else {
                        value = CharonChannelAt(CHARON_SHEAR_AT(src, at, sourceCross), 0, channel, type);
                    }
                    accumulator += (double)weight * value;
                }
                CharonChannelPut(CHARON_SHEAR_AT(dest, along, cross), 0, channel,
                                 divisor != 0.0 ? accumulator / divisor : 0.0, type);
            }
            position += step;
        }
    }
#undef CHARON_SHEAR_AT
    return kvImageNoError;
}
