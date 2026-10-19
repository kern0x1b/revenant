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

typedef enum { CharonDFTComplex = 0, CharonDFTReal = 1 } CharonDFTKind;

struct vDSP_DFT_SetupStructD {
    vDSP_Length length;
    double sign;
    CharonDFTKind kind;
};

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
            double out_real, out_imaginary;
            CharonDFTBin(real, imaginary, length, length, half, sign, &out_real, &out_imaginary);
            __Oi[0] = 2.0 * out_real;
        }
        free(real);
        free(imaginary);
        return;
    }
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
