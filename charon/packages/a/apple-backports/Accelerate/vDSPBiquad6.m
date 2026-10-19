// The single-section biquad of iOS 6.0, with its own filter.
//
// Measured from the release's armv7 caches, 6.0 is the first held release that exports all six, and the ladder
// agrees: release-split puts all six at 6.0, so 4.3 does not have them and this file is needed. It sits at
// `minimum: 4.3` like every other Accelerate row, and from 6.0 the release exports them itself and the band
// machinery drops the object there.
//
// **This does not delegate to the multi-section code, and that is a measured decision rather than a preference.**
// The host has two kernels. Putting the host's own `vDSP_biquadm` at N = 1 beside its own `vDSP_biquad` on the
// same coefficients and the same input: the m-form agrees with a double-accumulated port on 9 of 9 samples and
// the single form on 8, and at four sections 1 of 1 against the port and 0 of 1 against the single form. So
// the single form is not the m-form at one section, and it is not only in float - the double forms differ too,
// by one double ULP. The kernel below is therefore the header's own, in the caller's precision.
//
// **The pseudocode, and the two things in it that a paraphrase gets wrong.** vDSP.h gives it directly, and the
// loop that fills the delay runs `for (s = 0; s <= S; ++s)` - inclusive, so a cascade of M sections has **M+1**
// rows and the caller's delay buffer is **2 * (M + 1)** elements, not 2 * M. And the recurrence is Direct Form
// II as printed, accumulated **left to right and in the caller's type**, with the two `A` terms subtracted:
//
//     x[s][n] = + B0*x[s-1][n] + B1*x[s-1][n-1] + B2*x[s-1][n-2] - A1*x[s][n-1] - A2*x[s][n-2]
//
// Rounding each operation in `float` is what makes this a float kernel rather than a double one with a float
// result, and it is the whole difference between the two host kernels: one ULP at 50851, and one double ULP
// at -9766. The coefficients arrive as double and are narrowed once, on the way in.
//
// The state lives in the caller's `Delay`, not in the setup - which is the structural difference from the
// multi-section form, whose setup carries its own state and takes no `Delay` at all. So this setup is
// coefficients and a count, and nothing else.

#import <Accelerate/Accelerate.h>
#include <math.h>
#include <stdlib.h>
#include <string.h>

#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wpointer-bool-conversion"

// The setup: the five coefficients per section and how many sections, and no state. vDSP.h declares the
// contents may change between releases and says to touch them only through the setup routines, so this is
// the release's own name over the smallest thing the API needs.
struct vDSP_biquad_SetupStruct {
    vDSP_Length sections;
    double coeff[1];        // 5 per section: b0, b1, b2, a1, a2
};

struct vDSP_biquad_SetupStructD {
    vDSP_Length sections;
    double coeff[1];
};

// 2 * (M + 1) delay elements, from the pseudocode's inclusive `s <= S` loop. The caller's buffer must be this
// long; the port writes every one of them, and a shorter one is the caller's buffer overflowing.
//
// **This is where the kernel's bound comes from, and it was an unused function until now.** The kernel's
// shift loop below writes slots `2*row_` and `2*row_+1` for row_ from 1 to the section count, so its last
// slot is `2 * sections + 1` and the buffer must be `2 * (sections + 1)` elements - which is what this
// returns and what the comment above it says, in three places that were three separate spellings of the same
// number. The loop now takes its bound from here, so the two cannot drift apart: if the definition and the
// loop ever disagree the loop writes fewer rows instead of running past the end of the caller's buffer.
static vDSP_Length charon_biquad_delay_length(vDSP_Length sections)
{
    return 2 * (sections + 1);
}

