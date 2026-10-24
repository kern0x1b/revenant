#include <math.h>
#include <revenant/__sincospif.h>
#include <stdint.h>

static const double REVENANT_PI_HIGH = 3.141592653589793116;
static const double REVENANT_PI_LOW = 1.2246467991473532072e-16;

void __sincospif(float x, float *sinp, float *cosp)
{
    if (!isfinite(x)) {
        float invalid = x - x;
        *sinp = invalid;
        *cosp = invalid;
        return;
    }

    float magnitude = fabsf(x);
    if (magnitude >= 0x1p24f) {
        *sinp = copysignf(0.0f, x);
        *cosp = 1.0f;
        return;
    }

    unsigned int integer = (unsigned int)magnitude;
    float fraction = magnitude - (float)integer;
    if (fraction == 0.0f) {
        *sinp = copysignf(0.0f, x);
        *cosp = integer & 1 ? -1.0f : 1.0f;
        return;
    }

    int cosine_negative = integer & 1;
    if (fraction > 0.5f) {
        fraction = 1.0f - fraction;
        cosine_negative = !cosine_negative;
    }
    if (fraction == 0.5f) {
        float sine = integer & 1 ? -1.0f : 1.0f;
        *sinp = signbit(x) ? -sine : sine;
        *cosp = 0.0f;
        return;
    }

    double reduced = (double)fraction;
    double angle = reduced * REVENANT_PI_HIGH + reduced * REVENANT_PI_LOW;
    double sine = sin(angle);
    double cosine = cos(angle);
    if (integer & 1)
        sine = -sine;
    if (cosine_negative)
        cosine = -cosine;
    if (signbit(x))
        sine = -sine;
    *sinp = (float)sine;
    *cosp = (float)cosine;
}

float __sinpif(float x)
{
    float sine;
    float cosine;
    __sincospif(x, &sine, &cosine);
    return sine;
}

float __cospif(float x)
{
    float sine;
    float cosine;
    __sincospif(x, &sine, &cosine);
    return cosine;
}

float __tanpif(float x)
{
    if (!isfinite(x))
        return x - x;

    double magnitude = fabs((double)x);
    if (magnitude >= 0x1p53)
        return copysignf(0.0f, x);

    double integer;
    double fraction = modf(magnitude, &integer);
    int negative = signbit(x);
    if (fraction == 0.0) {
        if ((uint64_t)integer & 1)
            negative = !negative;
        return copysignf(0.0f, negative ? -1.0f : 1.0f);
    }
    if (fraction == 0.5) {
        if ((uint64_t)integer & 1)
            negative = !negative;
        return copysignf(INFINITY, negative ? -1.0f : 1.0f);
    }
    if (fraction > 0.5) {
        fraction = 1.0 - fraction;
        negative = !negative;
    }

    double angle = fraction * REVENANT_PI_HIGH;
    double tail = fma(fraction, REVENANT_PI_HIGH, -angle) + fraction * REVENANT_PI_LOW;
    double tangent = tan(angle);
    tangent = fma(tail, fma(tangent, tangent, 1.0), tangent);
    return (float)(negative ? -tangent : tangent);
}
