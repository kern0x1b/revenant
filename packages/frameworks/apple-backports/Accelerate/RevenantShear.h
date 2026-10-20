#pragma once

#import <Accelerate/Accelerate.h>
#include "RevenantChannels.h"
#include "RevenantResampling.h"
#include "RevenantVImageFixed.h"

enum RevenantPixelType {
    RevenantARGB16U, RevenantARGB16S, RevenantPlanar16U, RevenantPlanar16S, RevenantPlanar16F, RevenantPlanarF,
    RevenantCbCr8, RevenantCbCr16U, RevenantCbCr16S, RevenantCbCr16F, RevenantCbCrF, RevenantARGB16F, RevenantARGBFFFF,
    RevenantXRGB2101010W
};

static inline unsigned RevenantChannels(enum RevenantPixelType type)
{
    switch (type) {
    case RevenantARGB16U: case RevenantARGB16S: case RevenantARGB16F: case RevenantARGBFFFF: return 4;
    case RevenantCbCr8: case RevenantCbCr16U: case RevenantCbCr16S: case RevenantCbCr16F: case RevenantCbCrF: return 2;
    case RevenantXRGB2101010W: return 4;
    default: return 1;
    }
}

static inline size_t RevenantBytesPerPixel(enum RevenantPixelType type)
{
    switch (type) {
    case RevenantARGB16U: case RevenantARGB16S: case RevenantARGB16F: return 8;
    case RevenantARGBFFFF: return 16;
    case RevenantPlanar16U: case RevenantPlanar16S: case RevenantPlanar16F: return 2;
    case RevenantPlanarF: return 4;
    case RevenantCbCr8: return 2;
    case RevenantCbCr16U: case RevenantCbCr16S: case RevenantCbCr16F: return 4;
    case RevenantCbCrF: return 8;
    case RevenantXRGB2101010W: return 4;
    default: return 1;
    }
}

static inline double RevenantChannelAt(const void *row, vImagePixelCount pixel, unsigned channel,
                                     enum RevenantPixelType type)
{
    switch (type) {
    case RevenantARGB16U: return (double)((const uint16_t *)row)[pixel * 4 + channel];
    case RevenantARGB16S: return (double)((const int16_t *)row)[pixel * 4 + channel];
    case RevenantPlanar16U: return (double)((const uint16_t *)row)[pixel];
    case RevenantPlanar16S: return (double)((const int16_t *)row)[pixel];
    case RevenantCbCr8: return (double)((const uint8_t *)row)[pixel * 2 + channel];
    case RevenantCbCr16U: return (double)((const uint16_t *)row)[pixel * 2 + channel];
    case RevenantCbCr16S: return (double)((const int16_t *)row)[pixel * 2 + channel];
    case RevenantCbCr16F: return (double)revenant_half_to_float(((const uint16_t *)row)[pixel * 2 + channel]);
    case RevenantPlanar16F: return (double)revenant_half_to_float(((const uint16_t *)row)[pixel]);
    case RevenantARGB16F: return (double)revenant_half_to_float(((const uint16_t *)row)[pixel * 4 + channel]);
    case RevenantXRGB2101010W: return (double)((((const uint32_t *)row)[pixel] >> (channel * 10)) & 0x3FFu);
    case RevenantPlanarF: return (double)((const float *)row)[pixel];
    case RevenantCbCrF: return (double)((const float *)row)[pixel * 2 + channel];
    case RevenantARGBFFFF: return (double)((const float *)row)[pixel * 4 + channel];
    default: return 0.0;
    }
}

static inline double RevenantSaturate(double value, enum RevenantPixelType type)
{
    switch (type) {
    case RevenantARGB16U: case RevenantPlanar16U: case RevenantCbCr16U: case RevenantXRGB2101010W:
        return value < 0.0 ? 0.0 : (value > 65535.0 ? 65535.0 : value);
    case RevenantCbCr8:
        return value < 0.0 ? 0.0 : (value > 255.0 ? 255.0 : value);
    case RevenantARGB16S: case RevenantPlanar16S: case RevenantCbCr16S:
        return value < -32768.0 ? -32768.0 : (value > 32767.0 ? 32767.0 : value);
    default:
        return value;
    }
}

