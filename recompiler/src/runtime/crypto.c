#include <arm_neon.h>
#include <stdint.h>

static const uint8_t sbox[256] = {
    0x63, 0x7c, 0x77, 0x7b, 0xf2, 0x6b, 0x6f, 0xc5, 0x30, 0x01, 0x67, 0x2b, 0xfe, 0xd7, 0xab, 0x76,
    0xca, 0x82, 0xc9, 0x7d, 0xfa, 0x59, 0x47, 0xf0, 0xad, 0xd4, 0xa2, 0xaf, 0x9c, 0xa4, 0x72, 0xc0,
    0xb7, 0xfd, 0x93, 0x26, 0x36, 0x3f, 0xf7, 0xcc, 0x34, 0xa5, 0xe5, 0xf1, 0x71, 0xd8, 0x31, 0x15,
    0x04, 0xc7, 0x23, 0xc3, 0x18, 0x96, 0x05, 0x9a, 0x07, 0x12, 0x80, 0xe2, 0xeb, 0x27, 0xb2, 0x75,
    0x09, 0x83, 0x2c, 0x1a, 0x1b, 0x6e, 0x5a, 0xa0, 0x52, 0x3b, 0xd6, 0xb3, 0x29, 0xe3, 0x2f, 0x84,
    0x53, 0xd1, 0x00, 0xed, 0x20, 0xfc, 0xb1, 0x5b, 0x6a, 0xcb, 0xbe, 0x39, 0x4a, 0x4c, 0x58, 0xcf,
    0xd0, 0xef, 0xaa, 0xfb, 0x43, 0x4d, 0x33, 0x85, 0x45, 0xf9, 0x02, 0x7f, 0x50, 0x3c, 0x9f, 0xa8,
    0x51, 0xa3, 0x40, 0x8f, 0x92, 0x9d, 0x38, 0xf5, 0xbc, 0xb6, 0xda, 0x21, 0x10, 0xff, 0xf3, 0xd2,
    0xcd, 0x0c, 0x13, 0xec, 0x5f, 0x97, 0x44, 0x17, 0xc4, 0xa7, 0x7e, 0x3d, 0x64, 0x5d, 0x19, 0x73,
    0x60, 0x81, 0x4f, 0xdc, 0x22, 0x2a, 0x90, 0x88, 0x46, 0xee, 0xb8, 0x14, 0xde, 0x5e, 0x0b, 0xdb,
    0xe0, 0x32, 0x3a, 0x0a, 0x49, 0x06, 0x24, 0x5c, 0xc2, 0xd3, 0xac, 0x62, 0x91, 0x95, 0xe4, 0x79,
    0xe7, 0xc8, 0x37, 0x6d, 0x8d, 0xd5, 0x4e, 0xa9, 0x6c, 0x56, 0xf4, 0xea, 0x65, 0x7a, 0xae, 0x08,
    0xba, 0x78, 0x25, 0x2e, 0x1c, 0xa6, 0xb4, 0xc6, 0xe8, 0xdd, 0x74, 0x1f, 0x4b, 0xbd, 0x8b, 0x8a,
    0x70, 0x3e, 0xb5, 0x66, 0x48, 0x03, 0xf6, 0x0e, 0x61, 0x35, 0x57, 0xb9, 0x86, 0xc1, 0x1d, 0x9e,
    0xe1, 0xf8, 0x98, 0x11, 0x69, 0xd9, 0x8e, 0x94, 0x9b, 0x1e, 0x87, 0xe9, 0xce, 0x55, 0x28, 0xdf,
    0x8c, 0xa1, 0x89, 0x0d, 0xbf, 0xe6, 0x42, 0x68, 0x41, 0x99, 0x2d, 0x0f, 0xb0, 0x54, 0xbb, 0x16
};

