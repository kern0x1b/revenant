// The setters of the multiple-biquad filter that arrived in iOS 16.0: vDSP_biquadm_SetActiveFiltersD,
// vDSP_biquadm_SetCoefficientsSingleD, vDSP_biquadm_SetCoefficientsDoubleD, vDSP_biquadm_SetTargetsSingleD and
// vDSP_biquadm_SetTargetsDoubleD - all five on a double-precision setup.
//
// Measured from the release's armv7 caches, 16.0 is the first held release that exports the five, so this
// file holds the API of exactly one release. They are the 9.0 file's five over the setup struct vDSP.h
// declares for them (struct vDSP_biquadm_SetupStructD), and the semantics are the 9.0 file's with the one
// difference the target setters bring and this file has to say out loud:
//
//   - vDSP_biquadm_SetTargetsSingleD and vDSP_biquadm_SetTargetsDoubleD put the target in place before the
//     first sample, whatever interp_rate and interp_threshold are. Measured with a pure gain and a constant
//     input, where the output at each sample is the coefficient that sample was filtered with, a b0 going
//     from 1 to 9 answers 9, 9, 9, 9, 9, 9 for the rates and thresholds 0.1/0.25, 0.9/0.25, 0.5/100 and
//     0/0.25, where the single-precision setup of the same file answers 1, 8.2, 9 and 1, 1.8, 2.52 and 9 and
//     9 for the first, second and third. So the two rate arguments of the double pair are stored and change
//     nothing, which is a difference from the header's wording and the registry entries for those two say so.
//   - The elements of the array are the ones the declaration names, in both cases: SetCoefficientsSingleD and
//     SetTargetsSingleD read floats and SetCoefficientsDoubleD and SetTargetsDoubleD read doubles, which is
//     measured by handing each of them a float array of 9 and a double array of 9 and watching which one
//     sets a b0 of 9.

#import "CharonBiquad.h"

#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wunguarded-availability"
#pragma clang diagnostic ignored "-Wnonnull"

void vDSP_biquadm_SetActiveFiltersD(vDSP_biquadm_SetupD __setup, const bool *__filter_states)
{
    if (__setup && __filter_states) {
        CharonBiquadSetActive(__setup, __filter_states);
    }
}

void vDSP_biquadm_SetCoefficientsSingleD(vDSP_biquadm_SetupD __setup, const float *__coeffs, vDSP_Length __start_sec,
                                         vDSP_Length __start_chn, vDSP_Length __nsec, vDSP_Length __nchn)
{
    if (__setup && __coeffs) {
        CharonBiquadSetCoefficientsFloat(__setup, __coeffs, __start_sec, __start_chn, __nsec, __nchn);
    }
}

void vDSP_biquadm_SetCoefficientsDoubleD(vDSP_biquadm_SetupD __setup, const double *__coeffs, vDSP_Length __start_sec,
                                         vDSP_Length __start_chn, vDSP_Length __nsec, vDSP_Length __nchn)
{
    if (__setup && __coeffs) {
        CharonBiquadSetCoefficients(__setup, __coeffs, __start_sec, __start_chn, __nsec, __nchn);
    }
}

void vDSP_biquadm_SetTargetsSingleD(vDSP_biquadm_SetupD __setup, const float *__targets, double __interp_rate,
                                    double __interp_threshold, vDSP_Length __start_sec, vDSP_Length __start_chn,
                                    vDSP_Length __nsec, vDSP_Length __nchn)
{
    if (__setup && __targets) {
        CharonBiquadSetTargetsFloat(__setup, __targets, __interp_rate, __interp_threshold, __start_sec, __start_chn,
                                    __nsec, __nchn);
    }
}

void vDSP_biquadm_SetTargetsDoubleD(vDSP_biquadm_SetupD __setup, const double *__targets, double __interp_rate,
                                    double __interp_threshold, vDSP_Length __start_sec, vDSP_Length __start_chn,
                                    vDSP_Length __nsec, vDSP_Length __nchn)
{
    if (__setup && __targets) {
        CharonBiquadSetTargets(__setup, __targets, __interp_rate, __interp_threshold, __start_sec, __start_chn, __nsec,
                               __nchn);
    }
}
