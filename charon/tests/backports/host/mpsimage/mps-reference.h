// mps-reference.h - the reference the MPSImage cases are checked against, computed from the release's
// own stated formulas and NOT from this port.
//
// WHY A REFERENCE IN C AND NOT THE HOST'S KERNEL. The host cannot be the oracle on this machine: the
// release's own MPSImageThresholdToZero resolves, by dladdr on its encode method, to
//
//   /System/Library/Frameworks/MetalPerformanceShaders.framework/Versions/A/Frameworks/MPSImage.framework/…
//
// and then the process dies with
//
//   '-[AGXG16XFamilyCommandBuffer mtlnext computeCommandEncoderWithDispatchType:]': unrecognized selector
//
// because this host's AGX family does not implement the encoder selector the framework calls. It answers
// nothing here, so the reference is the header's formula, computed in this file, and every registry row for
// this family says so in its reason.
//
// THE FORMULAS, as the headers state them, cited by file and line so a reader can check them:
//
//   MPSImageThreshold.h:194  MPSImageThresholdToZero         dst = src > threshold ? src : 0
//   MPSImageThreshold.h:246  MPSImageThresholdToZeroInverse  dst = src > threshold ? 0 : src
//   MPSImageThreshold.h:141  MPSImageThresholdTruncate       dst = src > threshold ? threshold : src
//   MPSImageThreshold.h:21   MPSImageThresholdBinary         dst = src > threshold ? maximum : 0
//   MPSImageThreshold.h:81   MPSImageThresholdBinaryInverse  dst = src > threshold ? 0 : maximum
//   MPSImageMath.h           MPSImageArithmetic              primary*primaryScale OP secondary*secondaryScale + bias
//
// The comparison is a whole float32 ulp of the expected answer, because these kernels accumulate in double
// and store float32: the difference between "the port is right" and "the port is one rounding off" is
// exactly that, and a tolerance wider than it would hide a real defect while a narrower one would fail
// every case.
#ifndef CHARON_MPS_REFERENCE_H
#define CHARON_MPS_REFERENCE_H

#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

// Which of the five thresholds a case runs, and which of the four arithmetic operations.
typedef enum {
    CharonRefToZero,
    CharonRefToZeroInverse,
    CharonRefBinary,
    CharonRefBinaryInverse,
    CharonRefTruncate,
} CharonRefThreshold;

typedef enum {
    CharonRefAdd,
    CharonRefSubtract,
    CharonRefMultiply,
    CharonRefDivide,
} CharonRefOperation;

// How many elements have been compared and how many were further than one ulp from the reference. The
// case returns non-zero on any, so a regression cannot pass the harness.
static NSUInteger gCompared = 0;
static NSUInteger gMismatches = 0;

// One float32 ulp at `value`, as a difference. The bit pattern is put in the order that increases with
// magnitude - a negative float's pattern is reflected about zero first - stepped by one, and reflected
// back, so the answer is the spacing on the side of the value where the spacing is. A NaN has no spacing
// and says so; a zero's is the smallest denormal.
static double CharonOneUlp(double value)
{
    float f = (float)value;
    if (!(f == f))
        return (double)NAN;                  // nothing is within any bound of a NaN
    if (f == 0.0f)
        return (double)1.40129846e-45f;      // the smallest denormal
    uint32_t bits;
    memcpy(&bits, &f, sizeof(bits));
    uint32_t negative = bits & 0x80000000u;
    uint32_t magnitude = negative ? ~bits + 1u : bits;   // the value's own order
    uint32_t stepped = magnitude + 1u;
    if (negative)
        stepped = ~stepped + 1u;                          // back into the negative half
    float next;
    memcpy(&next, &stepped, sizeof(next));
    double delta = (double)next - (double)f;
    return delta < 0.0 ? -delta : delta;
}

// The five, as the header's five formulas.
static double CharonReferenceThreshold(CharonRefThreshold which, double src, double threshold, double maximum)
{
    switch (which) {
    case CharonRefToZero: return src > threshold ? src : 0.0;
    case CharonRefToZeroInverse: return src > threshold ? 0.0 : src;
    case CharonRefBinary: return src > threshold ? maximum : 0.0;
    case CharonRefBinaryInverse: return src > threshold ? 0.0 : maximum;
    case CharonRefTruncate: return src > threshold ? threshold : src;
    }
    return src;
}

