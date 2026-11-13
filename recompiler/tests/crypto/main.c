#include <arm_neon.h>
#include <stdint.h>

#define FUNCTION __attribute__((noinline, used))

FUNCTION uint8x16_t crypto_aese(uint8x16_t data, uint8x16_t key) { return vaeseq_u8(data, key); }
FUNCTION uint8x16_t crypto_aesd(uint8x16_t data, uint8x16_t key) { return vaesdq_u8(data, key); }
FUNCTION uint8x16_t crypto_aesmc(uint8x16_t data) { return vaesmcq_u8(data); }
FUNCTION uint8x16_t crypto_aesimc(uint8x16_t data) { return vaesimcq_u8(data); }

FUNCTION uint32x4_t crypto_sha1c(uint32x4_t abcd, uint32_t e, uint32x4_t wk) { return vsha1cq_u32(abcd, e, wk); }
FUNCTION uint32x4_t crypto_sha1p(uint32x4_t abcd, uint32_t e, uint32x4_t wk) { return vsha1pq_u32(abcd, e, wk); }
FUNCTION uint32x4_t crypto_sha1m(uint32x4_t abcd, uint32_t e, uint32x4_t wk) { return vsha1mq_u32(abcd, e, wk); }
FUNCTION uint32_t crypto_sha1h(uint32_t value) { return vsha1h_u32(value); }
FUNCTION uint32x4_t crypto_sha1su0(uint32x4_t w0, uint32x4_t w4, uint32x4_t w8) { return vsha1su0q_u32(w0, w4, w8); }
FUNCTION uint32x4_t crypto_sha1su1(uint32x4_t w0, uint32x4_t w12) { return vsha1su1q_u32(w0, w12); }

FUNCTION uint32x4_t crypto_sha256h(uint32x4_t abcd, uint32x4_t efgh, uint32x4_t wk) { return vsha256hq_u32(abcd, efgh, wk); }
FUNCTION uint32x4_t crypto_sha256h2(uint32x4_t efgh, uint32x4_t abcd, uint32x4_t wk) { return vsha256h2q_u32(efgh, abcd, wk); }
FUNCTION uint32x4_t crypto_sha256su0(uint32x4_t w0, uint32x4_t w4) { return vsha256su0q_u32(w0, w4); }
FUNCTION uint32x4_t crypto_sha256su1(uint32x4_t w0, uint32x4_t w8, uint32x4_t w12) { return vsha256su1q_u32(w0, w8, w12); }

FUNCTION poly16x8_t crypto_pmull_8b(poly8x8_t a, poly8x8_t b) { return vmull_p8(a, b); }
FUNCTION poly16x8_t crypto_pmull2_16b(poly8x16_t a, poly8x16_t b) { return vmull_high_p8(a, b); }
FUNCTION poly128_t crypto_pmull_1d(poly64_t a, poly64_t b) { return vmull_p64(a, b); }
FUNCTION poly128_t crypto_pmull2_2d(poly64x2_t a, poly64x2_t b) { return vmull_high_p64(a, b); }

FUNCTION uint8x16_t crypto_trn1_16b(uint8x16_t a, uint8x16_t b) { return vtrn1q_u8(a, b); }
FUNCTION uint8x16_t crypto_trn2_16b(uint8x16_t a, uint8x16_t b) { return vtrn2q_u8(a, b); }
FUNCTION uint16x8_t crypto_trn1_8h(uint16x8_t a, uint16x8_t b) { return vtrn1q_u16(a, b); }
FUNCTION uint16x8_t crypto_trn2_8h(uint16x8_t a, uint16x8_t b) { return vtrn2q_u16(a, b); }
FUNCTION uint32x4_t crypto_trn1_4s(uint32x4_t a, uint32x4_t b) { return vtrn1q_u32(a, b); }
FUNCTION uint32x4_t crypto_trn2_4s(uint32x4_t a, uint32x4_t b) { return vtrn2q_u32(a, b); }
FUNCTION uint64x2_t crypto_trn1_2d(uint64x2_t a, uint64x2_t b) {
    uint64x2_t result;
    __asm__("trn1 %0.2d, %1.2d, %2.2d" : "=w"(result) : "w"(a), "w"(b));
    return result;
}
FUNCTION uint64x2_t crypto_trn2_2d(uint64x2_t a, uint64x2_t b) {
    uint64x2_t result;
    __asm__("trn2 %0.2d, %1.2d, %2.2d" : "=w"(result) : "w"(a), "w"(b));
    return result;
}
FUNCTION uint8x8_t crypto_trn1_8b(uint8x8_t a, uint8x8_t b) { return vtrn1_u8(a, b); }
FUNCTION uint8x8_t crypto_trn2_8b(uint8x8_t a, uint8x8_t b) { return vtrn2_u8(a, b); }

FUNCTION uint8x16_t crypto_round(uint8x16_t data, uint8x16_t key) { return vaesmcq_u8(vaeseq_u8(data, key)); }
FUNCTION uint8x16_t crypto_rounds(uint8x16_t data, const uint8x16_t *keys, unsigned count) {
    for (unsigned i = 0; i < count; i++) {
        data = vaesmcq_u8(vaeseq_u8(data, keys[i]));
    }
    return data;
}

static uint8x16_t block;

int main(void) {
    uint8x16_t keys[2] = {block, block};
    block = crypto_rounds(crypto_aesd(crypto_aese(block, block), block), keys, 2);
    return (int)vgetq_lane_u8(block, 0);
}
