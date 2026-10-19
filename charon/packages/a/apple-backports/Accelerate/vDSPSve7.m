// The sum and sum-of-squares reductions of iOS 6.0: vDSP_sve_svesq and vDSP_sve_svesqD.
//
// Measured from the release's armv7 caches, 6.0 is the first held release that exports the pair, and
// release-split places both at 6.0, so 4.3 does not have them and this file is needed. It carries
// `minimum: 4.3` like every other Accelerate row, and from 6.0 the release exports them itself.
//
// **Everything here happens in the caller's own type, and that is measured rather than assumed.** The
// decisive case is four denormals: the host's sum of squares comes back **exactly zero**, because each
// square of a value around 1e-42 underflows to zero in float. A double accumulator would have given
// about 4e-84, which double can represent comfortably, so the host is not accumulating wider than the
// caller asked for. The float form's sum of squares also carries the small offsets in the inputs -
// 63 near-equal pairs give 64.0000076 - which a wider accumulator would have washed out.
//
// The accumulation is left-to-right in the caller's type, which is what the sequential form in
// tests/backports/host/vdspsve is checked against a hand-computed exact value at small N **before** any
// comparison with the host, because a differential whose expected values come from the host cannot tell
// a correct implementation from one that reproduces the host's mistake.

#import <Accelerate/Accelerate.h>

#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wpointer-bool-conversion"
#pragma clang diagnostic ignored "-Wnonnull"

// The one loop, instantiated in each type. A reduction has no printed form in the header, so the order is
// the one the differential proves: sequential, left to right, in the caller's type.
#define CHARON_SVE_RUN(value, A, IA, Sum, SumOfSquares, N)                    \
    do {                                                                       \
        const value *in_ = (const value *)(A);                                 \
        value sum_ = 0, squares_ = 0;                                          \
        for (vDSP_Length at_ = 0; at_ < (N); at_++) {                          \
            const value sample_ = in_[at_ * (IA)];                             \
            sum_ = sum_ + sample_;                                             \
            squares_ = squares_ + sample_ * sample_;                           \
        }                                                                       \
        *(Sum) = sum_;                                                         \
        *(SumOfSquares) = squares_;                                            \
    } while (0)

void vDSP_sve_svesq(const float *__A, vDSP_Stride __IA, float *__Sum, float *__SumOfSquares, vDSP_Length __N)
{
    if (!__A || !__Sum || !__SumOfSquares)
        return;
    // **N = 0 is not a refusal and not untouched memory: the host answers 0 and 0.** The loop below writes
    // both from its initialiser, so it agrees without a case of its own - measured, and recorded in the
    // facts file.
    CHARON_SVE_RUN(float, __A, __IA, __Sum, __SumOfSquares, __N);
}

void vDSP_sve_svesqD(const double *__A, vDSP_Stride __IA, double *__Sum, double *__SumOfSquares, vDSP_Length __N)
{
    if (!__A || !__Sum || !__SumOfSquares)
        return;
    CHARON_SVE_RUN(double, __A, __IA, __Sum, __SumOfSquares, __N);
}