// The four, at the header's default scales of one and a bias of zero, which is what the cases build.
static double CharonReferenceArithmetic(CharonRefOperation op, double primary, double secondary)
{
    switch (op) {
    case CharonRefAdd: return primary + secondary;
    case CharonRefSubtract: return primary - secondary;
    case CharonRefMultiply: return primary * secondary;
    case CharonRefDivide: return secondary == 0.0 ? 0.0 : primary / secondary;
    }
    return primary;
}

static void CharonRecord(const char *name, NSUInteger index, double want, double got)
{
    gCompared++;
    if (want == 0.0 && got == 0.0)
        return;
    double ulp = CharonOneUlp(want);
    if (fabs(got - want) > ulp) {
        gMismatches++;
        printf("  MISMATCH %s [%lu] reference %.9g port %.9g, one ulp %.3g\n",
               name, (unsigned long)index, want, got, ulp);
    }
}

// CharonCompareUnary: the five threshold cases. `src` is what the case fed in and `out` is what the port
// answered, `n` elements of each.
static void CharonCompareUnary(const char *name, const float *src, NSUInteger n, const float *out,
                              CharonRefThreshold kind, double threshold, double maximum)
{
    printf("reference %s %lu", name, (unsigned long)n);
    for (NSUInteger i = 0; i < n; i++) {
        double want = CharonReferenceThreshold(kind, (double)src[i], threshold, maximum);
        printf(" %.9g", want);
        CharonRecord(name, i, want, (double)out[i]);
    }
    printf("\n");
}

// CharonCompareBinary: the four arithmetic cases, over the two images the case built.
static void CharonCompareBinary(const char *name, const float *primary, const float *secondary,
                                NSUInteger n, const float *out, CharonRefOperation op)
{
    printf("reference %s %lu", name, (unsigned long)n);
    for (NSUInteger i = 0; i < n; i++) {
        double want = CharonReferenceArithmetic(op, (double)primary[i], (double)secondary[i]);
        printf(" %.9g", want);
        CharonRecord(name, i, want, (double)out[i]);
    }
    printf("\n");
}

