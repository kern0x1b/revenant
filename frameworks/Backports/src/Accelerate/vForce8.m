#include "../revenant_impl.h"
#import <Accelerate/Accelerate.h>
#include <math.h>

#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wunguarded-availability"

void BACKPORT_IMPL(vvcbrt)(double *y, const double *x, const int *n)
{
    if (!y || !x || !n)
        return;
    for (int i = 0; i < *n; i++)
        y[i] = cbrt(x[i]);
}

void BACKPORT_IMPL(vvcbrtf)(float *y, const float *x, const int *n)
{
    if (!y || !x || !n)
        return;
    for (int i = 0; i < *n; i++)
        y[i] = (float)cbrtf(x[i]);
}
