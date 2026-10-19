#include "CharonHAPBignum.h"

void charon_bn_from_bytes(BigNum *out, const uint8_t *bytes, size_t length)
{
    charon_bn_zero(out);
    for (size_t index = 0; index < length; ++index) {
        size_t limb = index / 4;
        if (limb >= BN_LIMBS)
            break;
        out->limb[limb] |= (uint32_t)bytes[index] << (8 * (index % 4));
    }
}

void charon_bn_from_bytes_be(BigNum *out, const uint8_t *bytes, size_t length)
{
    charon_bn_zero(out);
    for (size_t index = 0; index < length; ++index) {
        size_t position = length - 1 - index;
        size_t limb = position / 4;
        if (limb >= BN_LIMBS)
            break;
        out->limb[limb] |= (uint32_t)bytes[index] << (8 * (position % 4));
    }
}

void charon_bn_to_bytes_be(uint8_t *bytes, size_t length, const BigNum *value)
{
    // The value's own bytes, minimal length, at the front; the rest of the buffer zeroed.
    memset(bytes, 0, length);
    size_t needed = charon_bn_byte_length(value);
    if (!needed || needed > length)
        needed = needed ? length : 0;
    for (size_t index = 0; index < needed; ++index) {
        size_t position = needed - 1 - index;
        bytes[index] = (uint8_t)(value->limb[position / 4] >> (8 * (position % 4)));
    }
}

void charon_bn_to_bytes(uint8_t *bytes, size_t length, const BigNum *value)
{
    for (size_t index = 0; index < length; ++index) {
        size_t limb = index / 4;
        bytes[index] = limb < BN_LIMBS ? (uint8_t)(value->limb[limb] >> (8 * (index % 4))) : 0;
    }
}

size_t charon_bn_byte_length(const BigNum *value)
{
    return (size_t)((charon_bn_bits(value) + 7) / 8);
}

int charon_bn_equal_bytes(const BigNum *left, const uint8_t *right, size_t length)
{
    // A length that does not fit the width cannot be equal: the value has no such limb, and reading
    // past it would be the bug this check exists to catch.
    if (length > (size_t)BN_LIMBS * 4)
        return 0;
    uint8_t mine[BN_LIMBS * 4];
    charon_bn_to_bytes(mine, sizeof(mine), left);
    uint8_t difference = 0;
    for (size_t index = 0; index < sizeof(mine); ++index) {
        uint8_t theirs = index < length ? right[index] : 0;
        difference |= mine[index] ^ theirs;
    }
    return difference == 0;
}

uint32_t charon_bn_add(BigNum *out, const BigNum *left, const BigNum *right)
{
    uint64_t carry = 0;
    for (int index = 0; index < BN_LIMBS; ++index) {
        uint64_t sum = (uint64_t)left->limb[index] + right->limb[index] + carry;
        out->limb[index] = (uint32_t)sum;
        carry = sum >> 32;
    }
    return (uint32_t)carry;
}

void charon_bn_sub(BigNum *out, const BigNum *left, const BigNum *right)
{
    uint64_t borrow = 0;
    for (int index = 0; index < BN_LIMBS; ++index) {
        uint64_t difference = (uint64_t)left->limb[index] - right->limb[index] - borrow;
        out->limb[index] = (uint32_t)difference;
        borrow = (difference >> 32) & 1;
    }
}

// t = a * b, then t = (t + m*n) / R for one m per limb, which leaves t * R^-1 mod n in t[limbs..].
// The two steps are kept apart on purpose: each is a loop whose carry is visible, where the fused
// version hides the shift in the indexing.
#define BN_T_LIMBS (2 * BN_LIMBS + 2)

static void mont_product(const BigNumMont *mont, uint32_t *t, const BigNum *left, const BigNum *right)
{
    int limbs = mont->limbs;
    for (int index = 0; index < BN_T_LIMBS; ++index)
        t[index] = 0;
    for (int i = 0; i < limbs; ++i) {
        uint64_t carry = 0;
        uint32_t multiplier = right->limb[i];
        if (!multiplier)
            continue;
        for (int j = 0; j < limbs; ++j) {
            uint64_t product = (uint64_t)left->limb[j] * multiplier + t[i + j] + carry;
            t[i + j] = (uint32_t)product;
            carry = product >> 32;
        }
        uint64_t sum = (uint64_t)t[i + limbs] + carry;
        t[i + limbs] = (uint32_t)sum;
        t[i + limbs + 1] += (uint32_t)(sum >> 32);
    }
}

static void mont_reduce(const BigNumMont *mont, uint32_t *t)
{
    int limbs = mont->limbs;
    for (int i = 0; i < limbs; ++i) {
        uint32_t factor = t[i] * mont->inverse;
        uint64_t carry = 0;
        for (int j = 0; j < limbs; ++j) {
            uint64_t product = (uint64_t)mont->modulus.limb[j] * factor + t[i + j] + carry;
            t[i + j] = (uint32_t)product;
            carry = product >> 32;
        }
        for (int k = i + limbs; carry && k < BN_T_LIMBS; ++k) {
            uint64_t product = (uint64_t)t[k] + carry;
            t[k] = (uint32_t)product;
            carry = product >> 32;
        }
    }
}