static const uint8_t inverse_sbox[256] = {
    0x52, 0x09, 0x6a, 0xd5, 0x30, 0x36, 0xa5, 0x38, 0xbf, 0x40, 0xa3, 0x9e, 0x81, 0xf3, 0xd7, 0xfb,
    0x7c, 0xe3, 0x39, 0x82, 0x9b, 0x2f, 0xff, 0x87, 0x34, 0x8e, 0x43, 0x44, 0xc4, 0xde, 0xe9, 0xcb,
    0x54, 0x7b, 0x94, 0x32, 0xa6, 0xc2, 0x23, 0x3d, 0xee, 0x4c, 0x95, 0x0b, 0x42, 0xfa, 0xc3, 0x4e,
    0x08, 0x2e, 0xa1, 0x66, 0x28, 0xd9, 0x24, 0xb2, 0x76, 0x5b, 0xa2, 0x49, 0x6d, 0x8b, 0xd1, 0x25,
    0x72, 0xf8, 0xf6, 0x64, 0x86, 0x68, 0x98, 0x16, 0xd4, 0xa4, 0x5c, 0xcc, 0x5d, 0x65, 0xb6, 0x92,
    0x6c, 0x70, 0x48, 0x50, 0xfd, 0xed, 0xb9, 0xda, 0x5e, 0x15, 0x46, 0x57, 0xa7, 0x8d, 0x9d, 0x84,
    0x90, 0xd8, 0xab, 0x00, 0x8c, 0xbc, 0xd3, 0x0a, 0xf7, 0xe4, 0x58, 0x05, 0xb8, 0xb3, 0x45, 0x06,
    0xd0, 0x2c, 0x1e, 0x8f, 0xca, 0x3f, 0x0f, 0x02, 0xc1, 0xaf, 0xbd, 0x03, 0x01, 0x13, 0x8a, 0x6b,
    0x3a, 0x91, 0x11, 0x41, 0x4f, 0x67, 0xdc, 0xea, 0x97, 0xf2, 0xcf, 0xce, 0xf0, 0xb4, 0xe6, 0x73,
    0x96, 0xac, 0x74, 0x22, 0xe7, 0xad, 0x35, 0x85, 0xe2, 0xf9, 0x37, 0xe8, 0x1c, 0x75, 0xdf, 0x6e,
    0x47, 0xf1, 0x1a, 0x71, 0x1d, 0x29, 0xc5, 0x89, 0x6f, 0xb7, 0x62, 0x0e, 0xaa, 0x18, 0xbe, 0x1b,
    0xfc, 0x56, 0x3e, 0x4b, 0xc6, 0xd2, 0x79, 0x20, 0x9a, 0xdb, 0xc0, 0xfe, 0x78, 0xcd, 0x5a, 0xf4,
    0x1f, 0xdd, 0xa8, 0x33, 0x88, 0x07, 0xc7, 0x31, 0xb1, 0x12, 0x10, 0x59, 0x27, 0x80, 0xec, 0x5f,
    0x60, 0x51, 0x7f, 0xa9, 0x19, 0xb5, 0x4a, 0x0d, 0x2d, 0xe5, 0x7a, 0x9f, 0x93, 0xc9, 0x9c, 0xef,
    0xa0, 0xe0, 0x3b, 0x4d, 0xae, 0x2a, 0xf5, 0xb0, 0xc8, 0xeb, 0xbb, 0x3c, 0x83, 0x53, 0x99, 0x61,
    0x17, 0x2b, 0x04, 0x7e, 0xba, 0x77, 0xd6, 0x26, 0xe1, 0x69, 0x14, 0x63, 0x55, 0x21, 0x0c, 0x7d
};

static const uint8_t shift_rows[16] = {0, 5, 10, 15, 4, 9, 14, 3, 8, 13, 2, 7, 12, 1, 6, 11};
static const uint8_t inverse_shift_rows[16] = {0, 13, 10, 7, 4, 1, 14, 11, 8, 5, 2, 15, 12, 9, 6, 3};

static uint32_t rotate_left(uint32_t value, unsigned amount) {
    return (value << amount) | (value >> (32 - amount));
}

static uint32_t rotate_right(uint32_t value, unsigned amount) {
    return (value >> amount) | (value << (32 - amount));
}

static uint32_t choose(uint32_t x, uint32_t y, uint32_t z) {
    return ((y ^ z) & x) ^ z;
}

static uint32_t parity(uint32_t x, uint32_t y, uint32_t z) {
    return x ^ y ^ z;
}

static uint32_t majority(uint32_t x, uint32_t y, uint32_t z) {
    return (x & y) | ((x | y) & z);
}

static uint8x8_t substitute(const uint8_t *table, uint8x8_t index) {
    uint8x8_t result = vdup_n_u8(0);
    for (unsigned chunk = 0; chunk < 8; chunk++) {
        const uint8_t *entries = table + 32 * chunk;
        uint8x8x4_t window = {{vld1_u8(entries), vld1_u8(entries + 8), vld1_u8(entries + 16), vld1_u8(entries + 24)}};
        result = vorr_u8(result, vtbl4_u8(window, vsub_u8(index, vdup_n_u8((uint8_t)(32 * chunk)))));
    }
    return result;
}