// CharonReferenceTranspose: the transpose of a region, from the header's own words.
//
//   MPSImageTranspose.h:16   the header says it transposes an image
//   MPSImageTranspose.h:18   the kernel accepts unsigned and signed integer textures as well as normalized and float ones.
//   MPSImageTranspose.h:21   MPSImageTranspose : MPSUnaryImageKernel
//   MPSImageKernel.h:141-144 clipRect names the MTLRegion of the destination that is overwritten. If it does not lie wholly within the destination
//                            image, only its overlap with the destination is used. The default, MPSRectNoClip, means the whole image.
//
// So: destination(row, column) takes source(column, row), over the intersection of the clip rectangle
// with the destination, and MPSRectNoClip is the whole destination. The header says "transposes" and
// nothing more about the arithmetic - there is none, and this is the whole of what the kernel computes.
//
// The value moves unchanged, so the reference is the same array read at the transposed index: there is no
// arithmetic to differ by an ulp, and `CharonCompareTranspose` therefore compares for equality rather
// than against a bound, and a single bit of difference is a failure.
static void CharonReferenceTranspose(const char *name, const float *src, NSUInteger srcWidth,
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


// MPSImageCopyToMatrix, from MPSImageCopy.h:19-24: the kernel copies image data into a matrix, one image's data per row. The data layout fixes how the feature channels are placed in the matrix, and a batch of images
// occupies several rows, one for each image. And the two orders, as MPSImage.h:300-303
// gives them in the surface's own comments:
//   MPSDataLayoutFeatureChannelsxHeightxWidth   [imageNum][featureChannels][imageHeight][imageWidth]
//   MPSDataLayoutHeightxWidthxFeatureChannels   [imageNum][imageHeight][imageWidth][featureChannels]
// The default at MPSImageCopy.h:37 is MPSDataLayoutFeatureChannelsxHeightxWidth.
//
// So image (y, x, channel) lands at element
//   channel * width * height + y * width + x        in MPSDataLayoutFeatureChannelsxHeightxWidth
//   (y * width + x) * channels + channel            in MPSDataLayoutHeightxWidthxFeatureChannels
// in the row the kernel's origin x names, plus the image's own index - one row per image, MPSImageCopy.h:22-23
// - each row `rowElements` long, which MPSImageCopy.h:26-29 requires to be at least width * height *
// featureChannels.
//
// A copy moves the bits, so this compares exactly, like the transpose: one bit of difference is a failure
// and there is no tolerance. `layout` is the order the kernel was asked for, so the same call checks both
// of the header's two orders - and the two differ only where there is more than one feature channel, which
// is why the case's image has two. `originRow` and `originColumn` are the kernel's destinationMatrixOrigin
// of MPSImageCopy.h:23, and the element is read out of the matrix's own row, so a kernel that wrote at the
// wrong place reads back as a mismatch instead of passing.
static void CharonReferenceImageCopyToMatrix(const char *name, const float *src, NSUInteger width,
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

// MPSImageReduce, from MPSImageReduce.h of the iPhoneOS 26.2 surface: four reductions over a row or a
// column - min, max, mean, sum. Nine rows owe this family: MPSImageReduceUnary abstract, and RowMin,
// ColumnMin, RowMax, ColumnMax, RowMean, ColumnMean, RowSum, ColumnSum.
//
// What the header says, at :53, :74, :91, :108, :125, :142, :159 and :176: the Row classes return "the
// mininmum value for each row of an image" (the release's own spelling), "the maximum value for each
// row", "the mean value for each row", "the sum for each row"; the Column classes say the same for each
// column. So a row reduction over a rows x cols image answers `rows` values and a column reduction
// answers `cols`. That much is the header's wording and it is what fixes the count.
//
// The read window is MPSImageReduce.h:31-42's clipRectSource, the source rectangle to read. When it does not lie wholly
// inside the source image, only its overlap with the image is used, and it takes the place of the offset parameter, which this filter
// ignores; with no clip set, the whole source texture is read. So `offset` does not enter this reduction at all - unlike every other unary kernel in this
// package - and clipRectSource is INTERSECTED with the image rather than applied on its own. That is
// why the indices below are clamped to the image and not used raw: the reference models the
// intersection rather than assuming a caller passes a rectangle that fits.
//
// `clipRect` is a different thing and is NOT the read window. MPSImageReduce.h:38-40: clipRect sets where the min and max values land in the destination, and its
// width must be at least 2 with a height of at least 1. That is
// where the write lands, and the two bounds are a precondition the kernel refuses, not a result.
//
// What the header does NOT say is the destination's shape. Each class fixes how many values there are
// and not their width or height. It cannot be measured here - this host's AGX family lacks
// computeCommandEncoderWithDispatchType: and the release's own kernel dies encoding - so the case builds
// the one-by-rows and cols-by-one destinations the class names imply and says so, rather than claiming
// it measured the release. Every row of this family carries that AGX reason.
//
// min, max and sum are compared for EQUALITY: they select or add values the source already holds, so a
// copy that moved a bit is a copy that moved a bit. mean divides, and dividing cannot be exact in
// binary, so it is compared with the same bound the rest of this file uses - one whole float32 ulp,
// CharonOneUlp - and that bound is stated rather than left implicit. A mean sums in double and divides
// once, so one float32 ulp is the whole of its error and not a slackened check.
typedef enum {
    CharonRefReduceMin,
    CharonRefReduceMax,
    CharonRefReduceMean,
    CharonRefReduceSum,
} CharonRefReduce;

static void CharonReferenceImageReduce(const char *name, const float *src, NSUInteger rows, NSUInteger cols,
                                        NSUInteger srcX, NSUInteger srcY, int byColumn,
                                        CharonRefReduce which, const float *out, NSUInteger values)
{
    printf("reference %s %lu", name, (unsigned long)values);
    NSUInteger runs = byColumn ? cols : rows;
    NSUInteger span = byColumn ? rows : cols;
    for (NSUInteger r = 0; r < runs; r++) {
        double total = 0.0;
        // Seeded from the first element OF THIS RUN, not from src[0]. The first version seeded from
        // src[0] and therefore reported the minimum of the WHOLE image for every row after the first -
        // the differential caught it, naming rows 1 and 2 of reduce-row-min as -1.5 when the values were
        // 0.5 and -0.75, which is how a reference bug is distinguishable from a kernel bug: the kernel's
        // numbers were the right ones.
        double smallest = 0.0, largest = 0.0;
        for (NSUInteger s = 0; s < span; s++) {
            NSUInteger y = byColumn ? srcY + s : srcY + r;
            NSUInteger x = byColumn ? srcX + r : srcX + s;
            if (y >= rows) y = rows - 1;      // clipRectSource is intersected with the image, :33-34
            if (x >= cols) x = cols - 1;
            float v = src[y * cols + x];
            if (s == 0 || (double)v < smallest) smallest = (double)v;
            if (s == 0 || (double)v > largest) largest = (double)v;
            total += (double)v;
        }
        double want;
        if (which == CharonRefReduceMin) want = smallest;
        else if (which == CharonRefReduceMax) want = largest;
        else if (which == CharonRefReduceSum) want = total;
        else want = total / (double)span;
        gCompared++;
        double got = (double)out[r];
        // min and max SELECT a value the source already holds, so they are exact. mean and sum ADD, and
        // the sum is stored back as a float32, so both are within one float32 ulp of the double total -
        // the same bound the arithmetic comparator in this file uses. Claiming a sum was exact was the
        // second thing the differential caught: reduce-row-sum row 2 read 2.8499999 against a reference of
        // 2.85, which is one rounding of the store and not a wrong answer.
        double bound = (which == CharonRefReduceMin || which == CharonRefReduceMax) ? 0.0 : CharonOneUlp(want);
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


// MPSImageConvolution, from MPSImageConvolution.h of the iPhoneOS 26.2 surface. Twelve rows owe this
// family; the base and its fixed-weight subclasses all reduce to one thing - a weighted sum of the source
// window - so the reference is written once and the case reuses it for each class with that class's own
// weights.
//
// What the header gives, and this is the whole of it:
//   :62-72 bias - the bias is added to the convolved value, and only then is the result stored. So the sum is taken, the bias added, and the result stored - three steps, and the
//     order matters: adding the bias before the store is what makes the result a float32 rounding of
//     (sum + bias), not a float32 rounding of the sum with a float32 bias added afterwards.
//   :87 -initWithDevice:kernelWidth:kernelHeight:weights: is the designated initializer, and
//     kernelWeights is a pointer to kernelWidth * kernelHeight values that form the kernel, row-major over kernelWidth.
//   :154-168 MPSImageBox - the same window, and both dimensions must be odd, which is what
//     keeps the window centred on the pixel it writes.
//   :270 MPSImageGaussianBlur and MPSImageBox mark -initWithDevice: NS_UNAVAILABLE, as the reduction
//     family does: the kernel size or the sigma is part of what the object IS.
//
// The edge rule is inherited, not this header's: MPSUnaryImageKernel's edgeMode, whose default MPSImageKernel.h
// gives the zero mode, though only usually. So a window that reaches off the edge reads ZERO there, and the
// reference clamps by multiplying by zero rather than by replicating the border - replicating would be
// MPSImageEdgeModeClamp and would answer a different question.
//
// min, max and sum of this family are not separate operations here: a convolution is a weighted sum, so it
// accumulates in double and stores float32 exactly as the reduction family's sum and mean did, and one whole
// float32 ulp of the answer is the bound. Comparing it for equality would be the same mistake the reduce
// reference made.
static void CharonReferenceImageConvolution(const char *name, const float *src, NSUInteger rows, NSUInteger cols,
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
                // MPSImageEdgeModeZero: a sample off the edge contributes nothing. Multiplying by zero
                // rather than skipping keeps the weights array indexed the way the header describes it.
                long sy = (long)(y + ky) - (long)halfH;
                long sx = (long)(x + kx) - (long)halfW;
                double sample = 0.0;
                if (sy >= 0 && sy < (long)rows && sx >= 0 && sx < (long)cols)
                    sample = (double)src[(NSUInteger)sy * cols + (NSUInteger)sx];
                total += (double)weights[ky * kernelWidth + kx] * sample;
            }
        }
        double want = total + bias;          // bias added before the store, :62-72
        gCompared++;
        double got = (double)out[r];
        if (fabs(got - want) > CharonOneUlp(want)) {
            gMismatches++;
            printf("\n  MISMATCH %s [%lu] reference %.9g port %.9g, one float32 ulp is the bound\n",
                   name, (unsigned long)r, want, got);
        }
        printf(" %.9g", want);
    }
    printf("\n");
}


// MPSImageMorphology, from MPSImageMorphology.h of the iPhoneOS 26.2 surface: MPSImageAreaMax (:22),
// MPSImageAreaMin (:72), MPSImageDilate (:96) and MPSImageErode (:174), all ios(9.0).
//
// :17-18 MPSImageAreaMax takes the maximum over a rectangular region centred on each pixel. With several channels, each
// channel is processed on its own window, so the channel is a third loop and not a divide of the buffer. MPSImageAreaMin is the
// minimum over the same window; MPSImageDilate is the maximum with the caller's probe (:129 gives the probe as the set of values
// to use, and :116 says each probe describes a 3D surface of values), so one height per tap, row-major; MPSImageErode is the minimum over the same probe.
//
// THE EDGE IS CLAMPED, and this is what makes the family unlike the convolution's. :69 and :93 both say the
// edge mode is fixed at clamp for this filter. So a tap reaching
// off the edge takes the nearest edge VALUE, not zero. The convolution reference multiplies an off-edge
// sample by zero; this one clamps the index instead, and the case runs a window wider than the image
// precisely so the two cannot both pass.
//
// COMPARED FOR EQUALITY, and that is the header's semantics rather than a convenience. A maximum and a
// minimum SELECT a value the source already holds: nothing is added, nothing is multiplied, so the answer
// is bit-for-bit one of the inputs and a tolerance could only hide a real defect. The convolution family's
// reference carries one float32 ulp because that family accumulates and stores; this one carries none,
// and the difference is stated here rather than left for a reader to infer from a missing tolerance.
static void CharonReferenceImageMorphology(const char *name, const float *src, NSUInteger rows, NSUInteger cols,
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
                    // :69 and :93 - the edge is CLAMPED, not zero. An index past the edge takes the
                    // nearest edge sample, which is MPSImageEdgeModeClamp and what the header says this
                    // filter always assumes.
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


// MPSImageHistogram, from MPSImageHistogram.h of the iPhoneOS 26.2 surface: MPSImageHistogram (:33) and
// MPSImageNormalizedHistogram (:145), both ios(9.0).
//
// What the header fixes, and this is the whole contract:
//   MPSImageHistogramInfo carries numberOfHistogramEntries (the bin count), histogramForAlpha, minPixelValue
//   and maxPixelValue. The header's wording on the two bounds gives the range as half-open at the bottom and
//   closed at the top, and a value outside it is not binned at all.
//   :59 minPixelThresholdValue - an entry is incremented only when the pixel reaches the threshold, per channel.
//   :206-215 the result layout: R bins first, then G, B and A, each channel's bins in order -- so CHANNEL-MAJOR, and :208
//   says that with histogramForAlpha off on an RGBA source only the RGB channels are stored.
//
// EXACT, and for the same reason the morphology reference is exact: a histogram COUNTS. It selects a bin
// and adds one, so the answer is an integer and a tolerance could only hide an off-by-one. There is no ulp
// here, and that is stated because the convolution family's reference has one and the difference is a
// decision about what the operation does rather than an inconsistency in how it is checked.
static void CharonReferenceImageHistogram(const char *name, const unsigned char *rgba, NSUInteger rows,
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
                    double v = (double)rgba[(y * cols + x) * 4 + c] / 255.0;   // the case's unorm8 source
                    if (v < lo || v > hi)                                       // minPixelValue / maxPixelValue
                        continue;
                    NSUInteger bin = (NSUInteger)((v - lo) / (hi - lo) * (double)bins);
                    if (bin >= bins)
                        bin = bins - 1;      // the top of the range is a real bin, not one past the end
                    if (bin == b)
                        want++;
                }
            gCompared++;
            uint32_t have = got[c * bins + b];        // :206-215, channel-major
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

#endif /* CHARON_MPS_REFERENCE_H */
