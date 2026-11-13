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

#include "../crypto/carry.h"
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

static void expect_number(const char *name, uint64_t got, uint64_t want) {
    int ok = got == want;
    printf("%s %s\n", ok ? "ok" : "FAIL", name);
    if (!ok) {
        printf("  want %016llx\n  got  %016llx\n", (unsigned long long)want, (unsigned long long)got);
    }
    fflush(stdout);
}

static const uint8_t first_operand[16] = {0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88, 0x99, 0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff};
static const uint8_t second_operand[16] = {0xf0, 0xe1, 0xd2, 0xc3, 0xb4, 0xa5, 0x96, 0x87, 0x78, 0x69, 0x5a, 0x4b, 0x3c, 0x2d, 0x1e, 0x0f};

static void test_shift_insert(void) {
    uint8x16_t a = vld1q_u8(first_operand), b = vld1q_u8(second_operand);
    uint8_t out[16];
    vst1q_u8(out, vsliq_n_u8(a, b, 3));
    expect_hex("sli.16b #3", out, 16, "8009921ba42db63fc049d25be46df67f");
    vst1q_u8(out, vreinterpretq_u8_u32(vsliq_n_u32(vreinterpretq_u32_u8(a), vreinterpretq_u32_u8(b), 12)));
    expect_hex("sli.4s #12", out, 16, "00011f2e44455b6a888997a6cccdd3e2");
    vst1q_u8(out, vreinterpretq_u8_u64(vsliq_n_u64(vreinterpretq_u64_u8(a), vreinterpretq_u64_u8(b), 40)));
    expect_hex("sli.2d #40", out, 16, "0011223344f0e1d28899aabbcc78695a");
    vst1q_u8(out, vcombine_u8(vreinterpret_u8_u64(vsli_n_u64(vget_low_u64(vreinterpretq_u64_u8(a)), vget_low_u64(vreinterpretq_u64_u8(b)), 17)), vdup_n_u8(0)));
    expect_hex("sli d #17", out, 16, "0011e0c3a587694b0000000000000000");
    vst1q_u8(out, vsriq_n_u8(a, b, 3));
    expect_hex("sri.16b #3", out, 16, "1e1c3a38565472708f8daba9c7c5e3e1");
    vst1q_u8(out, vreinterpretq_u8_u32(vsriq_n_u32(vreinterpretq_u32_u8(a), vreinterpretq_u32_u8(b), 12)));
    expect_hex("sri.4s #12", out, 16, "2e3d2c336a796877a6b5a4bbe2f1e0ff");
    vst1q_u8(out, vreinterpretq_u8_u32(vsriq_n_u32(vreinterpretq_u32_u8(a), vreinterpretq_u32_u8(b), 32)));
    expect_hex("sri.4s #32 keeps the destination", out, 16, "00112233445566778899aabbccddeeff");
    vst1q_u8(out, vreinterpretq_u8_u64(vsriq_n_u64(vreinterpretq_u64_u8(a), vreinterpretq_u64_u8(b), 40)));
    expect_hex("sri.2d #40", out, 16, "a5968733445566772d1e0fbbccddeeff");
}

static void test_add_across_lanes(void) {
    uint8x16_t a = vld1q_u8(first_operand), b = vld1q_u8(second_operand);
    expect_number("uaddlv.16b", vaddlvq_u8(a), 2040);
    expect_number("saddlv.16b", (uint16_t)vaddlvq_s8(vreinterpretq_s8_u8(a)), (uint16_t)-8);
    expect_number("uaddlv.8b", vaddlv_u8(vget_low_u8(b)), 1500);
    expect_number("uaddlv.8h", vaddlvq_u16(vreinterpretq_u16_u8(b)), 246840);
    expect_number("saddlv.8h", (uint32_t)vaddlvq_s16(vreinterpretq_s16_u8(b)), (uint32_t)-15304);
    expect_number("uaddlv.4s", vaddlvq_u32(vreinterpretq_u32_u8(a)), 10303430040ull);
    expect_number("saddlv.4s", (uint64_t)vaddlvq_s32(vreinterpretq_s32_u8(a)), (uint64_t)1713495448);
}