static void cipher_round(void *vd, const void *vn, const uint8_t *table, const uint8_t *permutation) {
    uint8x16_t state = veorq_u8(vld1q_u8(vd), vld1q_u8(vn));
    uint8x8x2_t halves = {{vget_low_u8(state), vget_high_u8(state)}};
    uint8x8_t low = vtbl2_u8(halves, vld1_u8(permutation));
    uint8x8_t high = vtbl2_u8(halves, vld1_u8(permutation + 8));
    vst1q_u8(vd, vcombine_u8(substitute(table, low), substitute(table, high)));
}

static uint32_t double_bytes(uint32_t word) {
    return ((word & 0x7f7f7f7fu) << 1) ^ (((word >> 7) & 0x01010101u) * 0x1bu);
}

void rellume_aarch64_aese(void *vd, const void *vn) {
    cipher_round(vd, vn, sbox, shift_rows);
}

void rellume_aarch64_aesd(void *vd, const void *vn) {
    cipher_round(vd, vn, inverse_sbox, inverse_shift_rows);
}

void rellume_aarch64_aesmc(void *vd, const void *vn) {
    uint32_t *d = vd;
    const uint32_t *n = vn;
    for (unsigned i = 0; i < 4; i++) {
        uint32_t word = n[i];
        uint32_t x2 = double_bytes(word);
        d[i] = x2 ^ rotate_right(x2 ^ word, 8) ^ rotate_right(word, 16) ^ rotate_right(word, 24);
    }
}

void rellume_aarch64_aesimc(void *vd, const void *vn) {
    uint32_t *d = vd;
    const uint32_t *n = vn;
    for (unsigned i = 0; i < 4; i++) {
        uint32_t word = n[i];
        uint32_t x2 = double_bytes(word);
        uint32_t x4 = double_bytes(x2);
        uint32_t x8 = double_bytes(x4);
        d[i] = (x8 ^ x4 ^ x2) ^ rotate_right(x8 ^ x2 ^ word, 8) ^ rotate_right(x8 ^ x4 ^ word, 16) ^ rotate_right(x8 ^ word, 24);
    }
}

static void sha1_rounds(uint32_t *x, uint32_t e, const uint32_t *w, uint32_t (*function)(uint32_t, uint32_t, uint32_t)) {
    for (unsigned i = 0; i < 4; i++) {
        e += rotate_left(x[0], 5) + function(x[1], x[2], x[3]) + w[i];
        uint32_t next = x[3];
        x[3] = x[2];
        x[2] = rotate_left(x[1], 30);
        x[1] = x[0];
        x[0] = e;
        e = next;
    }
}

void rellume_aarch64_sha1c(void *vd, uint32_t sn, const void *vm) {
    sha1_rounds(vd, sn, vm, choose);
}

void rellume_aarch64_sha1p(void *vd, uint32_t sn, const void *vm) {
    sha1_rounds(vd, sn, vm, parity);
}

void rellume_aarch64_sha1m(void *vd, uint32_t sn, const void *vm) {
    sha1_rounds(vd, sn, vm, majority);
}

void rellume_aarch64_sha1su0(void *vd, const void *vn, const void *vm) {
    uint32_t *d = vd;
    const uint32_t *n = vn;
    const uint32_t *m = vm;
    uint32_t r0 = d[0] ^ d[2] ^ m[0];
    uint32_t r1 = d[1] ^ d[3] ^ m[1];
    uint32_t r2 = d[2] ^ n[0] ^ m[2];
    uint32_t r3 = d[3] ^ n[1] ^ m[3];
    d[0] = r0;
    d[1] = r1;
    d[2] = r2;
    d[3] = r3;
}

void rellume_aarch64_sha1su1(void *vd, const void *vn) {
    uint32_t *d = vd;
    const uint32_t *n = vn;
    uint32_t t0 = d[0] ^ n[1];
    uint32_t t1 = d[1] ^ n[2];
    uint32_t t2 = d[2] ^ n[3];
    uint32_t t3 = d[3];
    d[0] = rotate_left(t0, 1);
    d[1] = rotate_left(t1, 1);
    d[2] = rotate_left(t2, 1);
    d[3] = rotate_left(t3, 1) ^ rotate_left(t0, 2);
}

