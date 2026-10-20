#include <stdint.h>

#define RMW(op, builtin, type, bits, order, memorder) \
    __attribute__((noinline, used)) type lse_##op##_##bits##_##order(type *p, type v) { \
        return builtin(p, v, memorder); \
    }

#define CAS(type, bits, order, success, failure) \
    __attribute__((noinline, used)) type lse_cas_##bits##_##order(type *p, type expected, type desired) { \
        __atomic_compare_exchange_n(p, &expected, desired, 0, success, failure); \
        return expected; \
    }

#define ORDERS(X, ...) \
    X(__VA_ARGS__, relaxed, __ATOMIC_RELAXED) \
    X(__VA_ARGS__, acquire, __ATOMIC_ACQUIRE) \
    X(__VA_ARGS__, release, __ATOMIC_RELEASE) \
    X(__VA_ARGS__, acq_rel, __ATOMIC_ACQ_REL) \
    X(__VA_ARGS__, seq_cst, __ATOMIC_SEQ_CST)

#define WIDTH(utype, stype, bits) \
    ORDERS(RMW, add, __atomic_fetch_add, utype, bits) \
    ORDERS(RMW, and, __atomic_fetch_and, utype, bits) \
    ORDERS(RMW, xor, __atomic_fetch_xor, utype, bits) \
    ORDERS(RMW, or, __atomic_fetch_or, utype, bits) \
    ORDERS(RMW, xchg, __atomic_exchange_n, utype, bits) \
    ORDERS(RMW, smax, __atomic_fetch_max, stype, bits) \
    ORDERS(RMW, smin, __atomic_fetch_min, stype, bits) \
    ORDERS(RMW, umax, __atomic_fetch_max, utype, bits) \
    ORDERS(RMW, umin, __atomic_fetch_min, utype, bits) \
    CAS(utype, bits, relaxed, __ATOMIC_RELAXED, __ATOMIC_RELAXED) \
    CAS(utype, bits, acquire, __ATOMIC_ACQUIRE, __ATOMIC_ACQUIRE) \
    CAS(utype, bits, release, __ATOMIC_RELEASE, __ATOMIC_RELAXED) \
    CAS(utype, bits, acq_rel, __ATOMIC_ACQ_REL, __ATOMIC_ACQUIRE) \
    CAS(utype, bits, seq_cst, __ATOMIC_SEQ_CST, __ATOMIC_SEQ_CST)

WIDTH(uint8_t, int8_t, 8)
WIDTH(uint16_t, int16_t, 16)
WIDTH(uint32_t, int32_t, 32)
WIDTH(uint64_t, int64_t, 64)

static uint64_t cell;

int main(void) {
    uint8_t *byte = (uint8_t *) &cell;
    lse_add_8_seq_cst(byte, 1);
    lse_cas_64_seq_cst(&cell, 1, 2);
    return (int) cell;
}
