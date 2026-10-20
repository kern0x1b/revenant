#import <Accelerate/Accelerate.h>

#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wpointer-bool-conversion"
#pragma clang diagnostic ignored "-Wnonnull"

void vDSP_distancesq(const float *__A, vDSP_Stride __IA, const float *__B, vDSP_Stride __IB, float *__C,
                     vDSP_Length __N)
{
    if (!__A || !__B || !__C)
        return;
    const float *a = __A, *b = __B;
    float total = 0.0f;
    for (vDSP_Length n = 0; n < __N; n++) {
        const float difference = a[n * __IA] - b[n * __IB];
        total = total + difference * difference;
    }
    *__C = total;
}
