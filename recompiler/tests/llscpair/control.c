#include <stdint.h>

#include "../../src/runtime/xl_budget_lines.h"

#if CONTROL == 3
static volatile int32_t locks[64];
#endif

uint32_t rellume_aarch64_stxp(volatile uint64_t *address, uint32_t armed, uint64_t seen_low, uint64_t seen_high, uint64_t low, uint64_t high)
{
    if (!armed)
        return 1;
#if CONTROL == 3
    uintptr_t at = (uintptr_t)address;
    volatile int32_t *lock = &locks[(at >> 4 ^ at >> 10) & 63];
    while (__sync_lock_test_and_set(lock, 1)) {
    }
    uint32_t changed = address[0] != seen_low || address[1] != seen_high;
    if (!changed) {
        address[0] = low;
        address[1] = high;
    }
    __sync_lock_release(lock);
    return changed;
#elif CONTROL == 1
    (void)seen_low;
    (void)seen_high;
#else
    if (address[0] != seen_low || address[1] != seen_high)
        return 1;
    for (volatile unsigned pause = 0; pause < 8; pause++) {
    }
#endif
    address[0] = low;
    address[1] = high;
    return 0;
}

void xl_pair_read(struct xl_pair_count *count)
{
    count->stored = count->failed = count->waited = count->yielded = count->held = 0;
}
