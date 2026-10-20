#import <Accelerate/Accelerate.h>

#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wpointer-bool-conversion"
#pragma clang diagnostic ignored "-Wnonnull"

void vDSP_vsmsma(const float *__A, vDSP_Stride __IA, const float *__B, const float *__C, vDSP_Stride __IC,
                 const float *__D, float *__E, vDSP_Stride __IE, vDSP_Length __N)
{
    if (!__A || !__B || !__C || !__D || !__E)
        return;
    const float b = __B[0], d = __D[0];
    for (vDSP_Length n = 0; n < __N; n++) {
        const float product_a = __A[n * __IA] * b;
        const float product_c = __C[n * __IC] * d;
        __E[n * __IE] = product_a + product_c;
    }
}
