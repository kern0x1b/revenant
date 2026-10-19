// vForce's cube root, the two entry points iOS 8.0 added: vvcbrt and vvcbrtf.
//
// Measured from the release's armv7 caches, 8.0 is the first held release that exports the two, so this
// file holds the API of exactly one release. vForce's header (vForce.h:38-40) says that the family may flush
// some or all denormal numbers to zero, and that a denormal's result depends on the microarchitecture and on
// the OS version, so the two are answered with libm's cbrt - the same number the header's own pseudocode computes - and the host
// differential compares them with a tolerance, and its numbers are what facts/Accelerate/vForce.md
// records.

#import <Accelerate/Accelerate.h>
#include <math.h>

#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wunguarded-availability"

// The length is a pointer and the caller names it there, as vForce's whole family does - an array of one is
// the common case and a NULL length is a caller's mistake the header does not describe, so it does nothing.
void vvcbrt(double *y, const double *x, const int *n)
{
    if (!y || !x || !n)
        return;
    for (int i = 0; i < *n; i++)
        y[i] = cbrt(x[i]);
}

void vvcbrtf(float *y, const float *x, const int *n)
{
    if (!y || !x || !n)
        return;
    for (int i = 0; i < *n; i++)
        y[i] = (float)cbrtf(x[i]);
}