#define REVENANT_ROUND_HALF_UP(v) ((v) >= 0.0 ? floor((v) + 0.5) : ceil((v) - 0.5))

static inline void RevenantChannelPut(void *row, vImagePixelCount pixel, unsigned channel, double value,
                                    enum RevenantPixelType type)
{
    switch (type) {
    case RevenantARGB16U: ((uint16_t *)row)[pixel * 4 + channel] = (uint16_t)REVENANT_ROUND_HALF_UP(RevenantSaturate(value, type)); break;
    case RevenantARGB16S: ((int16_t *)row)[pixel * 4 + channel] = (int16_t)REVENANT_ROUND_HALF_UP(RevenantSaturate(value, type)); break;
    case RevenantPlanar16U: ((uint16_t *)row)[pixel] = (uint16_t)REVENANT_ROUND_HALF_UP(RevenantSaturate(value, type)); break;
    case RevenantPlanar16S: ((int16_t *)row)[pixel] = (int16_t)REVENANT_ROUND_HALF_UP(RevenantSaturate(value, type)); break;
    case RevenantCbCr8: ((uint8_t *)row)[pixel * 2 + channel] = (uint8_t)REVENANT_ROUND_HALF_UP(RevenantSaturate(value, type)); break;
    case RevenantCbCr16U: ((uint16_t *)row)[pixel * 2 + channel] = (uint16_t)REVENANT_ROUND_HALF_UP(RevenantSaturate(value, type)); break;
    case RevenantCbCr16S: ((int16_t *)row)[pixel * 2 + channel] = (int16_t)REVENANT_ROUND_HALF_UP(RevenantSaturate(value, type)); break;
    case RevenantCbCr16F: ((uint16_t *)row)[pixel * 2 + channel] = revenant_float_to_half((float)value); break;
    case RevenantPlanar16F: ((uint16_t *)row)[pixel] = revenant_float_to_half((float)value); break;
    case RevenantARGB16F: ((uint16_t *)row)[pixel * 4 + channel] = revenant_float_to_half((float)value); break;
    case RevenantXRGB2101010W: {
        uint32_t word = ((uint32_t *)row)[pixel], shift = channel * 10;
        word = (word & ~(0x3FFu << shift))
             | ((((uint32_t)REVENANT_ROUND_HALF_UP(RevenantSaturate(value, type))) & 0x3FFu) << shift);
        ((uint32_t *)row)[pixel] = word;
        break;
    }
    case RevenantPlanarF: ((float *)row)[pixel] = (float)value; break;
    case RevenantCbCrF: ((float *)row)[pixel * 2 + channel] = (float)value; break;
    case RevenantARGBFFFF: ((float *)row)[pixel * 4 + channel] = (float)value; break;
    default: break;
    }
}

static inline void RevenantShearBackU16(double *out, const uint16_t *values, unsigned channels)
{
    for (unsigned channel = 0; channel < channels; channel++)
        out[channel] = (double)values[channel];
}

static inline void RevenantShearBackS16(double *out, const int16_t *values, unsigned channels)
{
    for (unsigned channel = 0; channel < channels; channel++)
        out[channel] = (double)values[channel];
}

static inline void RevenantShearBackU8(double *out, const uint8_t *values, unsigned channels)
{
    for (unsigned channel = 0; channel < channels; channel++)
        out[channel] = (double)values[channel];
}

static inline void RevenantShearBackF16(double *out, const uint16_t *values, unsigned channels)
{
    for (unsigned channel = 0; channel < channels; channel++)
        out[channel] = (double)revenant_half_to_float(values[channel]);
}

static inline unsigned RevenantShearFlags(enum RevenantPixelType type)
{
    switch (type) {
    case RevenantARGB16F: case RevenantCbCr16F: case RevenantPlanar16F:
        return (unsigned)(kvImageBackgroundColorFill | kvImageEdgeExtend | kvImageDoNotTile
                          | kvImageHighQualityResampling | kvImageGetTempBufferSize
                          | kvImagePrintDiagnosticsToConsole | kvImageUseFP16Accumulator);
    default:
        return 0xFFFFFFFFu;
    }
}

