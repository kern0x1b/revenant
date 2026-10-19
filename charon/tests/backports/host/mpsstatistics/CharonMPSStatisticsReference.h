#pragma once

#import <Foundation/Foundation.h>
#include <math.h>
#include <stdint.h>
#include <string.h>

extern NSUInteger gCompared;
extern NSUInteger gMismatches;

static inline double CharonMPSStatisticsOneUlp(double want)
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
    CharonMPSStatisticsMinMax = 0,
    CharonMPSStatisticsMeanVar,
    CharonMPSStatisticsMean,
} CharonMPSStatisticsOp;

static void CharonMPSStatisticsReference(const char *name, const float *src, NSUInteger rows, NSUInteger cols,
                                         NSUInteger channels, CharonMPSStatisticsOp op, const float *dst)
{
    NSUInteger count = rows * cols * channels;
    double smallest = INFINITY, largest = -INFINITY, sum = 0.0;
    for (NSUInteger i = 0; i < count; i++) {
        double v = (double)src[i];
        if (v < smallest) smallest = v;
        if (v > largest) largest = v;
        sum += v;
    }
    double mean = count ? sum / (double)count : 0.0;
    double variance = 0.0;
    if (op != CharonMPSStatisticsMinMax && count) {
        double squared = 0.0;
        for (NSUInteger i = 0; i < count; i++) {
            double d = (double)src[i] - mean;
            squared += d * d;
        }
        variance = squared / (double)count;
    }

    int wanted;
    switch (op) {
        case CharonMPSStatisticsMinMax:
            printf("reference %s min %g max %g\n", name, smallest, largest);
            wanted = 2;
            break;
        case CharonMPSStatisticsMeanVar:
            printf("reference %s mean %g variance %g\n", name, mean, variance);
            wanted = 2;
            break;
        default:
            printf("reference %s mean %g\n", name, mean);
            wanted = 1;
            break;
    }

    double answer[2];
    double bound[2];
    answer[0] = smallest;
    answer[1] = largest;
    bound[0] = bound[1] = 0.0;
    if (op != CharonMPSStatisticsMinMax) {
        answer[0] = mean;
        answer[1] = variance;
        bound[0] = CharonMPSStatisticsOneUlp(mean);
        bound[1] = CharonMPSStatisticsOneUlp(variance);
    }
    for (int i = 0; i < wanted; i++) {
        double got = (double)dst[i];
        gCompared++;
        if (fabs(got - answer[i]) > bound[i]) {
            gMismatches++;
            printf("MISMATCH %s value %d: port %0.9g reference %0.9g bound %0.9g\n", name, i, got, answer[i], bound[i]);
        }
    }
}
