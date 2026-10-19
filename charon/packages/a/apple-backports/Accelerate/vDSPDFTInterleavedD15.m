// vDSP_DFT_Interleaved, iOS 15.0, in double precision. The three rows are CreateSetup, Execute and
// DestroySetup, and the setup is the PORT's own object from end to end - nothing of the release's is opaque,
// which is what makes this family different from vDSP_biquad_SetCoefficients.
//
// **The supported lengths, measured over 1 to 1024.** The header (vDSP.h:7523) gives the length as f * 2**n, with f
// taken from a short list of factors and n at least 2, and returns zero when it has no implementation for the case.
// Measured: 31 of 1024 lengths are accepted, and they are exactly **f * 2**n with f in {2, 3, 5, 9, 15} and
// n >= 2**. The header's `5*5 = 25` is not implemented: 25 is refused and so are 100, 200, 400 and 800, every
// one of which the header's list admits. `3*5 = 15` is implemented. RealtoComplex and ComplextoComplex accept
// the same set, measured over the whole sweep. **So the refusal below is the host's set and not the header's**,
// and the difference is the difference between a port that matches the release and one that does not.
//
// **Execute takes no stride, no direction and no length**: all three live in the setup, which the header says
// may be used only for the length given at setup and may not be used for a shorter length.
//
// **The arithmetic, in the port's own type, and where a bound rather than bit-exactness is the
// specification.** No guest here runs 15.0 and the host's own FFT is not reachable bit for bit, so the
// transform's arithmetic is held to an error bound taken from the host:
//
//     per element:  |out - ref| <= 2.63 * log2(N) * DBL_EPSILON * ||x||_2
//
// 2.63 is the host's OWN worst ratio over the 31 accepted lengths, 24 trials each, across the three stages,
// against a DOUBLE-DOUBLE reference (2.624, rounded up) - so the constant is not chosen to pass this port. The
// reference is more precise than double on purpose: against a double one, the bound would measure the reference.
// facts/Accelerate/vDSPDFTInterleaved.md section 9 has the measurements. The exact parts, which need no
// bound, are the packing layout and the scale factors below.
//
// **The packing, measured by impulse in each of the sixteen scalar inputs of the inverse and read as the
// sixteen real samples it produces** - the inverse is linear, so that table is the formula:
//
//     o[0].real  contributes  1        to every sample
//     o[0].imag  contributes  (-1)^j
//     o[k].real  contributes  2*cos(2*pi*k*j/(2N))     k = 1 .. N-1
//     o[k].imag  contributes -2*sin(2*pi*k*j/(2N))
//
// and the forward packs the other way: `o[0] = (2*X_0, 2*X_n)` with `X_n` the Nyquist bin - for a real input
// the ALTERNATING SUM `sum x[j] * (-1)^j`, since `e^(-pi*i*j) = (-1)^j` - and `o[k] = 2*X_k` for k = 1 .. N-1.
// The x2 is vDSP's real-transform scale. The inverse is unscaled, and a forward then an inverse on a real signal
// gives back 4*N times the input, measured.
//
// The transform is a direct sum in the caller's type. That is not the fastest way to compute a DFT and it is
// the only one whose arithmetic is stated in the port's own terms, which is what the bound is about; the
// release's radix stages are not reproduced and the bound is what stands in for them.

#import <Accelerate/Accelerate.h>
#include <math.h>
#include <stdlib.h>
#include <string.h>

#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wpointer-bool-conversion"
#pragma clang diagnostic ignored "-Wnonnull"

// The setup: everything Execute needs, because Execute is given nothing else.
// Every buffer Execute needs is allocated here, by CreateSetupD, and freed by DestroySetupD: Execute itself never
// allocates, so it has no failure it could only swallow.
struct vDSP_DFT_Interleaved_SetupStructD {
    vDSP_Length length;             // N, the number of complex elements
    vDSP_Length real_length;        // 2N for a real-to-complex transform, else 0
    int forward;                    // 1 forward, 0 inverse
    int real_to_complex;            // 1 real-to-complex, 0 complex-to-complex
    double *twiddles;               // 2N doubles: cos and sin of the transform's angles, the sign set by the direction
    DSPDoubleComplex *packed;       // N: the real input packed as complex, real-to-complex only
    DSPDoubleComplex *z;            // N: the complex forward of the packed input, real-to-complex only
};

// Adds x to the compensated sum (*sum, *comp): the rounding error of each addition is kept in *comp, so the sum is
// held to about double-double precision rather than to a double per addition.
static void charon_dftD_add(double *sum, double *comp, double x)
{
    const double t = *sum + x;
    const double bb = t - *sum;
    *comp += (*sum - (t - bb)) + (x - bb);
    *sum = t;
}

// Adds the product a * b exactly: the product's rounding is recovered with fma and added as a second term.
static void charon_dftD_accumulate(double *sum, double *comp, double a, double b)
{
    const double p = a * b;
    charon_dftD_add(sum, comp, p);
    charon_dftD_add(sum, comp, fma(a, b, -p));
}

// Frees a setup and every buffer it holds; free(NULL) is a no-op, so a half-built setup is released the same way.
static void charon_dftD_release(struct vDSP_DFT_Interleaved_SetupStructD *setup)
{
    if (!setup)
        return;
    free(setup->twiddles);
    free(setup->packed);
    free(setup->z);
    free(setup);
}

