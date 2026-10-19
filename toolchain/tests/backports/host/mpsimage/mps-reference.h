#ifndef REVENANT_MPS_REFERENCE_H
#define REVENANT_MPS_REFERENCE_H

#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

typedef enum {
    RevenantRefToZero,
    RevenantRefToZeroInverse,
    RevenantRefBinary,
    RevenantRefBinaryInverse,
    RevenantRefTruncate,
} RevenantRefThreshold;

typedef enum {
    RevenantRefAdd,
    RevenantRefSubtract,
    RevenantRefMultiply,
    RevenantRefDivide,
} RevenantRefOperation;

static NSUInteger gCompared = 0;
static NSUInteger gMismatches = 0;

static double RevenantOneUlp(double value)
{
    float f = (float)value;
    if (!(f == f))
        return (double)NAN;
    if (f == 0.0f)
        return (double)1.40129846e-45f;
    uint32_t bits;
    memcpy(&bits, &f, sizeof(bits));
    uint32_t negative = bits & 0x80000000u;
    uint32_t magnitude = negative ? ~bits + 1u : bits;
    uint32_t stepped = magnitude + 1u;
    if (negative)
        stepped = ~stepped + 1u;
    float next;
    memcpy(&next, &stepped, sizeof(next));
    double delta = (double)next - (double)f;
    return delta < 0.0 ? -delta : delta;
}

static double RevenantReferenceThreshold(RevenantRefThreshold which, double src, double threshold, double maximum)
{
    switch (which) {
    case RevenantRefToZero: return src > threshold ? src : 0.0;
    case RevenantRefToZeroInverse: return src > threshold ? 0.0 : src;
    case RevenantRefBinary: return src > threshold ? maximum : 0.0;
    case RevenantRefBinaryInverse: return src > threshold ? 0.0 : maximum;
    case RevenantRefTruncate: return src > threshold ? threshold : src;
    }
    return src;
}

static double RevenantReferenceArithmetic(RevenantRefOperation op, double primary, double secondary)
{
    switch (op) {
    case RevenantRefAdd: return primary + secondary;
    case RevenantRefSubtract: return primary - secondary;
    case RevenantRefMultiply: return primary * secondary;
    case RevenantRefDivide: return secondary == 0.0 ? 0.0 : primary / secondary;
    }
    return primary;
}

static void RevenantRecord(const char *name, NSUInteger index, double want, double got)
{
    gCompared++;
    if (want == 0.0 && got == 0.0)
        return;
    double ulp = RevenantOneUlp(want);
    if (fabs(got - want) > ulp) {
        gMismatches++;
        printf("  MISMATCH %s [%lu] reference %.9g port %.9g, one ulp %.3g\n",
               name, (unsigned long)index, want, got, ulp);
    }
}

static void RevenantCompareUnary(const char *name, const float *src, NSUInteger n, const float *out,
                              RevenantRefThreshold kind, double threshold, double maximum)
{
    printf("reference %s %lu", name, (unsigned long)n);
    for (NSUInteger i = 0; i < n; i++) {
        double want = RevenantReferenceThreshold(kind, (double)src[i], threshold, maximum);
        printf(" %.9g", want);
        RevenantRecord(name, i, want, (double)out[i]);
    }
    printf("\n");
}

static void RevenantCompareBinary(const char *name, const float *primary, const float *secondary,
                                NSUInteger n, const float *out, RevenantRefOperation op)
{
    printf("reference %s %lu", name, (unsigned long)n);
    for (NSUInteger i = 0; i < n; i++) {
        double want = RevenantReferenceArithmetic(op, (double)primary[i], (double)secondary[i]);
        printf(" %.9g", want);
        RevenantRecord(name, i, want, (double)out[i]);
    }
    printf("\n");
}

static void RevenantReferenceTranspose(const char *name, const float *src, NSUInteger srcWidth,
                                     NSUInteger srcHeight, const float *out, NSUInteger dstWidth,
                                     NSUInteger dstHeight)
{
    printf("reference %s %lu", name, (unsigned long)(dstWidth * dstHeight));
    for (NSUInteger row = 0; row < dstHeight; row++) {
        for (NSUInteger column = 0; column < dstWidth; column++) {
            double want = (double)src[column * srcWidth + row];
            printf(" %.9g", want);
            gCompared++;
            double got = (double)out[row * dstWidth + column];
            if (got != want) {
                gMismatches++;
                printf("\n  MISMATCH %s destination(%lu,%lu) reference %.9g port %.9g"
                       " (a transpose moves bits, so this is exact)\n",
                       name, (unsigned long)row, (unsigned long)column, want, got);
            }
        }
    }
    printf("\n");
}


