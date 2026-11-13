#include <arm_neon.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <sys/time.h>

enum { TIMED = 20000 };

static void expect_hex(const char *name, const uint8_t *bytes, size_t size, const char *want) {
    char got[129];
    for (size_t i = 0; i < size; i++) {
        sprintf(got + 2 * i, "%02x", bytes[i]);
    }
    int ok = strcmp(got, want) == 0;
    printf("%s %s\n", ok ? "ok" : "FAIL", name);
    if (!ok) {
        printf("  want %s\n  got  %s\n", want, got);
    }
    fflush(stdout);
}

static void vector_aese(uint8_t *d, const uint8_t *n) { vst1q_u8(d, vaeseq_u8(vld1q_u8(d), vld1q_u8(n))); }
static void vector_aesd(uint8_t *d, const uint8_t *n) { vst1q_u8(d, vaesdq_u8(vld1q_u8(d), vld1q_u8(n))); }
static void vector_aesmc(uint8_t *d, const uint8_t *n) { vst1q_u8(d, vaesmcq_u8(vld1q_u8(n))); }
static void vector_aesimc(uint8_t *d, const uint8_t *n) { vst1q_u8(d, vaesimcq_u8(vld1q_u8(n))); }
static void vector_sha1c(uint32_t *d, uint32_t e, const uint32_t *w) { vst1q_u32(d, vsha1cq_u32(vld1q_u32(d), e, vld1q_u32(w))); }
static void vector_sha1p(uint32_t *d, uint32_t e, const uint32_t *w) { vst1q_u32(d, vsha1pq_u32(vld1q_u32(d), e, vld1q_u32(w))); }
static void vector_sha1m(uint32_t *d, uint32_t e, const uint32_t *w) { vst1q_u32(d, vsha1mq_u32(vld1q_u32(d), e, vld1q_u32(w))); }
static void vector_sha1su0(uint32_t *d, const uint32_t *n, const uint32_t *m) { vst1q_u32(d, vsha1su0q_u32(vld1q_u32(d), vld1q_u32(n), vld1q_u32(m))); }
static void vector_sha1su1(uint32_t *d, const uint32_t *n) { vst1q_u32(d, vsha1su1q_u32(vld1q_u32(d), vld1q_u32(n))); }
static void vector_sha256h(uint32_t *d, const uint32_t *n, const uint32_t *m) { vst1q_u32(d, vsha256hq_u32(vld1q_u32(d), vld1q_u32(n), vld1q_u32(m))); }
static void vector_sha256h2(uint32_t *d, const uint32_t *n, const uint32_t *m) { vst1q_u32(d, vsha256h2q_u32(vld1q_u32(d), vld1q_u32(n), vld1q_u32(m))); }
static void vector_sha256su0(uint32_t *d, const uint32_t *n) { vst1q_u32(d, vsha256su0q_u32(vld1q_u32(d), vld1q_u32(n))); }
static void vector_sha256su1(uint32_t *d, const uint32_t *n, const uint32_t *m) { vst1q_u32(d, vsha256su1q_u32(vld1q_u32(d), vld1q_u32(n), vld1q_u32(m))); }

#include "../crypto/vectors.h"

static double now_ns(void) {
    struct timeval tv;
    gettimeofday(&tv, 0);
    return (double)tv.tv_sec * 1e9 + (double)tv.tv_usec * 1e3;
}

static void test_pmull(void) {
    uint8_t a[8] = {0x03, 0xff, 0x80, 0x01, 0x00, 0x55, 0xaa, 0x0f};
    uint8_t b[8] = {0x03, 0xff, 0x80, 0xff, 0x77, 0x03, 0x03, 0x0f};
    uint8_t out[16];
    vst1q_u8(out, vreinterpretq_u8_p16(vmull_p8(vld1_p8(a), vld1_p8(b))));
    expect_hex("pmull.8h", out, 16, "050055550040ff000000ff00fe015500");
    vst1q_u8(out, vreinterpretq_u8_p128(vmull_p64(3, 3)));
    expect_hex("pmull.1q 3 x 3", out, 16, "05000000000000000000000000000000");
    vst1q_u8(out, vreinterpretq_u8_p128(vmull_p64(0x8000000000000001ull, 0x8000000000000001ull)));
    expect_hex("pmull.1q (x^63+1)^2", out, 16, "01000000000000000000000000000040");
    uint64_t pair[2] = {3, 0x8000000000000001ull};
    uint64_t other[2] = {7, 0x8000000000000001ull};
    vst1q_u8(out, vreinterpretq_u8_p128(vmull_high_p64(vld1q_p64((const poly64_t *)pair), vld1q_p64((const poly64_t *)other))));
    expect_hex("pmull2.1q high halves", out, 16, "01000000000000000000000000000040");
}

static void time_aes(void) {
    uint8_t d[16] = {0}, k[16] = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16};
    uint8x16_t block = vld1q_u8(d), key = vld1q_u8(k);
    double start = now_ns();
    for (unsigned i = 0; i < TIMED; i++) {
        block = vaesmcq_u8(vaeseq_u8(block, key));
    }
    double encrypt = (now_ns() - start) / TIMED;
    start = now_ns();
    for (unsigned i = 0; i < TIMED; i++) {
        block = vaesimcq_u8(vaesdq_u8(block, key));
    }
    double decrypt = (now_ns() - start) / TIMED;
    vst1q_u8(d, block);
    printf("time aese+aesmc %.0f ns, aesd+aesimc %.0f ns (check %02x)\n", encrypt, decrypt, d[0]);
    fflush(stdout);
}

static void time_pmull(void) {
    uint64_t x = 0x0123456789abcdefull;
    uint8x16_t sink = vdupq_n_u8(0);
    double start = now_ns();
    for (unsigned i = 0; i < TIMED; i++) {
        sink = veorq_u8(sink, vreinterpretq_u8_p128(vmull_p64(x, x ^ i)));
    }
    double wide = (now_ns() - start) / TIMED;
    uint8x8_t narrow = vdup_n_u8(7);
    start = now_ns();
    for (unsigned i = 0; i < TIMED; i++) {
        sink = veorq_u8(sink, vreinterpretq_u8_p16(vmull_p8(vreinterpret_p8_u8(narrow), vreinterpret_p8_u8(vdup_n_u8((uint8_t)i)))));
    }
    double bytes = (now_ns() - start) / TIMED;
    printf("time pmull.1q %.0f ns, pmull.8h %.0f ns (check %02x)\n", wide, bytes, vgetq_lane_u8(sink, 0));
    fflush(stdout);
}

int main(void) {
    test_fips197();
    test_sha256_abc();
    test_sha1_abc();
    test_pmull();
    time_aes();
    time_pmull();
    printf("done\n");
    return 0;
}