// The host's accepted set: length == f * 2**n with f in {2, 3, 5, 9, 15} and n >= 2. The header's list adds
// 5*5 = 25, which the release does not implement.
static int charon_dftD_length_supported(vDSP_Length length)
{
    static const vDSP_Length factors[5] = {2, 3, 5, 9, 15};
    /* sizeof factors / sizeof *factors, and not a literal 5: the bound IS the table's size. A mutant that
     * grew the table to the header's f = 5*5 = 25 and left this at 5 was INERT - it landed, and changed
     * nothing, because index 5 was never read. The two could drift apart silently, and a check that cannot be
     * broken by growing the table is not covering the table. */
    for (int i = 0; i < (int)(sizeof factors / sizeof *factors); i++) {
        vDSP_Length n = length / factors[i];
        if (length % factors[i] == 0 && n >= 4 && (n & (n - 1)) == 0)
            return 1;
    }
    return 0;
}

// A twiddle table for the transform, the sign following the direction.
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
        return NULL;                                  // the host's set, not the header's
    // Previous is an optimisation the release offers ("if feasible"): this setup takes its own tables, which the
    // header's contract allows and nothing in this port depends on, so Previous is not read.
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
    // A buffer that did not come back is a setup that cannot run, so it is refused here, where the caller can see it,
    // and never reaches Execute.
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
    const double *twiddles = setup->twiddles;      // built by CreateSetupD, which refuses a setup it cannot build
    if (!setup->real_to_complex) {
        // complex to complex: a plain DFT of N complex values, unscaled. The products are exact (charon_dftD_accumulate)
        // and the sums compensated, so the error does not grow with N the way a plain double sum's does: measured by
        // tests/backports/host/vdspdftd15 against the host-derived bound (K = 2.63), a plain sum was outside it in every
        // stage, at up to 1.2 times the bound for complex and 3.2 for real-to-complex.
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
        // The real path is NOT a direct sum of the 2N real samples: it is the VERIFIED complex forward of
        // length N on the packed signal, then the standard split. A direct sum with its own twiddle table is
        // what went wrong - the real transform resolves 2N frequencies and indexing an N-entry table by
        // (k*j) is structurally wrong, not a rounding difference - and building on the part already known to
        // be exact removes the whole class of error.
        const vDSP_Length samples = 2 * n;
        if (setup->forward) {
            // 1. pack z[n] = x[2n] + i*x[2n+1] over the interleaved input's real parts
            DSPDoubleComplex *packed = setup->packed;   // every entry is written below, so no clearing is needed
            // The packing reaches the input as x[2m] and x[2m+1] for m < n, which is the SAME 2*n fact the
            // inverse's output loop reaches as j < samples. One declaration, two uses.
            const double *x = &Iri[0].real;
            for (vDSP_Length j = 0; j < samples; j++) {
                const vDSP_Length m = j / 2;
                if (j % 2)
                    packed[m].imag = x[j];
                else
                    packed[m].real = x[j];
            }
            // 2. the complex forward of length N, the same loop as the complex-to-complex case above
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
            // 3. the split, with Z_N taken as Z_0:
            //       E_k = (Z_k + conj Z_{N-k}) / 2,  O_k = (Z_k - conj Z_{N-k}) / (2i),
            //       X_k = E_k + e^{-i*pi*k/N} * O_k,  and X_N = E_0 - O_0, which is real.
            //    The split is in double, and Z is in double-compensated sums, so the split's rounding is the only one
            //    left on this path; the bound it is held to is measured in tests/backports/host/vdspdftd15.
            for (vDSP_Length k = 0; k < n; k++) {
                const vDSP_Length m = (k == 0) ? 0 : n - k;            /* Z_N is Z_0 */
                const double zr = z[k].real, zi = z[k].imag;
                const double cr = z[m].real, ci = -z[m].imag;          /* conj Z_{N-k} */
                const double er = (zr + cr) / 2.0, ei = (zi + ci) / 2.0;
                const double or_ = (zi - ci) / 2.0, oi = -(zr - cr) / 2.0;   /* (z - conj)/(2i) */
                const double w = -M_PI * (double)k / (double)n;        /* e^{-i*pi*k/N} */
                const double pr = or_ * cos(w) - oi * sin(w);
                const double pi_ = or_ * sin(w) + oi * cos(w);
                if (k == 0) {
                    /* X_0 = E_0 + O_0 - the DC bin, and the general branch above would have said so, because
                     * W_0 = 1. Writing 2*E_0 here instead dropped the O_0 and put the whole DC bin out by
                     * O_0, which the bound reported as a ratio near 1e7. X_N = E_0 - O_0 is the other one and
                     * it is real. */
                    Ori[0].real = (double)(2.0 * (er + or_));
                    Ori[0].imag = (double)(2.0 * (er - or_));          /* X_N = E_0 - O_0, and it is real */
                } else {
                    Ori[k].real = (double)(2.0 * (er + pr));
                    Ori[k].imag = (double)(2.0 * (ei + pi_));
                }
            }
        } else {
            // The inverse unpacks, and the table of sixteen impulses above is this formula: o[0].real gives
            // every sample 1, o[0].imag gives (-1)^j, and o[k] gives 2*cos and -2*sin.
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
