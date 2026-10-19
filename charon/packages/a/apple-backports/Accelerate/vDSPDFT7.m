// The double-precision discrete Fourier transform of vDSP: vDSP_DFT_zop_CreateSetupD,
// vDSP_DFT_zrop_CreateSetupD, vDSP_DFT_ExecuteD and vDSP_DFT_DestroySetupD - the four the port carries,
// all of iOS 7.0.
//
// Measured from the release's armv7 caches, 7.0 is the first held release that exports the four, so this
// file holds the API of exactly one release. The release's own vecLib has them from 7.0 on; what the older
// bands do not have is the API itself, and this is its arithmetic rather than a second copy of a library.
//
// Everything below is the host's own answer, measured with tests/backports/host/vdspdft and recorded in
// facts/Accelerate/vDSPDFT.md. vDSP.h publishes no layout for a vDSP_DFT_SetupD, so the one here is the
// port's, and a caller only ever passes the pointer around.
//
// Which lengths have an implementation is the first thing a setup routine answers, and the answer is a set
// rather than a rule the header spells: a power of two, or f * 2**n for f in 3, 5 and 15 and n of at least
// 3. Measured over 1 to 200, in both directions and for both kinds of transform, the lengths that answer a
// setup are 1, 2, 4, 8, 16, 24, 32, 40, 48, 64, 80, 96, 120, 128, 160 and 192 for the complex-to-complex
// kind and the same without the 1 for the real-to-complex kind, which needs at least two. Everything else
// answers NULL, as the header says it does when there is no implementation for the case.
//
// The transforms, all of them unnormalised, and all of them the sum the header prints:
//
//   - Complex to complex, forward: H[k] = sum over j of h[j] * e**(-2*pi*i*j*k/N), in Or and Oi, k over the
//     whole length. Measured: an impulse at 0 answers 1 in every bin, and a vector of ones answers N in bin 0
//     and 0 in the rest.
//   - Real to complex, forward: the input is the even-indexed samples in Ir and the odd-indexed ones in Ii,
//     N/2 each, and the output is the packing the header prints under the declaration - H[0] in Or[0], H[N/2]
//     in Oi[0], and H[k] as Or[k] + i * Oi[k] for 1 < k < N/2 - and every packed value is *twice* the
//     transform. Measured as the linear map on the four basis inputs at N = 4 and N = 8: with Ir[0] alone set
//     to 1 at N = 4 the answer is Or = (2, 2) and Oi = (2, 0), which is H = (2, 2, 2) where the transform of
//     (1, 0, 0, 0) is (1, 1, 1); with Ir[1] alone set to 1 at N = 8, whose real signal is (0, 0, 1, 0, 0, 0,
//     0, 0), the answer is Or = (2, 0, -2, 0) and Oi = (2, -2, 0, 2), which is twice that transform's bins.
//   - Inverse, both kinds: the layouts are the other way round - the input is the packing above and the
//     output is the even and the odd samples - and there is no normalisation. Measured: a packed input of 1
//     in Or[0] and nothing else answers 1 in every element of both output arrays at N = 4, where a
//     normalised inverse would answer 1/4.
//
// The factor of two on the forward real-to-complex answer and the missing normalisation on the inverse are
// what the host answers; the facts file carries the numbers beside the header's own words and says where
// the two differ from the formula the header prints.

#import <Accelerate/Accelerate.h>
#include <math.h>
#include <stdlib.h>
#include <string.h>

#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wunguarded-availability"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#pragma clang diagnostic ignored "-Wnonnull"

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

// Which of the two transforms a setup is for, and the three numbers it has to carry.
typedef enum { CharonDFTComplex = 0, CharonDFTReal = 1 } CharonDFTKind;

struct vDSP_DFT_SetupStructD {
    vDSP_Length length;
    double sign;   // -1.0 forward, +1.0 inverse: the sign of the exponent in the sum
    CharonDFTKind kind;
};

// Whether there is an implementation for this length, which is what a setup routine answers NULL for. A
// power of two always has one; 3, 5 and 15 times a power of two have one from the third power for the
// complex-to-complex kind and from the fourth for the real-to-complex kind, which is one length fewer at
// each end and is what the measurement says (measured over 1 to 200: the complex kind answers for 24, 40
// and 120 and the real kind does not, while both answer for 48, 80, 96, 160 and 192). The real kind also
// needs at least two elements, where a length of 1 has a complex-to-complex setup and no real one.
static int CharonDFTHasImplementation(vDSP_Length length, CharonDFTKind kind)
{
    int power = 0;
    int floor = kind == CharonDFTReal ? 4 : 3;
    if (length == 0 || (kind == CharonDFTReal && length < 2)) {
        return 0;
    }
    while ((length & 1) == 0) {
        length >>= 1;
        power++;
    }
    if (length == 1) {
        return 1;
    }
    return power >= floor && (length == 3 || length == 5 || length == 15);
}

static vDSP_DFT_SetupD CharonDFTCreateSetup(vDSP_Length length, vDSP_DFT_Direction direction, CharonDFTKind kind)
{
    struct vDSP_DFT_SetupStructD *setup;
    if (!CharonDFTHasImplementation(length, kind)) {
        return NULL;
    }
    setup = (struct vDSP_DFT_SetupStructD *)calloc(1, sizeof(*setup));
    if (!setup) {
        return NULL;
    }
    setup->length = length;
    setup->kind = kind;
    setup->sign = direction == vDSP_DFT_INVERSE ? 1.0 : -1.0;
    return (vDSP_DFT_SetupD)setup;
}

