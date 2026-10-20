#pragma once

#include <math.h>

typedef struct RevenantComplex {
    double re;
    double im;
} RevenantComplex;

static inline RevenantComplex RevenantComplexMake(double re, double im)
{
    RevenantComplex value;
    value.re = re;
    value.im = im;
    return value;
}

static inline float _Complex RevenantComplexAsFloat(RevenantComplex a)
{
    float _Complex out;
    __real__ out = (float)a.re;
    __imag__ out = (float)a.im;
    return out;
}

static inline double _Complex RevenantComplexAsDouble(RevenantComplex a)
{
    double _Complex out;
    __real__ out = a.re;
    __imag__ out = a.im;
    return out;
}

static inline RevenantComplex RevenantComplexAdd(RevenantComplex a, RevenantComplex b)
{
    return RevenantComplexMake(a.re + b.re, a.im + b.im);
}

static inline RevenantComplex RevenantComplexSub(RevenantComplex a, RevenantComplex b)
{
    return RevenantComplexMake(a.re - b.re, a.im - b.im);
}

static inline RevenantComplex RevenantComplexMul(RevenantComplex a, RevenantComplex b)
{
    return RevenantComplexMake(a.re * b.re - a.im * b.im, a.re * b.im + a.im * b.re);
}

static inline RevenantComplex RevenantComplexDiv(RevenantComplex a, RevenantComplex b)
{
    double c = fabs(b.re), d = fabs(b.im);
    if (c >= d) {
        double r = 1.0 / b.re;
        double t = d * r;
        double s = 1.0 / (b.re + b.im * t);
        return RevenantComplexMake((a.re + a.im * t) * s, (a.im - a.re * t) * s);
    }
    double r = 1.0 / b.im;
    double t = c * r;
    double s = 1.0 / (b.re * t + b.im);
    return RevenantComplexMake((a.re * t + a.im) * s, (a.im * t - a.re) * s);
}

static inline int RevenantComplexIsZero(RevenantComplex a)
{
    return a.re == 0.0 && a.im == 0.0;
}

static inline double RevenantComplexModulus(RevenantComplex a)
{
    return hypot(a.re, a.im);
}

static inline double RevenantComplexPartSum(RevenantComplex a)
{
    return fabs(a.re) + fabs(a.im);
}