static void RevenantReferenceImageCopyToMatrix(const char *name, const float *src, NSUInteger width,
                                             NSUInteger height, NSUInteger channels, NSUInteger images,
                                             MPSDataLayout layout, NSUInteger originRow, NSUInteger originColumn,
                                             const float *out, NSUInteger rowElements)
{
    NSUInteger perImage = width * height * channels;
    printf("reference %s layout %lu origin %lux%lu %lu", name, (unsigned long)layout,
           (unsigned long)originRow, (unsigned long)originColumn, (unsigned long)(perImage * images));
    for (NSUInteger image = 0; image < images; image++) {
        for (NSUInteger element = 0; element < perImage; element++) {
            NSUInteger y, x, channel;
            if (layout == MPSDataLayoutHeightxWidthxFeatureChannels) {
                channel = element % channels;
                NSUInteger pixel = element / channels;
                y = pixel / width;
                x = pixel % width;
            } else {
                y = (element / width) % height;
                x = element % width;
                channel = element / (width * height);
            }
            float want = src[image * perImage + (y * width + x) * channels + channel];
            gCompared++;
            double got = (double)out[(originRow + image) * rowElements + originColumn + element];
            if (got != (double)want) {
                gMismatches++;
                printf("\n  MISMATCH %s layout %lu image %lu element %lu reference %.9g port %.9g"
                       " (a copy moves bits, so this is exact)\n",
                       name, (unsigned long)layout, (unsigned long)image, (unsigned long)element,
                       (double)want, got);
            }
            printf(" %.9g", (double)want);
        }
    }
    printf("\n");
}

typedef enum {
    RevenantRefReduceMin,
    RevenantRefReduceMax,
    RevenantRefReduceMean,
    RevenantRefReduceSum,
} RevenantRefReduce;

static void RevenantReferenceImageReduce(const char *name, const float *src, NSUInteger rows, NSUInteger cols,
                                        NSUInteger srcX, NSUInteger srcY, int byColumn,
                                        RevenantRefReduce which, const float *out, NSUInteger values)
{
    printf("reference %s %lu", name, (unsigned long)values);
    NSUInteger runs = byColumn ? cols : rows;
    NSUInteger span = byColumn ? rows : cols;
    for (NSUInteger r = 0; r < runs; r++) {
        double total = 0.0;
        double smallest = 0.0, largest = 0.0;
        for (NSUInteger s = 0; s < span; s++) {
            NSUInteger y = byColumn ? srcY + s : srcY + r;
            NSUInteger x = byColumn ? srcX + r : srcX + s;
            if (y >= rows) y = rows - 1;
            if (x >= cols) x = cols - 1;
            float v = src[y * cols + x];
            if (s == 0 || (double)v < smallest) smallest = (double)v;
            if (s == 0 || (double)v > largest) largest = (double)v;
            total += (double)v;
        }
        double want;
        if (which == RevenantRefReduceMin) want = smallest;
        else if (which == RevenantRefReduceMax) want = largest;
        else if (which == RevenantRefReduceSum) want = total;
        else want = total / (double)span;
        gCompared++;
        double got = (double)out[r];
        double bound = (which == RevenantRefReduceMin || which == RevenantRefReduceMax) ? 0.0 : RevenantOneUlp(want);
        if (fabs(got - want) > bound) {
            gMismatches++;
            printf("\n  MISMATCH %s %s %lu reference %.9g port %.9g%s\n", name,
                   byColumn ? "column" : "row", (unsigned long)r, want, got,
                   bound == 0.0 ? ", exact" : ", one float32 ulp is the bound");
        }
        printf(" %.9g", want);
    }
    printf("\n");
}


