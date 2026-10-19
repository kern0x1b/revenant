// CharonNNReduceReference.h - the reference MPSNNReduce is checked against, in plain C.
//
// This is a NEW file, not an addition to mps-reference.h, for the reason the workspace contract gives:
// MPSNNReduce lives in MPSNeuralNetwork.framework and the MPSImageReduce rows live in MPSImage.framework,
// and one reference header shared by both would be a file whose contents depend on which framework's
// surface the compiler read - the same second-answer problem CharonMPSImage.h:41-44 records when it
// removed a second data-type table.
//
// WHAT THE REFERENCE IS, and what it is not. It is the header's own sentences turned into arithmetic:
//   MPSNNReduce.h:66   the minimum taken over each row of the image, one answer per row
//   MPSNNReduce.h:93   the same for each column's minimum
//   MPSNNReduce.h:119  across the feature channels, one answer per pixel
//   MPSNNReduce.h:173/:199/:225  max, for each row / column / feature channel
//   MPSNNReduce.h:279/:305/:331  mean, for each row / column / feature channel
//   MPSNNReduce.h:357/:383/:410  sum, for each row / column / feature channel
// so the COUNT of answers is the header's: one per row, one per column, one per pixel. It is written
// independently of MPSNNReduce11.m - it takes the source values and the operation as arguments and
// never names the port's class - so a case that agrees is two implementations of one sentence and not
// one implementation compared with itself.
//
// WHERE THE CHANNEL GOES is the one thing the header does not state, and it is decided the same way in
// both: an MPSImage's row is a row of ONE feature channel (MPSCNNKernel carries
// sourceFeatureChannelOffset precisely because a kernel walks one channel at a time), so a row or column
// reduction answers one value per row or column PER CHANNEL and keeps the channel count, while a
// feature-channel reduction crosses channels and so answers one value per pixel into one plane.
//
// WHAT IS NOT HERE: a claim about the release's own numbers. This host's AGX family lacks
// computeCommandEncoderWithDispatchType: and the release's own kernel dies encoding with
// '-[AGXG16XFamilyCommandBuffer mtlnext computeCommandEncoderWithDispatchType:]': unrecognized
// selector, so there is no oracle for the release and no number below is one. What the cases establish
// is that the port's walk is the header's sentence, element for element.
//
// THE BOUND, and why it differs by operation. min, max and sum select or add values the source already
// holds, so they are EXACT and are compared for equality - a copy that moved a bit is a copy that moved
// a bit, and a tolerance here could only hide it. mean divides, and dividing cannot be exact in binary,
// so the sum is taken in double and divided once and the result is within one whole float32 ulp of the
// answer. That is the same split mps-reference.h:276-283 states for the MPSImageReduce rows, applied
// here rather than reinvented: a narrower bound fails every mean case and a wider one would let a real
// defect through a sum.
#pragma once

#import <Foundation/Foundation.h>
#include <math.h>
#include <stdint.h>

extern NSUInteger gCompared;
extern NSUInteger gMismatches;

// One whole float32 ulp of `want`. The same function mps-reference.h uses, repeated here rather than
// included: that header is in the MPSImage framework's surface and this one is in MPSNeuralNetwork's,
// and reaching across would make one file's contents depend on the other's framework.
static inline double CharonNNOneUlp(double want)
{
    if (want == 0.0)
        return 0.0;
    float f = (float)want;
    uint32_t bits;
    memcpy(&bits, &f, sizeof bits);
    // step to the NEXT representable float32, so the bound is "how far one answer may be from another"
    // and not a fraction of the value
    bits += (bits & 0x80000000u) ? 0xFFFFFFFFu : 1u;
    float next;
    memcpy(&next, &bits, sizeof next);
    double bound = (double)next - (double)f;
    return bound < 0.0 ? -bound : bound;
}