static void test_carry_arithmetic(void) {
    uint64x2_t result = carry_adcs_x(UINT64_MAX, 0, 1);
    expect_number("adcs of all ones with the carry set", vgetq_lane_u64(result, 0), 0);
    expect_number("adcs of all ones with the carry set, flags", vgetq_lane_u64(result, 1), 6);
    result = carry_sbcs_x(5, UINT64_MAX, 0);
    expect_number("sbcs of an all-ones operand with the borrow set", vgetq_lane_u64(result, 0), 5);
    expect_number("sbcs of an all-ones operand with the borrow set, flags", vgetq_lane_u64(result, 1), 0);
    result = carry_sbcs_w(5, UINT32_MAX, 0);
    expect_number("sbcs w of an all-ones operand with the borrow set, flags", vgetq_lane_u64(result, 1), 0);
    result = carry_sbcs_x(0, 0, 0);
    expect_number("sbcs of zero with the borrow set", vgetq_lane_u64(result, 0), UINT64_MAX);
    expect_number("sbcs of zero with the borrow set, flags", vgetq_lane_u64(result, 1), 8);
    result = carry_final_reduction(0x1234, 0x5678, 3);
    expect_number("poly1305 reduction keeps a value below p with the top limb 3", vgetq_lane_u64(result, 0), 0x1234);
    result = carry_final_reduction(UINT64_C(0xfffffffffffffffd), UINT64_MAX, 3);
    expect_number("poly1305 reduction subtracts p from p plus 2", vgetq_lane_u64(result, 0), 2);
    expect_number("poly1305 reduction subtracts p from p plus 2, middle limb", vgetq_lane_u64(result, 1), 0);
}

static __attribute__((noinline)) uint32_t half_of_single(float value) {
    _Float16 half = (_Float16)value;
    uint16_t bits;
    memcpy(&bits, &half, sizeof(bits));
    return bits;
}

static __attribute__((noinline)) uint32_t half_of_double(double value) {
    _Float16 half = (_Float16)value;
    uint16_t bits;
    memcpy(&bits, &half, sizeof(bits));
    return bits;
}

static __attribute__((noinline)) uint32_t single_of_half(uint16_t bits) {
    _Float16 half;
    memcpy(&half, &bits, sizeof(half));
    float value = (float)half;
    uint32_t result;
    memcpy(&result, &value, sizeof(result));
    return result;
}

static __attribute__((noinline)) uint64_t double_of_half(uint16_t bits) {
    _Float16 half;
    memcpy(&half, &bits, sizeof(half));
    double value = (double)half;
    uint64_t result;
    memcpy(&result, &value, sizeof(result));
    return result;
}

static float single_from(uint32_t bits) {
    float value;
    memcpy(&value, &bits, sizeof(value));
    return value;
}

static double double_from(uint64_t bits) {
    double value;
    memcpy(&value, &bits, sizeof(value));
    return value;
}

static void test_half_precision(void) {
    expect_number("fcvt s, h of 1.0", single_of_half(0x3c00), 0x3f800000);
    expect_number("fcvt s, h of the largest half", single_of_half(0x7bff), 0x477fe000);
    expect_number("fcvt s, h of the smallest subnormal", single_of_half(0x0001), 0x33800000);
    expect_number("fcvt s, h of -infinity", single_of_half(0xfc00), 0xff800000);
    expect_number("fcvt s, h of a signaling NaN", single_of_half(0x7d00), 0x7fe00000);
    expect_number("fcvt d, h of -2.0", double_of_half(0xc000), 0xc000000000000000ull);
    expect_number("fcvt d, h of the smallest subnormal", double_of_half(0x0001), 0x3e70000000000000ull);
    expect_number("fcvt h, s of 1.0", half_of_single(single_from(0x3f800000)), 0x3c00);
    expect_number("fcvt h, s rounds 65519.0 down", half_of_single(single_from(0x477fef00)), 0x7bff);
    expect_number("fcvt h, s rounds 65520.0 to infinity", half_of_single(single_from(0x477ff000)), 0x7c00);
    expect_number("fcvt h, s ties to even below", half_of_single(single_from(0x3f801000)), 0x3c00);
    expect_number("fcvt h, s ties to even above", half_of_single(single_from(0x3f803000)), 0x3c02);
    expect_number("fcvt h, s of 2^-25 is zero", half_of_single(single_from(0x33000000)), 0x0000);
    expect_number("fcvt h, s of a signaling NaN", half_of_single(single_from(0x7f800001)), 0x7e00);
    expect_number("fcvt h, d of 0.1", half_of_double(double_from(0x3fb999999999999aull)), 0x2e66);
    expect_number("fcvt h, d rounds once", half_of_double(double_from(0x3ff0020000000100ull)), 0x3c01);
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
    test_shift_insert();
    test_add_across_lanes();
    test_half_precision();
    test_carry_arithmetic();
    time_aes();
    time_pmull();
    printf("done\n");
    return 0;
}
