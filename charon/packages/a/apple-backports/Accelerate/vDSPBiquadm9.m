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
