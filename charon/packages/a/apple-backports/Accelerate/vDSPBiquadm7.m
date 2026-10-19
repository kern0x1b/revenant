// The multiple-biquad filter of iOS 7.0, in single precision: vDSP_biquadm_CreateSetup,
// vDSP_biquadm_DestroySetup, vDSP_biquadm, vDSP_biquadm_ResetState and vDSP_biquadm_CopyState.
//
// Measured from the release's armv7 caches, 7.0 is the first held release that exports the five, and no
// earlier one does, so this file holds the API of exactly one release and the band machinery places it
// there. The release's own vDSP has all of it from 7.0 on, so this is the arithmetic for the bands the
// release's own vecLib does not reach (4.3, 5.1.1, 6.0, 6.1.3) and not a second copy of a library for the
// ones it does.
//
// The filter is M sections over N channels: vDSP.h publishes no layout for the setup, so CharonBiquad.h
// defines one and every answer below is the host's, measured case by case by tests/backports/host/vdspbiquad
// and recorded in facts/Accelerate/vDSPBiquad.md. What was measured and is not what the names read:
//
//   - The five coefficients of a section are in the order b0, b1, b2, a1, a2 and the section is
//     y[n] = b0 x[n] + b1 x[n-1] + b2 x[n-2] - a1 y[n-1] - a2 y[n-2], which is the header's own pseudocode.
//     {0.1, 0.2, 0.3, 0.4, 0.5} answers 0.1, 0.16, 0.186, -0.1544 and {1, 0, 0, 0.5, 0} answers 1, -0.5,
//     0.25, -0.125 to an impulse.
//   - The caller's coefficients are section-major and channel-minor: the block for section s and channel c
//     begins at (s * N + c) * 5. One section and two channels with the coefficients 1..10 give channel 0 a
//     b0 of 1 and channel 1 a b0 of 6.
//   - The cascade runs section 0 first: two sections with the second one's b0 at 2 answer 2.
//   - Each section and channel keeps its own two-element delay. An impulse on channel 0 of a one-section,
//     two-channel setup leaves channel 1 silent, and silent on the next call too.
//   - The delay is the state of the section in transposed direct form II, which is the two-value form that
//     carries the last two samples' input and output history; a section that is asked for one delay element
//     per sample would need four.
//   - IX and IY are element strides: an impulse at index 1 of a strided input comes out at index 1, and a
//     length of 0 leaves the output alone.
//   - CreateSetup answers NULL for no coefficients at all and where the product would overflow. **No sections
//     and no channels are not refusals**: the host answers a setup for both, and a call over M = 0 passes the
//     input through while a call over N = 0 writes nothing (measured). DestroySetup takes NULL and does
//     nothing, which the host cannot be asked about - the header does not declare that argument nullable and it
//     reads through it.

#import "CharonBiquad.h"

#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wunguarded-availability"
#pragma clang diagnostic ignored "-Wnonnull"

vDSP_biquadm_Setup vDSP_biquadm_CreateSetup(const double *__coeffs, vDSP_Length __M, vDSP_Length __N)
{
    return (vDSP_biquadm_Setup)CharonBiquadCreate(__coeffs, __M, __N, 1);
}

void vDSP_biquadm_DestroySetup(vDSP_biquadm_Setup __setup)
{
    CharonBiquadDestroy(__setup);
}

void vDSP_biquadm_ResetState(vDSP_biquadm_Setup __setup)
{
    if (__setup) {
        CharonBiquadResetState(__setup);
    }
}

void vDSP_biquadm_CopyState(vDSP_biquadm_Setup __dest, const struct vDSP_biquadm_SetupStruct *__src)
{
    if (__dest && __src) {
        CharonBiquadCopyState(__dest, __src);
    }
}

// The cascade for every channel, one sample at a time: a channel's samples do not reach any other's, so
// walking them together is the same arithmetic as walking each channel whole, and it needs one working
// value per channel instead of a copy of the input.
void vDSP_biquadm(vDSP_biquadm_Setup __Setup, const float * __nonnull * __nonnull __X, vDSP_Stride __IX, float * __nonnull * __nonnull __Y,
                  vDSP_Stride __IY, vDSP_Length __N)
{
    CharonBiquadCell *cells;
    vDSP_Length sections, channels, channel;
    if (!__Setup || !__X || !__Y) {
        return;
    }
    cells = CharonBiquadCells(__Setup);
    sections = CharonBiquadSections(__Setup);
    channels = CharonBiquadChannels(__Setup);
    for (channel = 0; channel < channels; channel++) {
        CharonBiquadCell *own = &cells[channel];
        for (vDSP_Length n = 0; n < __N; n++) {
            double sample = __X[channel][n * __IX];
            __Y[channel][n * __IY] = (float)CharonBiquadStep(own, channels, sections, sample, 1, 1);
        }
    }
}
