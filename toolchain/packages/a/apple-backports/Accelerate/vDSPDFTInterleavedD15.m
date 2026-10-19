#import <Accelerate/Accelerate.h>
#include <math.h>
#include <stdlib.h>
#include <string.h>

#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wpointer-bool-conversion"
#pragma clang diagnostic ignored "-Wnonnull"

struct vDSP_DFT_Interleaved_SetupStructD {
    vDSP_Length length;
    vDSP_Length real_length;
    int forward;
    int real_to_complex;
    double *twiddles;
    DSPDoubleComplex *packed;
    DSPDoubleComplex *z;
};

static void charon_dftD_add(double *sum, double *comp, double x)
{
    const double t = *sum + x;
    const double bb = t - *sum;
    *comp += (*sum - (t - bb)) + (x - bb);
    *sum = t;
}

static void charon_dftD_accumulate(double *sum, double *comp, double a, double b)
{
    const double p = a * b;
    charon_dftD_add(sum, comp, p);
    charon_dftD_add(sum, comp, fma(a, b, -p));
}

static void charon_dftD_release(struct vDSP_DFT_Interleaved_SetupStructD *setup)
{
    if (!setup)
        return;
    free(setup->twiddles);
    free(setup->packed);
    free(setup->z);
    free(setup);
}

static int charon_dftD_length_supported(vDSP_Length length)
{
    static const vDSP_Length factors[5] = {2, 3, 5, 9, 15};
    for (int i = 0; i < (int)(sizeof factors / sizeof *factors); i++) {
        vDSP_Length n = length / factors[i];
        if (length % factors[i] == 0 && n >= 4 && (n & (n - 1)) == 0)
            return 1;
    }
    return 0;
}

static double *charon_dftD_twiddles(vDSP_Length length, int forward)
{
    double *twiddles = (double *)malloc(sizeof(double) * (size_t)(2 * length));
    if (!twiddles)
        return NULL;
    for (vDSP_Length k = 0; k < length; k++) {
        double angle = 2.0 * M_PI * (double)k / (double)length;
        double sign = forward ? -1.0 : 1.0;
        twiddles[2 * k] = cos(sign * angle);
        twiddles[2 * k + 1] = sin(sign * angle);
    }
    return twiddles;
}

vDSP_DFT_Interleaved_SetupD vDSP_DFT_Interleaved_CreateSetupD(vDSP_DFT_Interleaved_SetupD Previous, vDSP_Length Length,
                                                             vDSP_DFT_Direction Direction,
                                                             vDSP_DFT_RealtoComplex RealtoComplex)
{
    if (!charon_dftD_length_supported(Length))
        return NULL;
    (void)Previous;
    struct vDSP_DFT_Interleaved_SetupStructD *setup = (struct vDSP_DFT_Interleaved_SetupStructD *)calloc(1, sizeof(*setup));
    if (!setup)
        return NULL;
    setup->length = Length;
    setup->real_length = RealtoComplex == vDSP_DFT_Interleaved_RealtoComplex ? 2 * Length : 0;
    setup->forward = Direction == vDSP_DFT_FORWARD;
    setup->real_to_complex = RealtoComplex == vDSP_DFT_Interleaved_RealtoComplex;
    setup->twiddles = charon_dftD_twiddles(Length, setup->forward);
    if (setup->twiddles && setup->real_to_complex) {
        setup->packed = (DSPDoubleComplex *)calloc(Length, sizeof(DSPDoubleComplex));
        setup->z = (DSPDoubleComplex *)calloc(Length, sizeof(DSPDoubleComplex));
    }
    if (!setup->twiddles || (setup->real_to_complex && (!setup->packed || !setup->z))) {
        charon_dftD_release(setup);
        return NULL;
    }
    return (vDSP_DFT_Interleaved_SetupD)setup;
}

