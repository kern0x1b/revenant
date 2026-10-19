#pragma once

#import <Foundation/Foundation.h>
#include <math.h>
#include <stdint.h>

extern NSUInteger gCompared;
extern NSUInteger gMismatches;

static inline double RevenantNNOneUlp(double want)
{
    if (want == 0.0)
        return 0.0;
    float f = (float)want;
    uint32_t bits;
    memcpy(&bits, &f, sizeof bits);
    bits += (bits & 0x80000000u) ? 0xFFFFFFFFu : 1u;
    float next;
    memcpy(&next, &bits, sizeof next);
    double bound = (double)next - (double)f;
    return bound < 0.0 ? -bound : bound;
}

typedef enum {
    RevenantNNReduceMin = 0,
    RevenantNNReduceMax,
    RevenantNNReduceMean,
    RevenantNNReduceSum,
} RevenantNNReduceOp;

static void RevenantNNReduceReference(const char *name, const float *src, NSUInteger rows, NSUInteger cols,
                                    NSUInteger channels, int byColumn, int byFeatureChannel,
                                    RevenantNNReduceOp op, float weight, int weighted,
                                    const float *out, NSUInteger dstCols, NSUInteger dstChannels)
{
    NSUInteger span = byFeatureChannel ? channels : (byColumn ? rows : cols);
    NSUInteger spatial = byFeatureChannel ? rows * cols : (byColumn ? cols : rows);
    NSUInteger runs = byFeatureChannel ? spatial : spatial * channels;
    printf("reference %s runs %lu span %lu", name, (unsigned long)runs, (unsigned long)span);

    for (NSUInteger r = 0; r < runs; r++) {
        double total = 0.0;
        double smallest = 0.0, largest = 0.0;
        for (NSUInteger s = 0; s < span; s++) {
            NSUInteger at, c;
            if (byFeatureChannel) {
                at = r;
                c = s;
            } else {
                NSUInteger along = byColumn ? cols : rows;
                NSUInteger sp = r % along;
                c = r / along;
                at = byColumn ? sp + s * cols : sp * cols + s;
            }
            double v = (double)src[at * channels + c];
            if (byFeatureChannel && weighted && (op == RevenantNNReduceSum || op == RevenantNNReduceMean))
                v *= (double)weight;
            if (s == 0 || v < smallest) smallest = v;
            if (s == 0 || v > largest) largest = v;
            total += v;
        }
        double want;
        switch (op) {
            case RevenantNNReduceMin: want = smallest; break;
            case RevenantNNReduceMax: want = largest; break;
            case RevenantNNReduceMean: want = total / (double)span; break;
            case RevenantNNReduceSum: want = total; break;
        }

        NSUInteger x, y, c;
        if (byFeatureChannel) {
            x = r % cols;
            y = r / cols;
            c = 0;
        } else {
            NSUInteger along = byColumn ? cols : rows;
            NSUInteger sp = r % along;
            c = r / along;
            x = byColumn ? sp : 0;
            y = byColumn ? 0 : sp;
        }
        double have = (double)out[(y * dstCols + x) * dstChannels + c];

        gCompared++;
        int exact = (op == RevenantNNReduceMean) ? 0 : 1;
        double bound = exact ? 0.0 : RevenantNNOneUlp(want);
        if (exact ? (have != want) : (fabs(have - want) > bound)) {
            gMismatches++;
            printf("\n  MISMATCH %s run %lu reference %.9g port %.9g, %s\n", name, (unsigned long)r,
                   want, have, exact ? "exact (this operation selects or adds)" : "within one float32 ulp");
        }
        printf(" %.9g", want);
    }
    printf("\n");
}
