#import "CharonBiquad.h"

#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wunguarded-availability"
#pragma clang diagnostic ignored "-Wnonnull"

vDSP_biquadm_SetupD vDSP_biquadm_CreateSetupD(const double *__coeffs, vDSP_Length __M, vDSP_Length __N)
{
    return (vDSP_biquadm_SetupD)CharonBiquadCreate(__coeffs, __M, __N, 0);
}

void vDSP_biquadm_DestroySetupD(vDSP_biquadm_SetupD __setup)
{
    CharonBiquadDestroy(__setup);
}

void vDSP_biquadm_ResetStateD(vDSP_biquadm_SetupD __setup)
{
    if (__setup) {
        CharonBiquadResetState(__setup);
    }
}

void vDSP_biquadm_CopyStateD(vDSP_biquadm_SetupD __dest, const struct vDSP_biquadm_SetupStructD *__src)
{
    if (__dest && __src) {
        CharonBiquadCopyState(__dest, __src);
    }
}

void vDSP_biquadmD(vDSP_biquadm_SetupD __Setup, const double * __nonnull * __nonnull __X, vDSP_Stride __IX, double * __nonnull * __nonnull __Y,
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
            __Y[channel][n * __IY] = CharonBiquadStep(own, channels, sections, sample, 0, 0);
        }
    }
}