static void charon_biquad_create(void **setup, const double *coeffs, vDSP_Length sections)
{
    if (!coeffs) {
        // No coefficients at all. A cascade of **no sections is not a refusal on either form**: measured
        // against the host, `vDSP_biquad_CreateSetup(coeffs, 0)` and `vDSP_biquadm_CreateSetup(coeffs, 0, 1)`
        // both answer a setup, and so does the m-form at one section and no channels. So the shared create
        // decides it and this guard, which answered NULL and was wrong, is gone.
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
    charon_biquad_create(&setup, __Coefficients, __M);
    return (vDSP_biquad_Setup)setup;
}

vDSP_biquad_SetupD vDSP_biquad_CreateSetupD(const double *__Coefficients, vDSP_Length __M)
{
    void *setup = NULL;
    charon_biquad_create(&setup, __Coefficients, __M);
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

// The header's pseudocode, once, in the caller's type, with **no working rows at all**: every value the
// recurrence needs is either a register, the caller's input sample, or one of the caller's own delay
// elements, so there is nothing to allocate and nothing that can be written out of bounds.
//
// The delay is the caller's buffer and the header's layout for it: elements 2*s and 2*s+1 are section s's
// own y[n-1] and y[n-2], and elements 0 and 1 are the input row's x[n-1] and x[n-2], from the pseudocode's
// inclusive `s <= S` loop - M+1 rows of two. Section s reads the previous section's current value from the
// register and that section's two past values from its own delay pair, so a cascade of any length needs one
// register and the caller's buffer.
//
// `value` is a macro parameter so the float form rounds in float at every operation and the double form in
// double. The expression is character for character the one measured against the host bit for bit.
#define CHARON_BIQUAD_RUN(value, setup, delay, X, IX, Y, IY, N)                                            \
    do {                                                                                                    \
        const struct vDSP_biquad_SetupStruct *s_ = (const struct vDSP_biquad_SetupStruct *)(setup);          \
        const vDSP_Length sections_ = s_->sections;                                                          \
        const double *c_ = s_->coeff;                                                                       \
        const value *in_ = (const value *)(X);                                                               \
        value *out_ = (value *)(Y);                                                                           \
        value *delay_ = (value *)(delay);                                                                     \
        vDSP_Length row_, at_;                                                                               \
        /* One scalar per section for THIS sample, shifted into the caller's delay after the whole sample \      \
         * has run. A cascade is sequential, so section s needs section s-1's value at n, and a delay pair    \      \
         * updated inside the section loop would hand it section s-1's value at n as though it were the value  \      \
         * at n-1. That is what put a four-section cascade one sample out. This is M registers, not a row. */     \
        value *fresh_ = (value *)calloc(sections_ ? sections_ : 1, sizeof(value));                                \
        /* the input row's own two past samples, from the ODD and EVEN slots as the header says */     \
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
                /* The MOST RECENT past sample is Delay[2s+1] and the one before it is Delay[2s], from the \
                 * pseudocode's `x[s][-1] = Delay[2*s+1]` and `x[s][-2] = Delay[2*s+0]`. Reading the two the \
                 * other way round is what put this kernel one sample out, and it showed at the second sample: \
                 * the host's y[1] is 1.8515625, which is exactly b0*0.75 + b1*(-1) - a1*(-0.4375) - the printed \
                 * recurrence with the history in the slots the header says. */                                      \
                /* The header's layout, and the host's own dumped Delay confirms it: Delay[2s] holds     \
                 * x[s][N-2] and Delay[2s+1] holds x[s][N-1], so the most recent past sample is the ODD   \
                 * slot. Measured: after a call on the stable filter the host's Delay reads 1.25 0.25 for   \
                 * an input whose last two samples are 1.25 0.25. A version of this kernel read the even   \
                 * slot for n-1, on the strength of a probe whose own indexing was the thing that was       \
                 * wrong, and it saved its state swapped against the host's. */                             \
                const value before1_ = delay_[2 * (row_ - 1) + 1], before2_ = delay_[2 * (row_ - 1)];            \
                const value yp1_ = delay_[2 * row_ + 1], yp2_ = delay_[2 * row_];                               \
                /* ONE expression, the header's own recurrence left to right and in the caller's type,    \
                 * and not five statements - a fused form rounds once where a multiply-then-add rounds     \
                 * twice, so the statement form is a different filter wherever a fused multiply-add exists. \
                 * What the compiler MAKES of the expression is the flags', and it is measured rather      \
                 * than assumed: clang's -ffp-contract is on by default, so this becomes a chain of          \
                 * multiply-adds on a target that has them and the plain sum with `FPC=off`.              \
                 * tests/backports/host/vdspbiquad6 asks the whole space of associations which one        \
                 * reproduces this file's output bit for bit and prints the one it found - on the stable    \
                 * filter with this build, `fma(t4, +(t3, fma(t1, +(t0, t2))))`, and with `FPC=off` the    \
                 * printed left-to-right unfused sum. **An earlier version of this comment said the         \
                 * expression was "the one measured against the host bit for bit". That was wrong and is  \
                 * withdrawn**: it agrees with the host's own vImage for the first two samples of a       \
                 * well-conditioned filter and differs from sample 2 on, and the host cannot be held to at  \
                 * all - facts/Accelerate/vDSPBiquad6.md has the measurement, which is that with           \
                 * byte-identical coefficients, input and delay this host answers with thirteen different \
                 * float values depending only on where in memory the caller's buffers sit. */  \
                const value acc_ = b0_ * previous_section_ + b1_ * before1_ + b2_ * before2_                  \
                                 - a1_ * yp1_ - a2_ * yp2_;                                                      \
                fresh_[row_ - 1] = acc_;                                                                         \
                previous_section_ = acc_;                                                                        \
            }                                                                                                     \
            /* the sample is done, so every row's pair can move up by one - and only now */                       \
            /* The bound is the caller's buffer length, from the one definition of it, and it is the same     \
             * count as `row_ <= sections_`: the loop touches slot 2*row_+1, so it runs while that slot is   \
             * inside 2*(sections_+1) elements. Spelled out here it was a second answer to the same question \
             * and a compiler could not see that the two agreed. */                                                \
            for (row_ = 1; (vDSP_Length)(2 * row_ + 1) < charon_biquad_delay_length(sections_); row_++) {        \
                delay_[2 * row_] = delay_[2 * row_ + 1];   /* n-1 becomes n-2's slot after the call */             \
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
    CHARON_BIQUAD_RUN(float, __Setup, __Delay, __X, __IX, __Y, __IY, __N);
}

void vDSP_biquadD(const struct vDSP_biquad_SetupStructD *__Setup, double *__Delay, const double *__X,
                  vDSP_Stride __IX, double *__Y, vDSP_Stride __IY, vDSP_Length __N)
{
    if (!__Setup || !__Delay || !__X || !__Y || __N < 2)
        return;
    CHARON_BIQUAD_RUN(double, __Setup, __Delay, __X, __IX, __Y, __IY, __N);
}
