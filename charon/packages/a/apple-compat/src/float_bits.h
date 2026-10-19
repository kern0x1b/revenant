#ifndef CHARON_FLOAT_BITS_H
#define CHARON_FLOAT_BITS_H

static unsigned long long charon_rounded(unsigned long long value, int precision, int *exponent)
{
    int digits = 64 - __builtin_clzll(value);
    *exponent = digits - 1;
    if (digits <= precision)
        return value << (precision - digits);
    int dropped = digits - precision;
    unsigned long long kept = value >> dropped;
    unsigned long long rest = value & ((1ULL << dropped) - 1);
    unsigned long long half = 1ULL << (dropped - 1);
    if (rest > half || (rest == half && (kept & 1)))
        kept++;
    if (kept >> precision) {
        kept >>= 1;
        ++*exponent;
    }
    return kept;
}

static double charon_double(unsigned long long value)
{
    if (value == 0)
        return 0.0;
    int exponent;
    unsigned long long mantissa = charon_rounded(value, 53, &exponent);
    unsigned long long bits = ((unsigned long long)(exponent + 1023) << 52) | (mantissa & ((1ULL << 52) - 1));
    double result;
    __builtin_memcpy(&result, &bits, sizeof result);
    return result;
}

static float charon_float(unsigned long long value)
{
    if (value == 0)
        return 0.0f;
    int exponent;
    unsigned long long mantissa = charon_rounded(value, 24, &exponent);
    unsigned int bits = ((unsigned int)(exponent + 127) << 23) | (unsigned int)(mantissa & 0x7FFFFF);
    float result;
    __builtin_memcpy(&result, &bits, sizeof result);
    return result;
}

#endif
