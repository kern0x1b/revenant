#ifndef REVENANT_HAP_BIGNUM_H
#define REVENANT_HAP_BIGNUM_H

#include <stdint.h>
#include <string.h>

#define BN_LIMBS 96
#define BN_BITS (BN_LIMBS * 32)

typedef struct {
    uint32_t limb[BN_LIMBS];
} BigNum;

static inline void revenant_bn_zero(BigNum *out)
{
    memset(out->limb, 0, sizeof(out->limb));
}

static inline void revenant_bn_set_u32(BigNum *out, uint32_t value)
{
    revenant_bn_zero(out);
    out->limb[0] = value;
}

void revenant_bn_from_bytes(BigNum *out, const uint8_t *bytes, size_t length);
void revenant_bn_to_bytes(uint8_t *bytes, size_t length, const BigNum *value);

void revenant_bn_from_bytes_be(BigNum *out, const uint8_t *bytes, size_t length);
void revenant_bn_to_bytes_be(uint8_t *bytes, size_t length, const BigNum *value);

static inline int revenant_bn_cmp(const BigNum *left, const BigNum *right)
{
    for (int index = BN_LIMBS - 1; index >= 0; --index) {
        if (left->limb[index] != right->limb[index])
            return left->limb[index] < right->limb[index] ? -1 : 1;
    }
    return 0;
}

static inline int revenant_bn_is_zero(const BigNum *value)
{
    for (int index = 0; index < BN_LIMBS; ++index) {
        if (value->limb[index])
            return 0;
    }
    return 1;
}

static inline int revenant_bn_is_odd(const BigNum *value)
{
    return value->limb[0] & 1;
}

static inline int revenant_bn_bits(const BigNum *value)
{
    for (int index = BN_LIMBS - 1; index >= 0; --index) {
        if (value->limb[index]) {
            int bit = 0;
            uint32_t limb = value->limb[index];
            while (limb) {
                limb >>= 1;
                ++bit;
            }
            return index * 32 + bit;
        }
    }
    return 0;
}

size_t revenant_bn_byte_length(const BigNum *value);
int revenant_bn_equal_bytes(const BigNum *left, const uint8_t *right, size_t length);

uint32_t revenant_bn_add(BigNum *out, const BigNum *left, const BigNum *right);
void revenant_bn_sub(BigNum *out, const BigNum *left, const BigNum *right);

typedef struct {
    BigNum modulus;
    BigNum r2;
    uint32_t inverse;
    int limbs;
} BigNumMont;

void revenant_bn_mont_prepare(BigNumMont *mont, const BigNum *modulus);
void revenant_bn_mont_mul(const BigNumMont *mont, BigNum *out, const BigNum *left, const BigNum *right);
void revenant_bn_mont_reduce(const BigNumMont *mont, BigNum *out, const BigNum *value);
void revenant_bn_mont_pow(const BigNumMont *mont, BigNum *out, const BigNum *value, const BigNum *exponent);
void revenant_bn_mont_pow_small(const BigNumMont *mont, BigNum *out, const BigNum *value, uint32_t exponent);
void revenant_bn_mont_add(const BigNumMont *mont, BigNum *out, const BigNum *left, const BigNum *right);
void revenant_bn_mont_sub(const BigNumMont *mont, BigNum *out, const BigNum *left, const BigNum *right);
void revenant_bn_mont_square(const BigNumMont *mont, BigNum *out, const BigNum *left);

#endif
