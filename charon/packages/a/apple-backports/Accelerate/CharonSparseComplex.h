#pragma once

#include <math.h>

typedef struct CharonComplex {
    double re;
    double im;
} CharonComplex;

static inline CharonComplex CharonComplexMake(double re, double im)
{
    CharonComplex value;
    value.re = re;
    value.im = im;
    return value;
}

static inline float _Complex CharonComplexAsFloat(CharonComplex a)
{
    float _Complex out;
    __real__ out = (float)a.re;
    __imag__ out = (float)a.im;
    return out;
}

static inline double _Complex CharonComplexAsDouble(CharonComplex a)
{
    double _Complex out;
    __real__ out = a.re;
    __imag__ out = a.im;
    return out;
}

static inline CharonComplex CharonComplexAdd(CharonComplex a, CharonComplex b)
{
    return CharonComplexMake(a.re + b.re, a.im + b.im);
}

static inline CharonComplex CharonComplexSub(CharonComplex a, CharonComplex b)
{
    return CharonComplexMake(a.re - b.re, a.im - b.im);
}

static inline CharonComplex CharonComplexMul(CharonComplex a, CharonComplex b)
{
    return CharonComplexMake(a.re * b.re - a.im * b.im, a.re * b.im + a.im * b.re);
}

static inline CharonComplex CharonComplexDiv(CharonComplex a, CharonComplex b)
{
    double c = fabs(b.re), d = fabs(b.im);
    if (c >= d) {
        double r = 1.0 / b.re;
        double t = d * r;
        double s = 1.0 / (b.re + b.im * t);
        return CharonComplexMake((a.re + a.im * t) * s, (a.im - a.re * t) * s);
    }
    double r = 1.0 / b.im;
    double t = c * r;
    double s = 1.0 / (b.re * t + b.im);
    return CharonComplexMake((a.re * t + a.im) * s, (a.im * t - a.re) * s);
}

static inline int CharonComplexIsZero(CharonComplex a)
{
    return a.re == 0.0 && a.im == 0.0;
}

static inline double CharonComplexModulus(CharonComplex a)
{
    return hypot(a.re, a.im);
}

static inline double CharonComplexPartSum(CharonComplex a)
{
    return fabs(a.re) + fabs(a.im);
}
