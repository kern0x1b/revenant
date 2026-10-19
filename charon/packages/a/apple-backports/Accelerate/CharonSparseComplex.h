// CharonSparseComplex.h - the arithmetic the complex entry points of vecLib/Sparse/BLAS.h are made of.
//
// A complex value is a pair of doubles here, never a `float _Complex` or a `double _Complex`, and that
// is the whole reason this file exists. A product of two complex values and a division of one by
// another are the only two places where the C99 operators need a helper the compiler calls out to
// (__mulsc3, __muldc3, __divsc3, __divdc3 on this target - measured, from a translation unit that
// multiplies and divides `float _Complex` and `double _Complex` for armv7-apple-ios6.0: the four are
// the only names left undefined), and no release this port supports is asked to carry them: the
// cache index over the fifty-one held rungs puts the first of the four at 3.2 and nothing at all
// after, so an import of them would resolve, but a library that has four helper calls in it for the
// sake of four operators is worse than one that spells the two operations out. Addition, subtraction,
// negation and a real scaling need no helper at all - measured, the same object leaves none of them
// undefined - and they are written with the operators below.
//
// The parts are doubles whatever the width of the row they live in, so one loop covers both complex
// types; the width comes back only when a value is written, and CharonSparseWriteComplexValue rounds
// the pair to the width the row stores.
//
// Every name here carries a Charon prefix and every one is static inline, so the gate weighs none of
// it against a release and asks the registry about none of it (modules/apple/backports.lua,
// internal_symbol).

#pragma once

#include <math.h>

// One complex value. Two doubles, and the real part first, which is the order every layout below
// writes and the order a float row and a double row both store.
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

// A pair back into the C99 complex types the entry points return and the caller hands over. The two
// parts are assigned through the operands C99 gives a complex type, which needs no library and no
// imaginary constant.
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

// The product of two complex values, spelled out: (ar + ai i)(br + bi i) = (ar br - ai bi) +
// (ar bi + ai br) i. No helper is called and none is needed, and the one multiplication a real
// scaling does not cover is all that is left out.
static inline CharonComplex CharonComplexMul(CharonComplex a, CharonComplex b)
{
    return CharonComplexMake(a.re * b.re - a.im * b.im, a.re * b.im + a.im * b.re);
}

// The quotient of two complex values, by Smith's algorithm, which divides by a real number once:
// with |br| >= |bi| the divisor is br + (bi/br) br and the quotient is scaled by its own inverse, and
// the other way round when |bi| is the larger. Nothing is multiplied by a complex value on the way.
//
// A divisor of exactly zero is not special-cased, and needs no case: 1/0 is an infinity and 0 times an
// infinity is a NaN, so the arithmetic below carries the zero divisor into a NaN in both parts, which
// is what a complex divide by zero gives and what the host's own zero pivot answers (measured: the
// lower triangular [[0,0],[0,1]] against (1,1) answers NaN in both parts).
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

// Whether a value is exactly zero, which is what every loop below skips on and what the count of the
// nonzero elements of a vector counts. Both parts have to be zero: a value with an imaginary part and
// no real one is not a zero, and measured on the host for the complex vectors that is what decides
// (a vector of {0, 1i, 2} has two nonzero elements, not one).
static inline int CharonComplexIsZero(CharonComplex a)
{
    return a.re == 0.0 && a.im == 0.0;
}

// The two magnitudes the norms are made of, and they are not each other. |z| is the modulus,
// sqrt(re^2 + im^2), and hypot is what computes it without overflowing on the way. And |re| + |im| is
// what the one-norm of a complex value is, measured on the host and not guessed: for the vector
// {3+4i, 1} the one norm answers 8 and the modulus of the same vector is 5, so the one norm adds the
// parts and the modulus is not what it uses. The two norms are used by different norms of
// Sparse/Types.h and both are here because both are measured.
static inline double CharonComplexModulus(CharonComplex a)
{
    return hypot(a.re, a.im);
}

static inline double CharonComplexPartSum(CharonComplex a)
{
    return fabs(a.re) + fabs(a.im);
}