static void mont_finish(const BigNumMont *mont, BigNum *out, const uint32_t *t)
{
    int limbs = mont->limbs;
    // The reduced value is below 2n, and a modulus that fills its own width -- which RFC 5054's
    // 1024-bit group does, and every group a protocol names -- has 2n above R = 2^(32*limbs). So the
    // value needs limbs + 1 limbs, and the carry limb is part of it rather than a flag beside it.
    //
    // Reading only the low `limbs` limbs and then subtracting the modulus *because* the carry limb was
    // set is the defect RFC 5054's own test vector found: for a value below the modulus whose reduced
    // form still carried a bit past R, the subtraction underflowed and produced a number that is
    // wrong without being obviously so. The carry limb goes in the value, and the single conditional
    // subtraction is the one the bound justifies.
    for (int index = 0; index < BN_LIMBS; ++index)
        out->limb[index] = index <= limbs ? t[limbs + index] : 0;
    if (charon_bn_cmp(out, &mont->modulus) >= 0)
        charon_bn_sub(out, out, &mont->modulus);
}

void charon_bn_mont_prepare(BigNumMont *mont, const BigNum *modulus)
{
    memset(mont, 0, sizeof(*mont));
    mont->modulus = *modulus;
    mont->limbs = (charon_bn_bits(modulus) + 31) / 32;
    if (mont->limbs < 1)
        mont->limbs = 1;
    // n' = -n^-1 mod 2^32, by the Newton iteration on the low limb, which is all the Montgomery
    // product ever multiplies by.
    uint32_t inverse = modulus->limb[0];
    for (int round = 0; round < 5; ++round)
        inverse *= 2u - modulus->limb[0] * inverse;
    mont->inverse = (uint32_t)(0u - inverse);
    // R^2 mod n, where R = 2^(32*limbs) is the Montgomery radix of *this* modulus and not of the
    // full width: mont_finish shifts by `limbs` limbs, so R^2 is 2^(64*limbs) and the doubling has
    // to run that far.
    //
    // The doubling is written as one of two operations that both stay below n, because for a
    // modulus that fills the width -- 3072 bits out of 3072, which is the SRP-6a group HAP pairs
    // with -- 2*value does not fit, and reducing a wrapped double by subtracting n would go
    // negative. Below n/2 the double is safe; above it the difference n - value is what is safe.
    BigNum value;
    charon_bn_set_u32(&value, 1);
    for (int bit = 0; bit < 64 * mont->limbs; ++bit) {
        BigNum next;
        BigNum complement;
        charon_bn_sub(&complement, &mont->modulus, &value);
        if (charon_bn_cmp(&value, &complement) >= 0) {
            charon_bn_sub(&next, &value, &complement);
        } else {
            charon_bn_add(&next, &value, &value);
        }
        value = next;
    }
    mont->r2 = value;
}

void charon_bn_mont_mul(const BigNumMont *mont, BigNum *out, const BigNum *left, const BigNum *right)
{
    uint32_t t[BN_T_LIMBS];
    mont_product(mont, t, left, right);
    mont_reduce(mont, t);
    mont_finish(mont, out, t);
}

void charon_bn_mont_square(const BigNumMont *mont, BigNum *out, const BigNum *left)
{
    charon_bn_mont_mul(mont, out, left, left);
}

void charon_bn_mont_reduce(const BigNumMont *mont, BigNum *out, const BigNum *value)
{
    // value * R^-1 mod n, by the Montgomery product of value with 1.
    BigNum one;
    charon_bn_set_u32(&one, 1);
    charon_bn_mont_mul(mont, out, value, &one);
}

void charon_bn_mont_add(const BigNumMont *mont, BigNum *out, const BigNum *left, const BigNum *right)
{
    uint32_t carry = charon_bn_add(out, left, right);
    if (carry || charon_bn_cmp(out, &mont->modulus) >= 0)
        charon_bn_sub(out, out, &mont->modulus);
}

void charon_bn_mont_sub(const BigNumMont *mont, BigNum *out, const BigNum *left, const BigNum *right)
{
    if (charon_bn_cmp(left, right) >= 0) {
        charon_bn_sub(out, left, right);
    } else {
        BigNum shifted;
        charon_bn_add(&shifted, left, &mont->modulus);
        charon_bn_sub(out, &shifted, right);
    }
}

void charon_bn_mont_pow(const BigNumMont *mont, BigNum *out, const BigNum *value, const BigNum *exponent)
{
    // Square and multiply, most significant bit first, entirely in Montgomery form. The trip count
    // is the width rather than the exponent's own, so the time this takes does not depend on the
    // value of a secret exponent.
    BigNum base, one, accumulator, product;
    charon_bn_mont_mul(mont, &base, value, &mont->r2);
    charon_bn_set_u32(&one, 1);
    charon_bn_mont_mul(mont, &accumulator, &one, &mont->r2);
    for (int bit = BN_BITS - 1; bit >= 0; --bit) {
        int index = bit / 32;
        charon_bn_mont_square(mont, &product, &accumulator);
        accumulator = product;
        if ((exponent->limb[index] >> (bit % 32)) & 1) {
            charon_bn_mont_mul(mont, &product, &accumulator, &base);
            accumulator = product;
        }
    }
    charon_bn_mont_reduce(mont, out, &accumulator);
}

void charon_bn_mont_pow_small(const BigNumMont *mont, BigNum *out, const BigNum *value, uint32_t exponent)
{
    BigNum power;
    charon_bn_set_u32(&power, exponent);
    charon_bn_mont_pow(mont, out, value, &power);
}