void vDSP_DFT_Interleaved_ExecuteD(const vDSP_DFT_Interleaved_SetupD Setup, const DSPDoubleComplex *Iri, DSPDoubleComplex *Ori)
{
    const struct vDSP_DFT_Interleaved_SetupStructD *setup = (const struct vDSP_DFT_Interleaved_SetupStructD *)Setup;
    const vDSP_Length n = setup->length;
    const double *twiddles = setup->twiddles;
    if (!setup->real_to_complex) {
        for (vDSP_Length k = 0; k < n; k++) {
            double re = 0.0, reComp = 0.0, im = 0.0, imComp = 0.0;
            for (vDSP_Length j = 0; j < n; j++) {
                const double tr = twiddles[2 * ((k * j) % n)];
                const double ti = twiddles[2 * ((k * j) % n) + 1];
                charon_dftD_accumulate(&re, &reComp, Iri[j].real, tr);
                charon_dftD_accumulate(&re, &reComp, -Iri[j].imag, ti);
                charon_dftD_accumulate(&im, &imComp, Iri[j].real, ti);
                charon_dftD_accumulate(&im, &imComp, Iri[j].imag, tr);
            }
            Ori[k].real = re + reComp;
            Ori[k].imag = im + imComp;
        }
    } else {
        const vDSP_Length samples = 2 * n;
        if (setup->forward) {
            DSPDoubleComplex *packed = setup->packed;
            const double *x = &Iri[0].real;
            for (vDSP_Length j = 0; j < samples; j++) {
                const vDSP_Length m = j / 2;
                if (j % 2)
                    packed[m].imag = x[j];
                else
                    packed[m].real = x[j];
            }
            DSPDoubleComplex *z = setup->z;
            for (vDSP_Length k = 0; k < n; k++) {
                double re = 0.0, reComp = 0.0, im = 0.0, imComp = 0.0;
                for (vDSP_Length m = 0; m < n; m++) {
                    const vDSP_Length t = (k * m) % n;
                    const double tr = twiddles[2 * t], ti = twiddles[2 * t + 1];
                    charon_dftD_accumulate(&re, &reComp, packed[m].real, tr);
                    charon_dftD_accumulate(&re, &reComp, -packed[m].imag, ti);
                    charon_dftD_accumulate(&im, &imComp, packed[m].real, ti);
                    charon_dftD_accumulate(&im, &imComp, packed[m].imag, tr);
                }
                z[k].real = re + reComp;
                z[k].imag = im + imComp;
            }
            for (vDSP_Length k = 0; k < n; k++) {
                const vDSP_Length m = (k == 0) ? 0 : n - k;
                const double zr = z[k].real, zi = z[k].imag;
                const double cr = z[m].real, ci = -z[m].imag;
                const double er = (zr + cr) / 2.0, ei = (zi + ci) / 2.0;
                const double or_ = (zi - ci) / 2.0, oi = -(zr - cr) / 2.0;
                const double w = -M_PI * (double)k / (double)n;
                const double pr = or_ * cos(w) - oi * sin(w);
                const double pi_ = or_ * sin(w) + oi * cos(w);
                if (k == 0) {
                    Ori[0].real = (double)(2.0 * (er + or_));
                    Ori[0].imag = (double)(2.0 * (er - or_));
                } else {
                    Ori[k].real = (double)(2.0 * (er + pr));
                    Ori[k].imag = (double)(2.0 * (ei + pi_));
                }
            }
        } else {
            for (vDSP_Length j = 0; j < samples; j++) {
                double acc = (double)Iri[0].real + (double)Iri[0].imag * ((j % 2) ? -1.0 : 1.0);
                for (vDSP_Length k = 1; k < n; k++) {
                    double angle = 2.0 * M_PI * (double)k * (double)j / (double)samples;
                    acc += 2.0 * ((double)Iri[k].real * cos(angle) - (double)Iri[k].imag * sin(angle));
                }
                ((double *)&Ori[0].real)[j] = (double)acc;
            }
        }
    }
}

void vDSP_DFT_Interleaved_DestroySetupD(vDSP_DFT_Interleaved_SetupD Setup)
{
    charon_dftD_release((struct vDSP_DFT_Interleaved_SetupStructD *)Setup);
}
