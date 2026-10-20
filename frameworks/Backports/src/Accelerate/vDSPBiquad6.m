#import <Accelerate/Accelerate.h>
#include <math.h>
#include <stdlib.h>
#include <string.h>

#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wpointer-bool-conversion"

struct vDSP_biquad_SetupStruct {
    vDSP_Length sections;
    double coeff[1];
};

struct vDSP_biquad_SetupStructD {
    vDSP_Length sections;
    double coeff[1];
};

static vDSP_Length revenant_biquad_delay_length(vDSP_Length sections)
{
    return 2 * (sections + 1);
}

static void revenant_biquad_create(void **setup, const double *coeffs, vDSP_Length sections)
{
    if (!coeffs) {
        *setup = NULL;
        return;
    }
    struct vDSP_biquad_SetupStruct *made = malloc(sizeof(*made) + (size_t)(sections * 5 - 1) * sizeof(double));
    if (!made) {
        *setup = NULL;
        return;
    }
    made->sections = sections;
    memcpy(made->coeff, coeffs, (size_t)sections * 5 * sizeof(double));
    *setup = made;
}

vDSP_biquad_Setup vDSP_biquad_CreateSetup(const double *__Coefficients, vDSP_Length __M)
{
    void *setup = NULL;
    revenant_biquad_create(&setup, __Coefficients, __M);
    return (vDSP_biquad_Setup)setup;
}

vDSP_biquad_SetupD vDSP_biquad_CreateSetupD(const double *__Coefficients, vDSP_Length __M)
{
    void *setup = NULL;
    revenant_biquad_create(&setup, __Coefficients, __M);
    return (vDSP_biquad_SetupD)setup;
}

void vDSP_biquad_DestroySetup(vDSP_biquad_Setup __setup)
{
    free(__setup);
}

void vDSP_biquad_DestroySetupD(vDSP_biquad_SetupD __setup)
{
    free(__setup);
}

#define REVENANT_BIQUAD_RUN(value, setup, delay, X, IX, Y, IY, N)                                            \
    do {                                                                                                    \
        const struct vDSP_biquad_SetupStruct *s_ = (const struct vDSP_biquad_SetupStruct *)(setup);          \
        const vDSP_Length sections_ = s_->sections;                                                          \
        const double *c_ = s_->coeff;                                                                       \
        const value *in_ = (const value *)(X);                                                               \
        value *out_ = (value *)(Y);                                                                           \
        value *delay_ = (value *)(delay);                                                                     \
        vDSP_Length row_, at_;                                                                               \
             \
        value *fresh_ = (value *)calloc(sections_ ? sections_ : 1, sizeof(value));                                \
             \
        value xp1_ = delay_[1], xp2_ = delay_[0];                                                     \
        if (!fresh_)                                                                                             \
            return;                                                                                                 \
        for (at_ = 0; at_ < N; at_++) {                                                                       \
            const value xn_ = in_[at_ * (IX)];                                                                \
            value previous_section_ = xn_;                                                                     \
            for (row_ = 1; row_ <= sections_; row_++) {                                                         \
                const double *c5_ = c_ + (size_t)(row_ - 1) * 5;                                                \
                const value b0_ = (value)c5_[0], b1_ = (value)c5_[1], b2_ = (value)c5_[2];                       \
                const value a1_ = (value)c5_[3], a2_ = (value)c5_[4];                                            \
                                                      \
                                             \
                const value before1_ = delay_[2 * (row_ - 1) + 1], before2_ = delay_[2 * (row_ - 1)];            \
                const value yp1_ = delay_[2 * row_ + 1], yp2_ = delay_[2 * row_];                               \
                  \
                const value acc_ = b0_ * previous_section_ + b1_ * before1_ + b2_ * before2_                  \
                                 - a1_ * yp1_ - a2_ * yp2_;                                                      \
                fresh_[row_ - 1] = acc_;                                                                         \
                previous_section_ = acc_;                                                                        \
            }                                                                                                     \
                                   \
                                                            \
            for (row_ = 1; (vDSP_Length)(2 * row_ + 1) < revenant_biquad_delay_length(sections_); row_++) {        \
                delay_[2 * row_] = delay_[2 * row_ + 1];                \
                delay_[2 * row_ + 1] = fresh_[row_ - 1];                                                          \
            }                                                                                                         \
            out_[at_ * (IY)] = previous_section_;                                                                     \
            xp2_ = xp1_;                                                                                               \
            xp1_ = xn_;                                                                                                \
            delay_[0] = xp2_;                                                                                            \
            delay_[1] = xp1_;                                                                                            \
        }                                                                                                             \
        free(fresh_);                                                                                                 \
    } while (0)

void vDSP_biquad(const struct vDSP_biquad_SetupStruct *__Setup, float *__Delay, const float *__X, vDSP_Stride __IX,
                 float *__Y, vDSP_Stride __IY, vDSP_Length __N)
{
    if (!__Setup || !__Delay || !__X || !__Y || __N < 2)
        return;
    REVENANT_BIQUAD_RUN(float, __Setup, __Delay, __X, __IX, __Y, __IY, __N);
}

void vDSP_biquadD(const struct vDSP_biquad_SetupStructD *__Setup, double *__Delay, const double *__X,
                  vDSP_Stride __IX, double *__Y, vDSP_Stride __IY, vDSP_Length __N)
{
    if (!__Setup || !__Delay || !__X || !__Y || __N < 2)
        return;
    REVENANT_BIQUAD_RUN(double, __Setup, __Delay, __X, __IX, __Y, __IY, __N);
}
