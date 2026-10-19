// mps9-reference.h - the reference the three MPSImage 9.0 kernels are checked against, computed from
// the release's own stated formulas and NOT from this port.
//
// WHY A REFERENCE IN C AND NOT THE HOST'S KERNEL. The host cannot be the oracle on this machine: this
// host's AGX family does not implement computeCommandEncoderWithDispatchType:, and the release's own
// MPSImage kernels die encoding with
//
//   '-[AGXG16XFamilyCommandBuffer mtlnext computeCommandEncoderWithDispatchType:]': unrecognized selector
//
// so it answers nothing here. The reference is therefore the header's formula, computed in this file,
// and the registry rows for these three say so in their reason. Nothing on these rows is a measurement
// of Apple's code, and no number below pretends to be.
//
// THE FORMULAS, as the headers state them, cited so a reader can check them:
//
//   MPSImageIntegral.h:19-20, :40-41   sumRect.origin = MPSUnaryImageKernel.offset
//                                      sumRect.size   = dest_position - clipRect.origin
//                                      -> the value at a position is the sum of the source over the
//                                         rectangle from the offset to that position
//   MPSImageIntegral.h:38              MPSImageIntegralOfSquares sums the SQUARES of that rectangle
//   MPSImageConvolution.h:281-288      "implements the Sobel filter"; the luminance it runs on is
//                                      Luminance = v[0]*x + v[1]*y + v[2]*z, and :301-302 gives the
//                                      default transform BT.601/JPEG {0.299f, 0.587f, 0.114f}
//   MPSImageConvolution.h:350-352      G = sqrt(Sx^2 + Sy^2) for the 3x3 Sobel pair
//
// THE TOLERANCE, and why it is what it is. The integral sums in double and stores float32; the Sobel
// forms a magnitude in double and stores float32. The difference between "the port is right" and "the
// port is one rounding off" is exactly one unit in the last place of the stored float32, so that is the
// bound: a wider one would hide a real defect, a narrower one would fail every case. The reference sums
// in the SAME order as the port - the header states no order and one is as good as another, but a
// prefix-sum reference against a per-pixel-sum implementation would differ by real accumulation and
// would be measuring the difference between two implementations rather than against the header.
//
// WHAT IS NOT HERE, and why. Neither a non-maximum suppression nor a median appears below: the
// suppression is MPSImageConvolution.h:353-360, step 3 of MPSImageCANNY's five, and MPSImageSobel's own
// @discussion does not claim it; the median belongs to MPSImageMedian, whose two diameter accessors no
// header states a value for, so that class is owed rather than answered. A reference that checked for a
// behaviour the row does not claim would be checking something else.

#ifndef CHARON_MPS9_REFERENCE_H
#define CHARON_MPS9_REFERENCE_H

#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

static NSUInteger gCompared9 = 0;
static NSUInteger gMismatches9 = 0;

// One unit in the last place of the stored float32, which is what the comparison is about.
static double CharonMPS9Ulp(float stored)
{
    return (double)fabsf(stored) * 1.19209290e-07 + 1.0e-30;
}

static void CharonMPS9Compare(const char *name, double want, float got)
{
    gCompared9++;
    double ulp = CharonMPS9Ulp(got);
    if (fabs((double)got - want) > ulp) {
        gMismatches9++;
        printf("  MISMATCH %s reference %.9g port %.9g, one ulp %.3g\n", name, want, (double)got, ulp);
    }
}

// The rectangle sum, MPSImageIntegral.h:19-20. `values` is the source row-major, one channel, and
// `w`/`h` the source's own. The rectangle at (x, y) runs from the origin to (x, y) INCLUSIVE: the
// header's size is a difference of two POSITIONS and not a count, so a rectangle that size holds one
// more sample per axis than its length. The two loops are in the same order the port's are, so the
// comparison is against the formula and not against an accumulation difference.
static double CharonMPS9Integral(const double *values, NSUInteger w, NSUInteger h, NSInteger x,
                                 NSInteger y, BOOL squared)
{
    if (x < 0 || y < 0)
        return 0.0;
    double total = 0.0;
    for (NSInteger j = 0; j <= y; j++)
        for (NSInteger i = 0; i <= x; i++) {
            double v = values[(NSUInteger)j * w + (NSUInteger)i];
            total += squared ? v * v : v;
        }
    return total;
}

static void CharonMPS9CheckIntegral(const char *name, const double *values, NSUInteger w, NSUInteger h,
                                    const float *got, BOOL squared)
{
    for (NSUInteger y = 0; y < h; y++)
        for (NSUInteger x = 0; x < w; x++) {
            double want = CharonMPS9Integral(values, w, h, (NSInteger)x, (NSInteger)y, squared);
            char label[256];
            snprintf(label, sizeof(label), "%s (%lu,%lu)", name, (unsigned long)x, (unsigned long)y);
            CharonMPS9Compare(label, want, got[y * w + x]);
        }
}

// The Sobel magnitude, MPSImageConvolution.h:350-352, on the luminance of :286 when `luminance` is set
// and on the channel itself when it is not (which is the header's own "applied to each channel
// separately" for matching colour models, :283-285). The 3x3 pair is the standard operator:
//   Sx = -1  0  +1     Sy = -1  -2  -1
//        -2  0  +2          0   0   0
//        -1  0  +1          1   2   1
// The neighbourhood is clipped at the image's edge and reads 0 outside it, which is the header's
// edgeModeZero default (MPSImageKernel.h:151-162) and what the port's walk does.
static void CharonMPS9CheckSobel(const char *name, const double *values, NSUInteger w, NSUInteger h,
                                 const float *got, NSUInteger channels, const float *transform)
{
    static const int kx[9] = { -1, 0, 1, -2, 0, 2, -1, 0, 1 };
    static const int ky[9] = { -1, -2, -1, 0, 0, 0, 1, 2, 1 };
    for (NSUInteger c = 0; c < channels; c++) {
        for (NSUInteger y = 0; y < h; y++)
            for (NSUInteger x = 0; x < w; x++) {
                double gx = 0.0, gy = 0.0;
                for (int j = 0; j < 3; j++)
                    for (int i = 0; i < 3; i++) {
                        NSInteger sx = (NSInteger)x + i - 1, sy = (NSInteger)y + j - 1;
                        if (sx < 0 || sy < 0 || (NSUInteger)sx >= w || (NSUInteger)sy >= h)
                            continue;           // outside the image: edgeModeZero, no sample
                        NSUInteger pixel = (NSUInteger)sy * w + (NSUInteger)sx;
                        double sample;
                        if (channels >= 3) {
                            sample = transform[0] * values[pixel * channels + 0]
                                   + transform[1] * values[pixel * channels + 1]
                                   + transform[2] * values[pixel * channels + 2];
                        } else {
                            sample = values[pixel * channels + c];
                        }
                        gx += kx[j * 3 + i] * sample;
                        gy += ky[j * 3 + i] * sample;
                    }
                char label[256];
                snprintf(label, sizeof(label), "%s channel %lu (%lu,%lu)", name, (unsigned long)c,
                         (unsigned long)x, (unsigned long)y);
                CharonMPS9Compare(label, sqrt(gx * gx + gy * gy), got[(y * w + x) * channels + c]);
            }
    }
}

#endif  // CHARON_MPS9_REFERENCE_H
