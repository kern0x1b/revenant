#include <arm_neon.h>
#include <stdint.h>

#define CARRY_ARITHMETIC(name, instruction)                                                                       \
    static inline uint64x2_t name(uint64_t a, uint64_t b, uint64_t carry) {                                       \
        uint64_t sum;                                                                                             \
        unsigned n, z, c, v;                                                                                      \
        __asm__("cmp %w[carry], #1\n\t" instruction "\n\tcset %w[n], mi\n\tcset %w[z], eq\n\tcset %w[c], hs\n\tcset %w[v], vs" \
                : [sum] "=&r"(sum), [n] "=&r"(n), [z] "=&r"(z), [c] "=&r"(c), [v] "=&r"(v)                       \
                : [a] "r"(a), [b] "r"(b), [carry] "r"(carry)                                                      \
                : "cc");                                                                                          \
        return vcombine_u64(vcreate_u64(sum), vcreate_u64((uint64_t)n << 3 | (uint64_t)z << 2 | (uint64_t)c << 1 | v)); \
    }

CARRY_ARITHMETIC(carry_adc_x, "adc %[sum], %[a], %[b]")
CARRY_ARITHMETIC(carry_adc_w, "adc %w[sum], %w[a], %w[b]")
CARRY_ARITHMETIC(carry_adcs_x, "adcs %[sum], %[a], %[b]")
CARRY_ARITHMETIC(carry_adcs_w, "adcs %w[sum], %w[a], %w[b]")
CARRY_ARITHMETIC(carry_sbc_x, "sbc %[sum], %[a], %[b]")
CARRY_ARITHMETIC(carry_sbc_w, "sbc %w[sum], %w[a], %w[b]")
CARRY_ARITHMETIC(carry_sbcs_x, "sbcs %[sum], %[a], %[b]")
CARRY_ARITHMETIC(carry_sbcs_w, "sbcs %w[sum], %w[a], %w[b]")
CARRY_ARITHMETIC(carry_ngc_x, "ngc %[sum], %[b]")
CARRY_ARITHMETIC(carry_ngcs_x, "ngcs %[sum], %[b]")
CARRY_ARITHMETIC(carry_ngcs_w, "ngcs %w[sum], %w[b]")

static inline uint64x2_t carry_final_reduction(uint64_t h0, uint64_t h1, uint64_t h2) {
    uint64_t t0, t1, t2;
    __asm__("mov %[t1], #-1\n\t"
            "mov %[t2], #3\n\t"
            "adds %[t0], %[h0], #5\n\t"
            "sbcs %[t1], %[h1], %[t1]\n\t"
            "sbcs %[t2], %[h2], %[t2]\n\t"
            "csel %[h0], %[t0], %[h0], hs\n\t"
            "csel %[h1], %[t1], %[h1], hs"
            : [h0] "+r"(h0), [h1] "+r"(h1), [t0] "=&r"(t0), [t1] "=&r"(t1), [t2] "=&r"(t2)
            : [h2] "r"(h2)
            : "cc");
    return vcombine_u64(vcreate_u64(h0), vcreate_u64(h1));
}