static inline vImage_Error RevenantShearReady(const vImage_Buffer *src, const vImage_Buffer *dest,
                                            const RevenantResampleFilter *ours, int horizontal,
                                            vImagePixelCount offsetX, vImagePixelCount offsetY)
{
    if (RevenantChannelsIsNull(src) || RevenantChannelsIsNull(dest))
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

static inline vImage_Error RevenantShearRun(const vImage_Buffer *src, const vImage_Buffer *dest,
                                          const RevenantResampleFilter *filter, enum RevenantPixelType type,
                                          int horizontal, double translate, double slope,
                                          vImagePixelCount offsetX, vImagePixelCount offsetY,
                                          const double *backColor, vImage_Flags flags)
{
    if (flags & ~RevenantShearFlags(type))
        return kvImageUnknownFlagsBit;
    unsigned channels = RevenantChannels(type);
    vImagePixelCount srcAlong = horizontal ? src->width : src->height;
    vImagePixelCount dstAlong = horizontal ? dest->width : dest->height;
    vImagePixelCount dstCross = horizontal ? dest->height : dest->width;
    vImagePixelCount along0 = horizontal ? offsetX : offsetY;
    vImagePixelCount cross0 = horizontal ? offsetY : offsetX;
    double reciprocal = filter->reciprocal;
    int extend = (flags & kvImageEdgeExtend) ? 1 : 0;

    double rowSum[RevenantResampleMaxPhases];
    for (unsigned phase = 0; phase < filter->phases; phase++)
        rowSum[phase] = RevenantResampleRowSum(filter, phase);

    const size_t pixelBytes = RevenantBytesPerPixel(type);
#define REVENANT_SHEAR_AT(img, along_, cross_) \
    ((uint8_t *)(img)->data + (size_t)(horizontal ? (cross_) : (along_)) * (img)->rowBytes \
     + (size_t)(horizontal ? (along_) : (cross_)) * pixelBytes)

    long long step = RevenantResampleStep(filter);
    long long position = 0;
    if (!horizontal) {
        double oneMinusReciprocal = 1.0 - reciprocal;
        double scaled = (double)dstAlong * oneMinusReciprocal;
        scaled = scaled + reciprocal * translate;
        scaled = scaled + (double)filter->taps * -0.5;
        position = RevenantResampleQ32((scaled + 1.0) * 4294967296.0);
    }

    for (vImagePixelCount cross = 0; cross < dstCross; cross++) {
        long sourceCross = (long)cross0 + (long)cross;
        if (horizontal) {
            double perRow = reciprocal * slope;
            double scaled = (double)((long)cross + 1 - (long)dstCross) * perRow;
            scaled = scaled - reciprocal * translate;
            scaled = scaled + (double)filter->taps * -0.5;
            position = RevenantResampleQ32((scaled + 1.0) * 4294967296.0);
        } else if (slope != 0.0) {
            double scaled = ((double)cross + 0.5) * slope * reciprocal;
            scaled = scaled + (double)dstAlong * (1.0 - reciprocal);
            scaled = scaled + reciprocal * translate;
            scaled = scaled + (double)filter->taps * -0.5;
            position = RevenantResampleQ32((scaled + 1.0) * 4294967296.0);
        }
        for (vImagePixelCount along = 0; along < dstAlong; along++) {
            unsigned phase;
            long base;
            RevenantResamplePhase(filter, position, &phase, &base);
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
                            value = RevenantChannelAt(REVENANT_SHEAR_AT(src, at, sourceCross), 0, channel, type);
                        }
                    } else {
                        value = RevenantChannelAt(REVENANT_SHEAR_AT(src, at, sourceCross), 0, channel, type);
                    }
                    accumulator += (double)weight * value;
                }
                RevenantChannelPut(REVENANT_SHEAR_AT(dest, along, cross), 0, channel,
                                 divisor != 0.0 ? accumulator / divisor : 0.0, type);
            }
            position += step;
        }
    }
#undef REVENANT_SHEAR_AT
    return kvImageNoError;
}
