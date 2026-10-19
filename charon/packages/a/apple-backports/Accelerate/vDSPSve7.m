#import <Accelerate/Accelerate.h>

#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wpointer-bool-conversion"
#pragma clang diagnostic ignored "-Wnonnull"

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
    CHARON_SVE_RUN(float, __A, __IA, __Sum, __SumOfSquares, __N);
}

void vDSP_sve_svesqD(const double *__A, vDSP_Stride __IA, double *__Sum, double *__SumOfSquares, vDSP_Length __N)
{
    if (!__A || !__Sum || !__SumOfSquares)
        return;
    CHARON_SVE_RUN(double, __A, __IA, __Sum, __SumOfSquares, __N);
}
