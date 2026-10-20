#import <Accelerate/Accelerate.h>

struct vDSP_biquad_SetupStruct {
    vDSP_Length sections;
    double coeff[1];
};

static inline void revenant_biquad15_set(void *setup, vDSP_Length section, const double *block)
{
    struct vDSP_biquad_SetupStruct *asSetup = (struct vDSP_biquad_SetupStruct *)setup;
    if (section >= asSetup->sections) {
        return;
    }
    double *into = asSetup->coeff + (size_t)section * 5;
    for (int k = 0; k < 5; k++) {
        into[k] = block[k];
    }
}

void vDSP_biquad_SetCoefficientsDouble(vDSP_biquad_Setup __setup, const double *__coeffs, vDSP_Length __start_sec,
                                       vDSP_Length __nsec)
{
    if (!__setup || !__coeffs) {
        return;
    }
    for (vDSP_Length at = 0; at < __nsec; at++) {
        revenant_biquad15_set(__setup, __start_sec + at, __coeffs + (size_t)at * 5);
    }
}

void vDSP_biquad_SetCoefficientsSingle(vDSP_biquad_Setup __setup, const float *__coeffs, vDSP_Length __start_sec,
                                       vDSP_Length __nsec)
{
    if (!__setup || !__coeffs) {
        return;
    }
    for (vDSP_Length at = 0; at < __nsec; at++) {
        double block[5];
        for (int k = 0; k < 5; k++) {
            block[k] = (double)__coeffs[(size_t)at * 5 + k];
        }
        revenant_biquad15_set(__setup, __start_sec + at, block);
    }
}
