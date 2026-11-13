#include <stdint.h>
#include <string.h>

enum {
    HALF_MANTISSA_BITS = 10,
    HALF_BIAS = 15,
    HALF_INFINITY = 0x7c00,
    HALF_QUIET_NAN = 0x7e00,
    SINGLE_EXPONENT_BITS = 8,
    SINGLE_MANTISSA_BITS = 23,
    DOUBLE_EXPONENT_BITS = 11,
    DOUBLE_MANTISSA_BITS = 52
};

static uint32_t narrow(uint64_t bits, unsigned exponent_bits, unsigned mantissa_bits) {
    uint32_t sign = (uint32_t)(bits >> (exponent_bits + mantissa_bits)) & 1;
    uint32_t exponent = (uint32_t)(bits >> mantissa_bits) & ((1u << exponent_bits) - 1);
    uint64_t mantissa = bits & ((UINT64_C(1) << mantissa_bits) - 1);
    uint32_t sign_bit = sign << 15;
    if (exponent == (1u << exponent_bits) - 1) {
        if (mantissa == 0) {
            return sign_bit | HALF_INFINITY;
        }
        return sign_bit | HALF_QUIET_NAN | (uint32_t)(mantissa >> (mantissa_bits - HALF_MANTISSA_BITS));
    }

    int target = (int)(exponent ? exponent : 1) - (int)((1u << (exponent_bits - 1)) - 1) + HALF_BIAS;
    unsigned shift = mantissa_bits - HALF_MANTISSA_BITS;
    if (exponent) {
        mantissa |= UINT64_C(1) << mantissa_bits;
    }
    if (target < 1) {
        shift += (unsigned)(1 - target);
        target = 0;
    }
    if (shift > 62) {
        return sign_bit;
    }

    uint64_t kept = mantissa >> shift;
    uint64_t dropped = mantissa & ((UINT64_C(1) << shift) - 1);
    uint64_t halfway = UINT64_C(1) << (shift - 1);
    if (dropped > halfway || (dropped == halfway && (kept & 1))) {
        kept++;
    }
    uint64_t result = (target ? (uint64_t)(target - 1) << HALF_MANTISSA_BITS : 0) + kept;
    return sign_bit | (result >= HALF_INFINITY ? HALF_INFINITY : (uint32_t)result);
}

static uint64_t widen(uint32_t half, unsigned exponent_bits, unsigned mantissa_bits) {
    uint64_t sign = (uint64_t)((half >> 15) & 1) << (exponent_bits + mantissa_bits);
    uint32_t exponent = (half >> HALF_MANTISSA_BITS) & 0x1f;
    uint64_t mantissa = half & ((1u << HALF_MANTISSA_BITS) - 1);
    int rebias = (int)((1u << (exponent_bits - 1)) - 1) - HALF_BIAS;
    if (exponent == 0x1f) {
        uint64_t payload = mantissa ? (mantissa << (mantissa_bits - HALF_MANTISSA_BITS)) | (UINT64_C(1) << (mantissa_bits - 1)) : 0;
        return sign | (((UINT64_C(1) << exponent_bits) - 1) << mantissa_bits) | payload;
    }
    if (exponent == 0) {
        if (mantissa == 0) {
            return sign;
        }
        unsigned top = 31 - (unsigned)__builtin_clz((unsigned)mantissa);
        uint64_t fraction = (mantissa << (mantissa_bits - top)) & ((UINT64_C(1) << mantissa_bits) - 1);
        return sign | (uint64_t)((int)top - 9 + rebias) << mantissa_bits | fraction;
    }
    return sign | (uint64_t)((int)exponent + rebias) << mantissa_bits | mantissa << (mantissa_bits - HALF_MANTISSA_BITS);
}

uint32_t rellume_aarch64_fcvt_h_s(float value) {
    uint32_t bits;
    memcpy(&bits, &value, sizeof(bits));
    return narrow(bits, SINGLE_EXPONENT_BITS, SINGLE_MANTISSA_BITS);
}

uint32_t rellume_aarch64_fcvt_h_d(double value) {
    uint64_t bits;
    memcpy(&bits, &value, sizeof(bits));
    return narrow(bits, DOUBLE_EXPONENT_BITS, DOUBLE_MANTISSA_BITS);
}

float rellume_aarch64_fcvt_s_h(uint32_t half) {
    uint32_t bits = (uint32_t)widen(half & 0xffff, SINGLE_EXPONENT_BITS, SINGLE_MANTISSA_BITS);
    float value;
    memcpy(&value, &bits, sizeof(value));
    return value;
}

double rellume_aarch64_fcvt_d_h(uint32_t half) {
    uint64_t bits = widen(half & 0xffff, DOUBLE_EXPONENT_BITS, DOUBLE_MANTISSA_BITS);
    double value;
    memcpy(&value, &bits, sizeof(value));
    return value;
}
