#import <Accelerate/Accelerate.h>
#include <math.h>
#include <stdlib.h>
#include <string.h>

#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wpointer-bool-conversion"
#pragma clang diagnostic ignored "-Wnonnull"

struct vDSP_DFT_Interleaved_SetupStruct {
    vDSP_Length length;
    vDSP_Length real_length;
    int forward;
    int real_to_complex;
    double *twiddles;
    DSPDoubleComplex *packed;
    DSPDoubleComplex *z;
};

struct vDSP_DFT_Interleaved_SetupStructD {
    vDSP_Length length;
    vDSP_Length real_length;
    int forward;
    int real_to_complex;
};

static int revenant_dft_length_supported(vDSP_Length length)
{
    static const vDSP_Length factors[5] = {2, 3, 5, 9, 15};
    for (int i = 0; i < (int)(sizeof factors / sizeof *factors); i++) {
        vDSP_Length n = length / factors[i];
        if (length % factors[i] == 0 && n >= 4 && (n & (n - 1)) == 0)
            return 1;
    }
    return 0;
}

static double *revenant_dft_twiddles(vDSP_Length length, int forward)
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

static void revenant_dft_release(struct vDSP_DFT_Interleaved_SetupStruct *setup)
{
    if (!setup)
        return;
    free(setup->twiddles);
    free(setup->packed);
    free(setup->z);
    free(setup);
}

vDSP_DFT_Interleaved_Setup vDSP_DFT_Interleaved_CreateSetup(vDSP_DFT_Interleaved_Setup Previous, vDSP_Length Length,
                                                             vDSP_DFT_Direction Direction,
                                                             vDSP_DFT_RealtoComplex RealtoComplex)
{
    if (!revenant_dft_length_supported(Length))
        return NULL;
    (void)Previous;
    struct vDSP_DFT_Interleaved_SetupStruct *setup = (struct vDSP_DFT_Interleaved_SetupStruct *)calloc(1, sizeof(*setup));
    if (!setup)
        return NULL;
    setup->length = Length;
    setup->real_length = RealtoComplex == vDSP_DFT_Interleaved_RealtoComplex ? 2 * Length : 0;
    setup->forward = Direction == vDSP_DFT_FORWARD;
    setup->real_to_complex = RealtoComplex == vDSP_DFT_Interleaved_RealtoComplex;
    setup->twiddles = revenant_dft_twiddles(Length, setup->forward);
    if (setup->twiddles && setup->real_to_complex) {
        setup->packed = (DSPDoubleComplex *)calloc(Length, sizeof(DSPDoubleComplex));
        setup->z = (DSPDoubleComplex *)calloc(Length, sizeof(DSPDoubleComplex));
    }
    if (!setup->twiddles || (setup->real_to_complex && (!setup->packed || !setup->z))) {
        revenant_dft_release(setup);
        return NULL;
    }
    return (vDSP_DFT_Interleaved_Setup)setup;
}

void vDSP_DFT_Interleaved_Execute(const vDSP_DFT_Interleaved_Setup Setup, const DSPComplex *Iri, DSPComplex *Ori)
{
    const struct vDSP_DFT_Interleaved_SetupStruct *setup = (const struct vDSP_DFT_Interleaved_SetupStruct *)Setup;
    const vDSP_Length n = setup->length;
    const double *twiddles = setup->twiddles;
    if (!setup->real_to_complex) {
        for (vDSP_Length k = 0; k < n; k++) {
            double re = 0.0, im = 0.0;
            for (vDSP_Length j = 0; j < n; j++) {
                const double tr = twiddles[2 * ((k * j) % n)];
                const double ti = twiddles[2 * ((k * j) % n) + 1];
                re += (double)Iri[j].real * tr - (double)Iri[j].imag * ti;
                im += (double)Iri[j].real * ti + (double)Iri[j].imag * tr;
            }
            Ori[k].real = (float)re;
            Ori[k].imag = (float)im;
        }
    } else {
        const vDSP_Length samples = 2 * n;
        if (setup->forward) {
            DSPDoubleComplex *packed = setup->packed;
            const float *x = &Iri[0].real;
            for (vDSP_Length j = 0; j < samples; j++) {
                const vDSP_Length m = j / 2;
                if (j % 2)
                    packed[m].imag = x[j];
                else
                    packed[m].real = x[j];
            }
            DSPDoubleComplex *z = setup->z;
            for (vDSP_Length k = 0; k < n; k++) {
                double re = 0.0, im = 0.0;
                for (vDSP_Length m = 0; m < n; m++) {
                    const vDSP_Length t = (k * m) % n;
                    const double pr = (double)packed[m].real * twiddles[2 * t] - (double)packed[m].imag * twiddles[2 * t + 1];
                    const double pi = (double)packed[m].real * twiddles[2 * t + 1] + (double)packed[m].imag * twiddles[2 * t];
                    re += pr;
                    im += pi;
                }
                z[k].real = re;
                z[k].imag = im;
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
                    Ori[0].real = (float)(2.0 * (er + or_));
                    Ori[0].imag = (float)(2.0 * (er - or_));
                } else {
                    Ori[k].real = (float)(2.0 * (er + pr));
                    Ori[k].imag = (float)(2.0 * (ei + pi_));
                }
            }
        } else {
            for (vDSP_Length j = 0; j < samples; j++) {
                double acc = (double)Iri[0].real + (double)Iri[0].imag * ((j % 2) ? -1.0 : 1.0);
                for (vDSP_Length k = 1; k < n; k++) {
                    double angle = 2.0 * M_PI * (double)k * (double)j / (double)samples;
                    acc += 2.0 * ((double)Iri[k].real * cos(angle) - (double)Iri[k].imag * sin(angle));
                }
                ((float *)&Ori[0].real)[j] = (float)acc;
            }
        }
    }
}

void vDSP_DFT_Interleaved_DestroySetup(vDSP_DFT_Interleaved_Setup Setup)
{
    revenant_dft_release((struct vDSP_DFT_Interleaved_SetupStruct *)Setup);
}