vDSP_DFT_SetupD vDSP_DFT_zop_CreateSetupD(vDSP_DFT_SetupD __Previous, vDSP_Length __Length,
                                          vDSP_DFT_Direction __Direction)
{
    (void)__Previous;
    return CharonDFTCreateSetup(__Length, __Direction, CharonDFTComplex);
}

vDSP_DFT_SetupD vDSP_DFT_zrop_CreateSetupD(vDSP_DFT_SetupD __Previous, vDSP_Length __Length,
                                           vDSP_DFT_Direction __Direction)
{
    (void)__Previous;
    return CharonDFTCreateSetup(__Length, __Direction, CharonDFTReal);
}

void vDSP_DFT_DestroySetupD(vDSP_DFT_SetupD __Setup)
{
    free(__Setup);
}

// One bin of the transform of a complex signal, by the sum the header prints. The two accumulators are the
// real and the imaginary part of the running total, which is how each term is split without a complex type.
static void CharonDFTBin(const double *real, const double *imaginary, vDSP_Length count, vDSP_Length length,
                         vDSP_Length bin, double sign, double *out_real, double *out_imaginary)
{
    double sum_real = 0.0, sum_imaginary = 0.0;
    for (vDSP_Length j = 0; j < count; j++) {
        double angle = sign * 2.0 * M_PI * (double)j * (double)bin / (double)length;
        sum_real += real[j] * cos(angle) - imaginary[j] * sin(angle);
        sum_imaginary += real[j] * sin(angle) + imaginary[j] * cos(angle);
    }
    *out_real = sum_real;
    *out_imaginary = sum_imaginary;
}

void vDSP_DFT_ExecuteD(const struct vDSP_DFT_SetupStructD *__Setup, const double *__Ir, const double *__Ii, double *__Or,
                       double *__Oi)
{
    const struct vDSP_DFT_SetupStructD *setup = __Setup;
    vDSP_Length length, half;
    double sign;
    double *real, *imaginary;
    if (!setup || !__Ir || !__Ii || !__Or || !__Oi) {
        return;
    }
    length = setup->length;
    half = length / 2;
    sign = setup->sign;
    real = (double *)malloc(length * sizeof(double));
    imaginary = (double *)malloc(length * sizeof(double));
    if (!real || !imaginary) {
        free(real);
        free(imaginary);
        return;
    }
    if (setup->kind == CharonDFTComplex) {
        // Straight from the sum, in the caller's own two arrays of length elements.
        memcpy(real, __Ir, length * sizeof(double));
        memcpy(imaginary, __Ii, length * sizeof(double));
        for (vDSP_Length k = 0; k < length; k++) {
            double out_real, out_imaginary;
            CharonDFTBin(real, imaginary, length, length, k, sign, &out_real, &out_imaginary);
            __Or[k] = out_real;
            __Oi[k] = out_imaginary;
        }
        free(real);
        free(imaginary);
        return;
    }
    if (sign < 0.0) {
        // Forward: the input is the even and the odd samples, N/2 each, so the signal is their
        // interleaving; the output is the header's packing of the first N/2 + 1 bins, each value twice the
        // transform's own.
        for (vDSP_Length j = 0; j < length; j++) {
            real[j] = (j & 1) ? __Ii[j / 2] : __Ir[j / 2];
            imaginary[j] = 0.0;
        }
        for (vDSP_Length k = 0; k < half; k++) {
            double out_real, out_imaginary;
            CharonDFTBin(real, imaginary, length, length, k, sign, &out_real, &out_imaginary);
            __Or[k] = 2.0 * out_real;
            __Oi[k] = 2.0 * out_imaginary;
        }
        {
            // The Nyquist bin, H[N/2], is the one the header puts in Oi[0] - and the loop has left the DC in
            // Or[0], which is the other half of the packing and which a real signal's H[0] is.
            double out_real, out_imaginary;
            CharonDFTBin(real, imaginary, length, length, half, sign, &out_real, &out_imaginary);
            __Oi[0] = 2.0 * out_real;
        }
        free(real);
        free(imaginary);
        return;
    }
    // The layouts are the other way round for an inverse - the header says so under the declaration - so
    // the packing comes in Ir and Ii: H[0] in Ir[0], H[N/2] in Ii[0] and H[k] as Ir[k] + i * Ii[k] for
    // 1 < k < N/2, with the bins above N/2 the conjugate of those. The even and the odd samples of the
    // inverse, unnormalised, go out in Or and Oi.
    for (vDSP_Length k = 0; k < half; k++) {
        real[k] = __Ir[k];
        imaginary[k] = __Ii[k];
    }
    real[0] = __Ir[0];
    imaginary[0] = 0.0;
    real[half] = __Ii[0];
    imaginary[half] = 0.0;
    for (vDSP_Length k = 1; k < half; k++) {
        real[length - k] = real[k];
        imaginary[length - k] = -imaginary[k];
    }
    // The output is two arrays of N/2 - the even samples in the first and the odd in the second - and they
    // are the caller's own, so they are written through a pointer of their own element type.
    {
        double *even = (double *)__Or, *odd = (double *)__Oi;
        for (vDSP_Length j = 0; j < length; j++) {
            double out_real, out_imaginary;
            CharonDFTBin(real, imaginary, length, length, j, sign, &out_real, &out_imaginary);
            if (j & 1) {
                odd[j / 2] = out_real;
            } else {
                even[j / 2] = out_real;
            }
        }
    }
    free(real);
    free(imaginary);
}
