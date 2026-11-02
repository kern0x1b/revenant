#pragma once

#import <Accelerate/Accelerate.h>
#include <math.h>
#include <stdlib.h>
#include "RevenantVImageFixed.h"

typedef struct RevenantScaleAxis {
    long span;
    long *count;
    long *index;
    double *weight;
} RevenantScaleAxis;

static inline void RevenantScaleAxisFree(RevenantScaleAxis *axis)
{
    free(axis->count);
    free(axis->index);
    free(axis->weight);
    axis->count = NULL;
    axis->index = NULL;
    axis->weight = NULL;
}

static inline long RevenantScaleClamp(long index, long length)
{
    return index < 0 ? 0 : (index >= length ? length - 1 : index);
}

static inline void RevenantScaleTap(long *indices, double *weights, long *taps, double *total, long span, long index, double weight)
{
    if (*taps >= span)
        return;
    indices[*taps] = index;
    weights[*taps] = weight;
    *taps += 1;
    *total += weight;
}

static inline int RevenantScaleAxisBuild(RevenantScaleAxis *axis, long source, long target)
{
    double ratio = (double)source / (double)target;
    long span = (long)ceil(ratio > 1.0 ? ratio : 1.0) + 2;
    axis->span = span;
    axis->count = calloc((size_t)target, sizeof(long));
    axis->index = calloc((size_t)target * (size_t)span, sizeof(long));
    axis->weight = calloc((size_t)target * (size_t)span, sizeof(double));
    if (!axis->count || !axis->index || !axis->weight) {
        RevenantScaleAxisFree(axis);
        return 0;
    }
    for (long i = 0; i < target; i++) {
        long *indices = axis->index + i * span;
        double *weights = axis->weight + i * span;
        long taps = 0;
        double total = 0.0;
        if (ratio > 1.0) {
            double start = (double)i * ratio;
            double end = (double)(i + 1) * ratio;
            for (long j = (long)floor(start); j < (long)ceil(end) && j < source; j++) {
                double low = start > (double)j ? start : (double)j;
                double high = end < (double)(j + 1) ? end : (double)(j + 1);
                if (high > low)
                    RevenantScaleTap(indices, weights, &taps, &total, span, j, high - low);
            }
        } else {
            double centre = ((double)i + 0.5) * ratio - 0.5;
            long left = (long)floor(centre);
            for (long j = left; j <= left + 1; j++) {
                double weight = 1.0 - fabs((double)j - centre);
                if (weight > 0.0)
                    RevenantScaleTap(indices, weights, &taps, &total, span, RevenantScaleClamp(j, source), weight);
            }
        }
        for (long k = 0; k < taps; k++)
            weights[k] = total > 0.0 ? weights[k] / total : 0.0;
        for (long k = 0; k < taps; k++)
            indices[k] = RevenantScaleClamp(indices[k], source);
        axis->count[i] = taps;
    }
    return 1;
}

static inline vImage_Error RevenantScaleRun16(const vImage_Buffer *src, const vImage_Buffer *dest, unsigned channels, vImage_Flags flags)
{
    const vImage_Flags allowed = kvImageDoNotTile | kvImageHighQualityResampling | kvImageGetTempBufferSize | kvImagePrintDiagnosticsToConsole;
    if (flags & ~allowed)
        return kvImageUnknownFlagsBit;
    if (flags & kvImageGetTempBufferSize)
        return kvImageNoError;
    if (!src || !dest || !src->data || !dest->data)
        return kvImageNullPointerArgument;
    if (dest->width == 0 || dest->height == 0)
        return kvImageNoError;
    if (src->width == 0 || src->height == 0)
        return kvImageInvalidParameter;
    size_t pixel = (size_t)channels * 2;
    if (src->rowBytes < src->width * pixel || dest->rowBytes < dest->width * pixel)
        return kvImageInvalidParameter;

    RevenantScaleAxis horizontal = { 0, NULL, NULL, NULL };
    RevenantScaleAxis vertical = { 0, NULL, NULL, NULL };
    float *middle = NULL;
    vImage_Error status = kvImageMemoryAllocationError;
    if (!RevenantScaleAxisBuild(&horizontal, (long)src->width, (long)dest->width))
        goto done;
    if (!RevenantScaleAxisBuild(&vertical, (long)src->height, (long)dest->height))
        goto done;
    middle = malloc(sizeof(float) * (size_t)src->height * (size_t)dest->width * channels);
    if (!middle)
        goto done;

    for (vImagePixelCount y = 0; y < src->height; y++) {
        const uint16_t *in = (const uint16_t *)((const uint8_t *)src->data + y * src->rowBytes);
        float *out = middle + (size_t)y * dest->width * channels;
        for (vImagePixelCount x = 0; x < dest->width; x++) {
            for (unsigned c = 0; c < channels; c++) {
                double sum = 0.0;
                for (long k = 0; k < horizontal.count[x]; k++) {
                    long slot = (long)x * horizontal.span + k;
                    sum += horizontal.weight[slot] * (double)in[(size_t)horizontal.index[slot] * channels + c];
                }
                out[x * channels + c] = (float)sum;
            }
        }
    }

    for (vImagePixelCount y = 0; y < dest->height; y++) {
        uint16_t *out = (uint16_t *)((uint8_t *)dest->data + y * dest->rowBytes);
        for (vImagePixelCount x = 0; x < dest->width; x++) {
            for (unsigned c = 0; c < channels; c++) {
                double sum = 0.0;
                for (long k = 0; k < vertical.count[y]; k++) {
                    long slot = (long)y * vertical.span + k;
                    sum += vertical.weight[slot] * (double)middle[((size_t)vertical.index[slot] * dest->width + x) * channels + c];
                }
                out[x * channels + c] = (uint16_t)revenant_sat(sum, 0, 65535);
            }
        }
    }
    status = kvImageNoError;

done:
    free(middle);
    RevenantScaleAxisFree(&horizontal);
    RevenantScaleAxisFree(&vertical);
    return status;
}
