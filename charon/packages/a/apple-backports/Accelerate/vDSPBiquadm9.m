// The setters of the multiple-biquad filter that arrived in iOS 9.0: vDSP_biquadm_SetActiveFilters,
// vDSP_biquadm_SetCoefficientsSingle, vDSP_biquadm_SetCoefficientsDouble, vDSP_biquadm_SetTargetsSingle and
// vDSP_biquadm_SetTargetsDouble - all five on a single-precision setup.
//
// Measured from the release's armv7 caches, 10.3.4 is the first held release that exports the five (the SDK
// declares them for 9.0, which the port holds no cache of), and neither 7.1.2 nor 8.0 names any of them, so
// this file holds the API of exactly one release.
//
// What was measured, over a setup of one section and one channel unless the case says otherwise, and is
// not what the names read:
//
//   - SetActiveFilters takes one bool per section and not one per section and channel: two sections of one
//     channel answer 2 with both active and 1 with the second inactive, from an array of two.
//   - An inactive section is skipped whole. Its input passes through unchanged and its delay is left as it
//     was: a two-section setup with the second inactive answers the input itself over a constant input, and
//     answers the fresh response of that section when it is made active again.
//   - SetCoefficients takes the caller's five values per section and channel in the layout CreateSetup
//     takes, and its window of (start_sec, start_chn, nsec, nchn) is that same array: one section and two
//     channels with (0, 1, 1, 1) set to a b0 of 5 changes channel 1 and leaves channel 0.
//   - SetTargets takes the same window with the same layout, and on a single-precision setup the
//     coefficients approach their targets one sample at a time: the sample is filtered with the
//     coefficient as it stands and the coefficient then moves by (target - coefficient) * (1 -
//     interp_rate), landing exactly on the target when what is left is at most interp_threshold. Measured
//     with a b0 going from 1 to 9 and a threshold of 0.25: a rate of 0.5 has the samples of one call answer
//     1, 5, 7, 8, 8.5, 9, 9, 9; a rate of 0.1 answers 1, 8.2, 9; a rate of 0 or a threshold at or above the
//     distance puts the target in place before the first sample.
//
// The two precisions of SetCoefficients and of SetTargets answer the same, which is what the host does: the
// targets are doubles in both and the coefficients are read in the element type the caller's array holds
// (measured: a float array of 9 read by SetCoefficientsSingle and a double array of 9 read by
// SetCoefficientsDouble each set a b0 of 9, and each of them read as the other type sets something else).

#import "CharonBiquad.h"

#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wunguarded-availability"
#pragma clang diagnostic ignored "-Wnonnull"

void vDSP_biquadm_SetActiveFilters(vDSP_biquadm_Setup __setup, const bool *__filter_states)
{
    if (__setup && __filter_states) {
        CharonBiquadSetActive(__setup, __filter_states);
    }
}

void vDSP_biquadm_SetCoefficientsSingle(vDSP_biquadm_Setup __setup, const float *__coeffs, vDSP_Length __start_sec,
                                        vDSP_Length __start_chn, vDSP_Length __nsec, vDSP_Length __nchn)
{
    if (__setup && __coeffs) {
        CharonBiquadSetCoefficientsFloat(__setup, __coeffs, __start_sec, __start_chn, __nsec, __nchn);
    }
}

void vDSP_biquadm_SetCoefficientsDouble(vDSP_biquadm_Setup __setup, const double *__coeffs, vDSP_Length __start_sec,
                                        vDSP_Length __start_chn, vDSP_Length __nsec, vDSP_Length __nchn)
{
    if (__setup && __coeffs) {
        CharonBiquadSetCoefficients(__setup, __coeffs, __start_sec, __start_chn, __nsec, __nchn);
    }
}

void vDSP_biquadm_SetTargetsSingle(vDSP_biquadm_Setup __setup, const float *__targets, float __interp_rate,
                                   float __interp_threshold, vDSP_Length __start_sec, vDSP_Length __start_chn,
                                   vDSP_Length __nsec, vDSP_Length __nchn)
{
    if (__setup && __targets) {
        CharonBiquadSetTargetsFloat(__setup, __targets, __interp_rate, __interp_threshold, __start_sec, __start_chn,
                                    __nsec, __nchn);
    }
}

void vDSP_biquadm_SetTargetsDouble(vDSP_biquadm_Setup __setup, const double *__targets, float __interp_rate,
                                   float __interp_threshold, vDSP_Length __start_sec, vDSP_Length __start_chn,
                                   vDSP_Length __nsec, vDSP_Length __nchn)
{
    if (__setup && __targets) {
        CharonBiquadSetTargets(__setup, __targets, __interp_rate, __interp_threshold, __start_sec, __start_chn, __nsec,
                               __nchn);
    }
}
