// CharonMPSStatisticsReference.h - the reference the MPSImageStatistics kernels are checked against,
// in plain C.
//
// WHAT THE REFERENCE IS, and what it is not. It is the header's own sentences turned into arithmetic:
//   MPSImageStatistics.h:18  the lowest and highest pixel values inside the region chosen
//   MPSImageStatistics.h:19  the minimum is written at pixel (0, 0)
//   MPSImageStatistics.h:20  the maximum is written at pixel (1, 0)
//   MPSImageStatistics.h:66  the mean and variance inside the region chosen
//   MPSImageStatistics.h:114 the mean inside the region chosen
// It is written independently of MPSImageStatistics11.m - it takes the source values and says which
// kernel to compute - and it never names the port's class, so a case that agrees is two
// implementations of one sentence and not one implementation compared with itself.
//
// WHAT IS NOT HERE: a claim about the release's own numbers. This host's AGX family lacks
// computeCommandEncoderWithDispatchType: and the release's own kernel dies encoding with
// '-[AGXG16XFamilyCommandBuffer mtlnext computeCommandEncoderWithDispatchType:]': unrecognized selector,
// so there is no oracle for the release here and no number below is one. What the cases establish is
// that the port's walk is the header's sentence, element for element.
//
// THE BOUND, and why it differs by kernel. A minimum and a maximum SELECT values the source already
// holds, so they are exact and are compared for EQUALITY - a copy that moved a bit is a copy that moved
// a bit, and a tolerance here could only hide it. A mean and a variance divide, and dividing cannot be
// exact in binary, so each sum is taken in double and divided ONCE and the answer is within one whole
// float32 ulp of the truth. That is the same split mps-reference.h and CharonNNReduceReference.h state
// for the reduce families, applied here rather than reinvented.
//
// WHERE THE PAIR GOES is the header's sentence for the min/max (:19-20) and this file's choice for the
// mean/variance pair, which the header does not place: along the first row, mean then variance. The
// choice is written into the port's rows and it is the SAME choice here, so the two agree by
// construction and the cases below do not pretend the header settled it.
#pragma once

#import <Foundation/Foundation.h>
#include <math.h>
#include <stdint.h>
#include <string.h>

extern NSUInteger gCompared;
extern NSUInteger gMismatches;

// One whole float32 ulp of `want`, the bound the dividing kernels are held to. Repeated from
// CharonNNReduceReference.h rather than included: that header belongs to the MPSNNReduce harness and
// this one to MPSImageStatistics, and one shared header would make a file's contents depend on which
// harness included it first.
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
    CharonMPSStatisticsMinMax = 0,   // the min at 0, the max at 1
    CharonMPSStatisticsMeanVar,      // the mean at 0, the variance at 1
    CharonMPSStatisticsMean,         // the mean at 0
} CharonMPSStatisticsOp;

// The statistics of `src`, which is the window in the release's own layout Height x Width x
// FeatureChannels: `src[(y * cols + x) * channels + c]` is one value, the layout CharonMPSCnnPixel and
// CharonMPSImageIndex already use on the port side.
//
// `dst` is the destination's whole plane as the case wrote it, and the two answers are compared at
// index 0 and 1 (or 0 alone), which is where MPSImageStatistics.h:19-20 puts the min and the max. The
// VARIANCE is the mean of the squared deviations - sum((x - mean)^2) / count - and not the mean of the
// squares minus the square of the mean: the two differ in the last bits on any input where they differ
// at all, and the second form is not what "the variance" means.
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
        // A dividing kernel: one whole float32 ulp.
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