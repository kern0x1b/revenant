#include <stdint.h>

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

static void slice(const uint8_t *bytes, uint16_t *planes) {
    for (unsigned bit = 0; bit < 8; bit++) {
        uint16_t plane = 0;
        for (unsigned i = 0; i < 16; i++) {
            plane |= (uint16_t)(((bytes[i] >> bit) & 1u) << i);
        }
        planes[bit] = plane;
    }
}

static void unslice(const uint16_t *planes, uint8_t *bytes) {
    for (unsigned i = 0; i < 16; i++) {
        unsigned byte = 0;
        for (unsigned bit = 0; bit < 8; bit++) {
            byte |= ((planes[bit] >> i) & 1u) << bit;
        }
        bytes[i] = (uint8_t)byte;
    }
}

static void reduce(uint16_t *product) {
    for (unsigned degree = 14; degree >= 8; degree--) {
        product[degree - 4] ^= product[degree];
        product[degree - 5] ^= product[degree];
        product[degree - 7] ^= product[degree];
        product[degree - 8] ^= product[degree];
    }
}

static void multiply(const uint16_t *a, const uint16_t *b, uint16_t *result) {
    uint16_t product[15] = {0};
    for (unsigned i = 0; i < 8; i++) {
        for (unsigned j = 0; j < 8; j++) {
            product[i + j] ^= a[i] & b[j];
        }
    }
    reduce(product);
    for (unsigned i = 0; i < 8; i++) {
        result[i] = product[i];
    }
}

static void square(const uint16_t *a, uint16_t *result) {
    uint16_t product[15] = {0};
    for (unsigned i = 0; i < 8; i++) {
        product[2 * i] = a[i];
    }
    reduce(product);
    for (unsigned i = 0; i < 8; i++) {
        result[i] = product[i];
    }
}

static void invert(uint16_t *x) {
    uint16_t x2[8], x3[8], x12[8], x15[8], x240[8], x252[8];
    square(x, x2);
    multiply(x2, x, x3);
    square(x3, x12);
    square(x12, x12);
    multiply(x12, x3, x15);
    square(x15, x240);
    square(x240, x240);
    square(x240, x240);
    square(x240, x240);
    multiply(x240, x12, x252);
    multiply(x252, x2, x);
}

static void affine(uint16_t *x) {
    uint16_t y[8];
    for (unsigned i = 0; i < 8; i++) {
        y[i] = x[i] ^ x[(i + 4) & 7] ^ x[(i + 5) & 7] ^ x[(i + 6) & 7] ^ x[(i + 7) & 7] ^ (uint16_t)-((0x63u >> i) & 1u);
    }
    for (unsigned i = 0; i < 8; i++) {
        x[i] = y[i];
    }
}

static void inverse_affine(uint16_t *x) {
    uint16_t y[8];
    for (unsigned i = 0; i < 8; i++) {
        y[i] = x[(i + 2) & 7] ^ x[(i + 5) & 7] ^ x[(i + 7) & 7] ^ (uint16_t)-((0x05u >> i) & 1u);
    }
    for (unsigned i = 0; i < 8; i++) {
        x[i] = y[i];
    }
}

static void substitute(uint8_t *bytes, unsigned inverse) {
    uint16_t planes[8];
    slice(bytes, planes);
    if (inverse) {
        inverse_affine(planes);
        invert(planes);
    } else {
        invert(planes);
        affine(planes);
    }
    unslice(planes, bytes);
}

static void cipher_round(void *vd, const void *vn, unsigned inverse, const uint8_t *permutation) {
    uint8_t *d = vd;
    const uint8_t *n = vn;
    uint8_t state[16];
    for (unsigned i = 0; i < 16; i++) {
        state[i] = d[i] ^ n[i];
    }
    substitute(state, inverse);
    for (unsigned i = 0; i < 16; i++) {
        d[i] = state[permutation[i]];
    }
}

static uint32_t double_bytes(uint32_t word) {
    return ((word & 0x7f7f7f7fu) << 1) ^ (((word >> 7) & 0x01010101u) * 0x1bu);
}

void rellume_aarch64_aese(void *vd, const void *vn) {
    cipher_round(vd, vn, 0, shift_rows);
}

void rellume_aarch64_aesd(void *vd, const void *vn) {
    cipher_round(vd, vn, 1, inverse_shift_rows);
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
