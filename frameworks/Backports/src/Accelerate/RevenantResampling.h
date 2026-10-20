#pragma once

#import <Accelerate/Accelerate.h>

enum {
    RevenantResampleSlot = (int)(sizeof(void *) >= 8 ? 8 : 4),
    RevenantResampleMaxPhases = 64
};

#define REVENANT_RESAMPLE_OFFSET(index) \
    ((index) == 0 ? (size_t)0 : (size_t)8 + (size_t)(RevenantResampleSlot) * (size_t)((index) - 1))

#define REVENANT_RESAMPLE_SLOT(object, index, type) \
    (*(type *)(void *)((const char *)(object) + REVENANT_RESAMPLE_OFFSET(index)))

typedef struct RevenantResampleFilter {
    double reciprocal;
    double scale;
    const int16_t *row;
    unsigned width;
    unsigned phases;
    unsigned exponent;
    unsigned taps;
    unsigned centre;
    unsigned offset;
} RevenantResampleFilter;

static inline int RevenantResampleFilterOf(ResamplingFilter filter, RevenantResampleFilter *out)
{
    out->reciprocal = 0.0;
    out->scale = 0.0;
    out->row = 0;
    out->width = 0;
    out->phases = 0;
    out->exponent = 0;
    out->taps = 0;
    out->centre = 0;
    out->offset = 0;
    if (!filter || !out)
        return 0;

    double reciprocal = REVENANT_RESAMPLE_SLOT(filter, 0, double);
    unsigned taps = REVENANT_RESAMPLE_SLOT(filter, 1, unsigned);
    unsigned floatStride = REVENANT_RESAMPLE_SLOT(filter, 2, unsigned);
    unsigned int16Stride = REVENANT_RESAMPLE_SLOT(filter, 3, unsigned);
    unsigned phases = REVENANT_RESAMPLE_SLOT(filter, 4, unsigned);
    unsigned exponent = REVENANT_RESAMPLE_SLOT(filter, 5, unsigned);
    unsigned offset = REVENANT_RESAMPLE_SLOT(filter, 6, unsigned);
    const char *table = (const char *)REVENANT_RESAMPLE_SLOT(filter, 7, const char *);

    if (!(reciprocal > 0.0) || taps < 1 || int16Stride < 2 || (int16Stride & 1))
        return 0;
    if (phases == 0 || phases > (unsigned)RevenantResampleMaxPhases || (phases & (phases - 1)) != 0)
        return 0;
    if (!table || table <= (const char *)filter)
        return 0;
    size_t inside = (size_t)(table - (const char *)filter);
    if (inside >= (size_t)offset)
        return 0;
    if (inside + (size_t)phases * (size_t)int16Stride > (size_t)offset)
        return 0;
    if ((size_t)offset != inside + (size_t)phases * (size_t)int16Stride)
        return 0;
    const char *base = REVENANT_RESAMPLE_SLOT(filter, 8, const char *);
    if (!base || base > table)
        return 0;
    size_t fromBase = (size_t)(table - base);
    if (fromBase != (size_t)floatStride * (size_t)(phases + 1))
        return 0;

    const int16_t *row = (const int16_t *)table;
    unsigned width = int16Stride / 2;
    int best = -(1 << 30);
    unsigned centre = 0;
    for (unsigned k = 0; k < width; k++) {
        int value = row[k];
        if (value > best) {
            best = value;
            centre = k;
        }
    }

    out->reciprocal = reciprocal;
    out->scale = 1.0 / reciprocal;
    out->row = row;
    out->width = width;
    out->phases = phases;
    out->exponent = exponent;
    out->taps = taps;
    out->centre = centre;
    out->offset = offset;
    return 1;
}

static inline void RevenantResamplePhase(const RevenantResampleFilter *filter, long long position,
                                       unsigned *phase, long *base)
{
    unsigned bits = filter->exponent;
    unsigned value = (bits >= 1u && bits <= 31u)
        ? (unsigned)(((unsigned long long)position & 0xffffffffULL) >> (32u - bits))
        : 0u;
    *phase = value & (filter->phases - 1u);
    *base = (long)(position >> 32) + (long)filter->centre;
}

static inline long long RevenantResampleQ32(double scaled)
{
    if (scaled >= 9223372036854775808.0)
        return (-9223372036854775807LL - 1);
    if (!(scaled > -9223372036854775808.0))
        return (-9223372036854775807LL - 1);
    return (long long)scaled;
}

static inline long long RevenantResampleStep(const RevenantResampleFilter *filter)
{
    return RevenantResampleQ32(filter->reciprocal * 4294967296.0);
}

static inline double RevenantResampleRowSum(const RevenantResampleFilter *filter, unsigned phase)
{
    const int16_t *row = filter->row + (size_t)phase * filter->width;
    long sum = 0;
    for (unsigned k = 0; k < filter->width; k++)
        sum += row[k];
    return (double)sum;
}
