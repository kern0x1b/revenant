#ifndef REVENANT_SINPI_H
#define REVENANT_SINPI_H

#pragma clang fp contract(off)

#include <math.h>

double __sinpi(double);
double __cospi(double);
double __tanpi(double);
void __sincospi(double, double *, double *);
float __sinpif(float);
float __cospif(float);
float __tanpif(float);
void __sincospif(float, float *, float *);

static const double REVENANT_PI_HI = 0x1.921fb54442d18p+1;
static const double REVENANT_PI_LO = 0x1.1a62633145c07p-53;
static const double REVENANT_PI_HI_HEAD = 0x1.921fb5p+1;
static const double REVENANT_PI_HI_TAIL = 0x4442d18p-51;
static const double REVENANT_SPLIT = 134217729.0;

static inline void revenant_split(double value, double *high, double *low)
{
    const double scaled = REVENANT_SPLIT * value;
    *high = scaled - (scaled - value);
    *low = value - *high;
}

static inline void revenant_sinpi_kernel(double h, double *sine, double *sine_tail, double *cosine, double *cosine_tail)
{
    const double z = h * h;
    double high;
    double low;
    revenant_split(h, &high, &low);
    const double p = h * REVENANT_PI_HI;
    const double err = ((high * REVENANT_PI_HI_HEAD - p) + high * REVENANT_PI_HI_TAIL + low * REVENANT_PI_HI_HEAD) + low * REVENANT_PI_HI_TAIL;
    const double lo = err + h * REVENANT_PI_LO;

    double s = -7.304711822217774797088e-9;
    s = s * z + 2.531217404137027651352e-7;
    s = s * z - 6.975873661656380474534e-6;
    s = s * z + 1.484287930310710036849e-4;
    s = s * z - 2.346081035455823637509e-3;
    s = s * z + 2.614784781765480050465e-2;
    s = s * z - 1.907518241220842136965e-1;
    s = s * z + 8.117424252833536436370e-1;
    s = s * z - 1.644934066848226436472e0;
    const double corr = lo + (p + lo) * (z * s);
    const double sine_hi = p + corr;
    *sine = sine_hi;
    *sine_tail = (p - sine_hi) + corr;

    double c = -1.387895246221377211447e-7;
    c = c * z + 4.303069587032947007298e-6;
    c = c * z - 1.046381049248457071180e-4;
    c = c * z + 1.929574309403923047903e-3;
    c = c * z - 2.580689139001406001260e-2;
    c = c * z + 2.353306303588932045419e-1;
    c = c * z - 1.335262768854589495875e0;
    c = c * z + 4.058712126416768218185e0;
    c = c * z - 4.934802200544679309417e0;
    const double d = z * c;
    const double cos_hi = 1.0 + d;
    *cosine = cos_hi;
    *cosine_tail = (1.0 - cos_hi) + d;
}

static inline void revenant_sincospi_core(double x, double *sinp, double *sinp_tail, double *cosp, double *cosp_tail)
{
    const double a = __builtin_fabs(x);
    if (!(a < INFINITY)) {
        *sinp = x - x;
        *sinp_tail = 0.0;
        *cosp = x - x;
        *cosp_tail = 0.0;
        return;
    }
    if (a >= 0x1p53) {
        *sinp = __builtin_copysign(0.0, x);
        *sinp_tail = 0.0;
        *cosp = 1.0;
        *cosp_tail = 0.0;
        return;
    }
    double ip = a;
    double f = 0.0;
    if (a < 0x1p52) {
        double r = (a + 0x1p52) - 0x1p52;
        if (r > a)
            r -= 1.0;
        ip = r;
        f = a - r;
    }
    const double half = ip * 0.5;
    const int odd = half != (half + 0x1p52) - 0x1p52;
    const int flip = f > 0.5;
    const double g = flip ? 1.0 - f : f;
    const int swap = g > 0.25;
    const double h = swap ? 0.5 - g : g;
    double ks;
    double ks_tail;
    double kc;
    double kc_tail;
    revenant_sinpi_kernel(h, &ks, &ks_tail, &kc, &kc_tail);
    const double sg = swap ? kc : ks;
    const double sg_tail = swap ? kc_tail : ks_tail;
    const double cg = swap ? ks : kc;
    const double cg_tail = swap ? ks_tail : kc_tail;
    const double sign_ip = odd ? -1.0 : 1.0;
    const double sign_x = signbit(x) ? -1.0 : 1.0;
    if (sg == 0.0) {
        *sinp = __builtin_copysign(0.0, x);
        *sinp_tail = 0.0;
    } else {
        const double sign = sign_x * sign_ip;
        *sinp = sign * sg;
        *sinp_tail = sign * sg_tail;
    }
    if (cg == 0.0) {
        *cosp = 0.0;
        *cosp_tail = 0.0;
    } else {
        const double sign = flip ? -sign_ip : sign_ip;
        *cosp = sign * cg;
        *cosp_tail = sign * cg_tail;
    }
}

static inline double revenant_tanpi_core(double x)
{
    double sine;
    double sine_tail;
    double cosine;
    double cosine_tail;
    revenant_sincospi_core(x, &sine, &sine_tail, &cosine, &cosine_tail);
    if (cosine == 0.0)
        return sine / cosine;
    const double q = sine / cosine;
    double product_high;
    double product_low;
    {
        double qh;
        double ql;
        double ch;
        double cl;
        revenant_split(q, &qh, &ql);
        revenant_split(cosine, &ch, &cl);
        product_high = q * cosine;
        product_low = ((qh * ch - product_high) + qh * cl + ql * ch) + ql * cl;
    }
    const double residual = (((sine - product_high) - product_low) + sine_tail) - q * cosine_tail;
    return q + residual / cosine;
}

#endif
