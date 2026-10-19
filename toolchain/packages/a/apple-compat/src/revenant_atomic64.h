#ifndef CHARON_ATOMIC64_H
#define CHARON_ATOMIC64_H

#include <stdint.h>

static inline int64_t charon_atomic_add64(volatile int64_t *address, int64_t delta)
{
#if defined(__arm__)
    int64_t before, after;
    uint32_t failed;
    __asm__ __volatile__(
        "dmb ish\n"
        "1: ldrexd %Q[before], %R[before], [%[address]]\n"
        "   adds   %Q[after], %Q[before], %Q[delta]\n"
        "   adc    %R[after], %R[before], %R[delta]\n"
        "   strexd %[failed], %Q[after], %R[after], [%[address]]\n"
        "   cmp    %[failed], #0\n"
        "   bne    1b\n"
        "dmb ish\n"
        : [before] "=&r"(before), [after] "=&r"(after), [failed] "=&r"(failed)
        : [address] "r"(address), [delta] "r"(delta)
        : "cc", "memory");
    return after;
#else
    return __atomic_add_fetch(address, delta, __ATOMIC_SEQ_CST);
#endif
}

#endif