typedef enum {
    CharonNNReduceMin = 0,
    CharonNNReduceMax,
    CharonNNReduceMean,
    CharonNNReduceSum,
} CharonNNReduceOp;

// The reduce, in plain C over the source values. `src` is the window in the release's own layout,
// Height x Width x FeatureChannels, so `src[(y * cols + x) * channels + c]` is one value - which is
// the layout MPSCNNKernel's own channels and CharonMPSCnnPlane already use.
//
// `out` receives the answers in the layout MPSNNReduce11.m writes them in, and the layout is derived
// from the same three rules on both sides: a row run's values go down the destination's first column, a
// column run's along its first row, a feature-channel run's fill the destination row-major, and a row
// or column run carries the channel it reduced.
// `weighted` says whether the weight applies at all, and the case sets it only for the ONE class that
// declares the property. The header puts `weight` on MPSNNReduceFeatureChannelsSum alone
// (MPSNNReduce.h:413-420) and the release's own cache agrees - of the twelve concrete classes only
// that one lists -weight and -setWeight: - so MPSNNReduceFeatureChannelsMean has no weight to set and
// a mean that is halved by one is a mean of a different kernel.
//
// `dstCols` and `dstChannels` are the DESTINATION's shape, not the source's: a row or column
// reduction's destination is 1 wide and a feature-channel one's holds a single plane, and indexing
// `out` with the source's column count reads the wrong element for every run after the first. That
// was this reference's first defect, and it is why both shapes are named rather than one.
static void CharonNNReduceReference(const char *name, const float *src, NSUInteger rows, NSUInteger cols,
                                    NSUInteger channels, int byColumn, int byFeatureChannel,
                                    CharonNNReduceOp op, float weight, int weighted,
                                    const float *out, NSUInteger dstCols, NSUInteger dstChannels)
{
    NSUInteger span = byFeatureChannel ? channels : (byColumn ? rows : cols);
    NSUInteger spatial = byFeatureChannel ? rows * cols : (byColumn ? cols : rows);
    NSUInteger runs = byFeatureChannel ? spatial : spatial * channels;
    printf("reference %s runs %lu span %lu", name, (unsigned long)runs, (unsigned long)span);

    for (NSUInteger r = 0; r < runs; r++) {
        double total = 0.0;
        // Seeded from the first value OF THIS RUN, not from src[0]. Seeding from src[0] reports the
        // minimum of the whole window for every run after the first, which mps-reference.h:300-302
        // records as the first version's defect for the MPSImageReduce rows.
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
            // MPSNNReduce.h:414-420: the weight multiplies each feature channel's value to compute a
            // weighted SUM OR MEAN, so it applies to those two operations and to a min or a max not at
            // all. This reference had it applying to all four, which made it report -0.5 for the
            // weighted minimum of a pixel whose smallest channel is -1, and the port was right.
            if (byFeatureChannel && weighted && (op == CharonNNReduceSum || op == CharonNNReduceMean))
                v *= (double)weight;
            if (s == 0 || v < smallest) smallest = v;
            if (s == 0 || v > largest) largest = v;
            total += v;
        }
        double want;
        switch (op) {
            case CharonNNReduceMin: want = smallest; break;
            case CharonNNReduceMax: want = largest; break;
            case CharonNNReduceMean: want = total / (double)span; break;
            case CharonNNReduceSum: want = total; break;
        }

        // where this run's answer is in `out`, by the same three rules
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
        int exact = (op == CharonNNReduceMean) ? 0 : 1;
        double bound = exact ? 0.0 : CharonNNOneUlp(want);
        if (exact ? (have != want) : (fabs(have - want) > bound)) {
            gMismatches++;
            printf("\n  MISMATCH %s run %lu reference %.9g port %.9g, %s\n", name, (unsigned long)r,
                   want, have, exact ? "exact (this operation selects or adds)" : "within one float32 ulp");
        }
        printf(" %.9g", want);
    }
    printf("\n");
}