static void RevenantReferenceImageConvolution(const char *name, const float *src, NSUInteger rows, NSUInteger cols,
                                             NSUInteger kernelWidth, NSUInteger kernelHeight,
                                             const float *weights, double bias,
                                             NSUInteger originX, NSUInteger originY,
                                             const float *out, NSUInteger values)
{
    printf("reference %s %lu", name, (unsigned long)values);
    NSUInteger halfW = kernelWidth / 2, halfH = kernelHeight / 2;
    for (NSUInteger r = 0; r < values; r++) {
        NSUInteger y = originY + r / cols;
        NSUInteger x = originX + r % cols;
        double total = 0.0;
        for (NSUInteger ky = 0; ky < kernelHeight; ky++) {
            for (NSUInteger kx = 0; kx < kernelWidth; kx++) {
                long sy = (long)(y + ky) - (long)halfH;
                long sx = (long)(x + kx) - (long)halfW;
                double sample = 0.0;
                if (sy >= 0 && sy < (long)rows && sx >= 0 && sx < (long)cols)
                    sample = (double)src[(NSUInteger)sy * cols + (NSUInteger)sx];
                total += (double)weights[ky * kernelWidth + kx] * sample;
            }
        }
        double want = total + bias;
        gCompared++;
        double got = (double)out[r];
        if (fabs(got - want) > RevenantOneUlp(want)) {
            gMismatches++;
            printf("\n  MISMATCH %s [%lu] reference %.9g port %.9g, one float32 ulp is the bound\n",
                   name, (unsigned long)r, want, got);
        }
        printf(" %.9g", want);
    }
    printf("\n");
}


static void RevenantReferenceImageMorphology(const char *name, const float *src, NSUInteger rows, NSUInteger cols,
                                            NSUInteger channels, NSUInteger kernelWidth, NSUInteger kernelHeight,
                                            const float *probe, int takeMax, NSUInteger originX, NSUInteger originY,
                                            const float *out, NSUInteger values)
{
    printf("reference %s %lu", name, (unsigned long)values);
    NSUInteger halfW = kernelWidth / 2, halfH = kernelHeight / 2;
    for (NSUInteger r = 0; r < values; r++) {
        NSUInteger y = originY + r / cols;
        NSUInteger x = originX + r % cols;
        for (NSUInteger channel = 0; channel < channels; channel++) {
            double best = 0.0;
            for (NSUInteger ky = 0; ky < kernelHeight; ky++) {
                for (NSUInteger kx = 0; kx < kernelWidth; kx++) {
                    long sy = (long)(y + ky) - (long)halfH;
                    long sx = (long)(x + kx) - (long)halfW;
                    if (sy < 0) sy = 0;
                    if (sx < 0) sx = 0;
                    if (sy >= (long)rows) sy = (long)rows - 1;
                    if (sx >= (long)cols) sx = (long)cols - 1;
                    double v = (double)src[((NSUInteger)sy * cols + (NSUInteger)sx) * channels + channel];
                    if (probe) v += (double)probe[ky * kernelWidth + kx];
                    if (kx == 0 && ky == 0) best = v;
                    else if (takeMax ? v > best : v < best) best = v;
                }
            }
            gCompared++;
            double got = (double)out[r * channels + channel];
            if (got != best) {
                gMismatches++;
                printf("\n  MISMATCH %s [%lu] channel %lu reference %.9g port %.9g, exact"
                       " (a maximum and a minimum select a value the source already holds)\n",
                       name, (unsigned long)r, (unsigned long)channel, best, got);
            }
            printf(" %.9g", best);
        }
    }
    printf("\n");
}


static void RevenantReferenceImageHistogram(const char *name, const unsigned char *rgba, NSUInteger rows,
                                          NSUInteger cols, NSUInteger bins, double lo, double hi,
                                          BOOL histogramForAlpha, const uint32_t *got, NSUInteger channels)
{
    printf("reference %s bins %lu range %g..%g", name, (unsigned long)bins, lo, hi);
    NSUInteger used = histogramForAlpha ? channels : (channels == 4 ? 3 : channels);
    for (NSUInteger c = 0; c < used; c++) {
        for (NSUInteger b = 0; b < bins; b++) {
            uint32_t want = 0;
            for (NSUInteger y = 0; y < rows; y++)
                for (NSUInteger x = 0; x < cols; x++) {
                    double v = (double)rgba[(y * cols + x) * 4 + c] / 255.0;
                    if (v < lo || v > hi)
                        continue;
                    NSUInteger bin = (NSUInteger)((v - lo) / (hi - lo) * (double)bins);
                    if (bin >= bins)
                        bin = bins - 1;
                    if (bin == b)
                        want++;
                }
            gCompared++;
            uint32_t have = got[c * bins + b];
            if (have != want) {
                gMismatches++;
                printf("\n  MISMATCH %s channel %lu bin %lu reference %lu port %lu, exact"
                       " (a histogram counts, so this is an integer)\n", name, (unsigned long)c,
                       (unsigned long)b, (unsigned long)want, (unsigned long)have);
            }
            printf(" %lu", (unsigned long)want);
        }
    }
    printf("\n");
}

#endif
