#include <stdint.h>

void xor16_alias(uint8_t *d, const uint8_t *s, const uint8_t *k)
{
    for (int i = 0; i < 16; i++)
        d[i] = s[i] ^ k[i];
}

void xor16_restrict(uint8_t *restrict d, const uint8_t *restrict s, const uint8_t *restrict k)
{
    for (int i = 0; i < 16; i++)
        d[i] = s[i] ^ k[i];
}

void mul_add_words_carry64(uint32_t *r, const uint32_t *a, uint32_t n, uint32_t w)
{
    uint64_t c = 0;
    for (uint32_t i = 0; i < n; i++) {
        uint64_t t = (uint64_t)a[i] * w + r[i] + c;
        r[i] = (uint32_t)t;
        c = t >> 32;
    }
}

void mul_add_words_carry32(uint32_t *r, const uint32_t *a, uint32_t n, uint32_t w)
{
    uint32_t c = 0;
    for (uint32_t i = 0; i < n; i++) {
        uint64_t t = (uint64_t)a[i] * w + r[i] + c;
        r[i] = (uint32_t)t;
        c = (uint32_t)(t >> 32);
    }
}