static uint32_t big_sigma0(uint32_t x) {
    return rotate_right(x, 2) ^ rotate_right(x, 13) ^ rotate_right(x, 22);
}

static uint32_t big_sigma1(uint32_t x) {
    return rotate_right(x, 6) ^ rotate_right(x, 11) ^ rotate_right(x, 25);
}

static uint32_t small_sigma0(uint32_t x) {
    return rotate_right(x, 7) ^ rotate_right(x, 18) ^ (x >> 3);
}

static uint32_t small_sigma1(uint32_t x) {
    return rotate_right(x, 17) ^ rotate_right(x, 19) ^ (x >> 10);
}

static void sha256_rounds(uint32_t *x, uint32_t *y, const uint32_t *w) {
    for (unsigned i = 0; i < 4; i++) {
        uint32_t t = y[3] + big_sigma1(y[0]) + choose(y[0], y[1], y[2]) + w[i];
        uint32_t e = x[3] + t;
        uint32_t a = t + big_sigma0(x[0]) + majority(x[0], x[1], x[2]);
        x[3] = x[2];
        x[2] = x[1];
        x[1] = x[0];
        x[0] = a;
        y[3] = y[2];
        y[2] = y[1];
        y[1] = y[0];
        y[0] = e;
    }
}

void rellume_aarch64_sha256h(void *vd, const void *vn, const void *vm) {
    uint32_t *d = vd;
    const uint32_t *n = vn;
    uint32_t x[4] = {d[0], d[1], d[2], d[3]};
    uint32_t y[4] = {n[0], n[1], n[2], n[3]};
    sha256_rounds(x, y, vm);
    d[0] = x[0];
    d[1] = x[1];
    d[2] = x[2];
    d[3] = x[3];
}

void rellume_aarch64_sha256h2(void *vd, const void *vn, const void *vm) {
    uint32_t *d = vd;
    const uint32_t *n = vn;
    uint32_t x[4] = {n[0], n[1], n[2], n[3]};
    uint32_t y[4] = {d[0], d[1], d[2], d[3]};
    sha256_rounds(x, y, vm);
    d[0] = y[0];
    d[1] = y[1];
    d[2] = y[2];
    d[3] = y[3];
}

void rellume_aarch64_sha256su0(void *vd, const void *vn) {
    uint32_t *d = vd;
    const uint32_t *n = vn;
    uint32_t r0 = small_sigma0(d[1]) + d[0];
    uint32_t r1 = small_sigma0(d[2]) + d[1];
    uint32_t r2 = small_sigma0(d[3]) + d[2];
    uint32_t r3 = small_sigma0(n[0]) + d[3];
    d[0] = r0;
    d[1] = r1;
    d[2] = r2;
    d[3] = r3;
}

void rellume_aarch64_sha256su1(void *vd, const void *vn, const void *vm) {
    uint32_t *d = vd;
    const uint32_t *n = vn;
    const uint32_t *m = vm;
    uint32_t r0 = small_sigma1(m[2]) + d[0] + n[1];
    uint32_t r1 = small_sigma1(m[3]) + d[1] + n[2];
    uint32_t r2 = small_sigma1(r0) + d[2] + n[3];
    uint32_t r3 = small_sigma1(r1) + d[3] + m[0];
    d[0] = r0;
    d[1] = r1;
    d[2] = r2;
    d[3] = r3;
}

void rellume_aarch64_pmull8(void *vd, uint64_t n, uint64_t m) {
    uint16_t *d = vd;
    for (unsigned i = 0; i < 8; i++) {
        uint16_t a = (uint8_t)(n >> (8 * i));
        uint8_t b = (uint8_t)(m >> (8 * i));
        uint16_t product = 0;
        for (unsigned bit = 0; bit < 8; bit++) {
            product ^= (uint16_t)(a << bit) & (uint16_t)-((b >> bit) & 1);
        }
        d[i] = product;
    }
}

void rellume_aarch64_pmull64(void *vd, uint64_t n, uint64_t m) {
    uint64_t *d = vd;
    uint64_t low = 0;
    uint64_t high = 0;
    for (unsigned bit = 0; bit < 64; bit++) {
        uint64_t mask = -((m >> bit) & 1);
        low ^= (n << bit) & mask;
        high ^= ((n >> 1) >> (63 - bit)) & mask;
    }
    d[0] = low;
    d[1] = high;
}
