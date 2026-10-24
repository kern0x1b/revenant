#include <math.h>
#include <revenant/__sincospi.h>
#include <stdint.h>

static const double REVENANT_PI_HIGH = 3.141592653589793116;
static const double REVENANT_PI_LOW = 1.2246467991473532072e-16;

void __sincospi(double x, double *sinp, double *cosp)
{
    if (!isfinite(x)) {
        double invalid = x - x;
        *sinp = invalid;
        *cosp = invalid;
        return;
    }

    double magnitude = fabs(x);
    if (magnitude >= 0x1p53) {
        *sinp = copysign(0.0, x);
        *cosp = 1.0;
        return;
    }

    double integer;
    double fraction = modf(magnitude, &integer);
    int odd = (int)((uint64_t)integer & 1U);
    if (fraction == 0.0) {
        *sinp = copysign(0.0, x);
        *cosp = odd ? -1.0 : 1.0;
        return;
    }

    int cosine_negative = odd;
    if (fraction > 0.5) {
        fraction = 1.0 - fraction;
        cosine_negative = !cosine_negative;
    }
    if (fraction == 0.5) {
        double sine = odd ? -1.0 : 1.0;
        *sinp = signbit(x) ? -sine : sine;
        *cosp = 0.0;
        return;
    }

    double angle = fraction * REVENANT_PI_HIGH;
    double tail = fma(fraction, REVENANT_PI_HIGH, -angle) + fraction * REVENANT_PI_LOW;
    double base_sine = sin(angle);
    double cosine = cos(angle);
    double sine = fma(tail, cosine, base_sine);
    cosine = fma(-tail, base_sine, cosine);
    if (odd)
        sine = -sine;
    if (cosine_negative)
        cosine = -cosine;
    if (signbit(x))
        sine = -sine;
    *sinp = sine;
    *cosp = cosine;
}

double __sinpi(double x)
{
    double sine;
    double cosine;
    __sincospi(x, &sine, &cosine);
    return sine;
}

double __cospi(double x)
{
    double sine;
    double cosine;
    __sincospi(x, &sine, &cosine);
    return cosine;
}

double __tanpi(double x)
{
    if (!isfinite(x))
        return x - x;

    double magnitude = fabs(x);
    if (magnitude >= 0x1p53)
        return copysign(0.0, x);

    double integer;
    double fraction = modf(magnitude, &integer);
    int negative = signbit(x);
    if (fraction == 0.0) {
        if ((uint64_t)integer & 1)
            negative = !negative;
        return copysign(0.0, negative ? -1.0 : 1.0);
    }
    if (fraction == 0.5) {
        if ((uint64_t)integer & 1)
            negative = !negative;
        return copysign(INFINITY, negative ? -1.0 : 1.0);
    }
    if (fraction > 0.5) {
        fraction = 1.0 - fraction;
        negative = !negative;
    }

    double angle = fraction * REVENANT_PI_HIGH;
    double tail = fma(fraction, REVENANT_PI_HIGH, -angle) + fraction * REVENANT_PI_LOW;
    double tangent = tan(angle);
    tangent = fma(tail, fma(tangent, tangent, 1.0), tangent);
    return negative ? -tangent : tangent;
}
