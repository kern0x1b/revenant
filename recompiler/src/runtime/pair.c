#include <mach/mach.h>
#include <mach/thread_switch.h>
#include <stdint.h>

#include "xl_budget_lines.h"

#define XL_PAIR_LOCKS 64
#define XL_PAIR_SPINS 1000

struct xl_pair_lock {
    volatile int32_t held;
    uint32_t stored, failed, waited, yielded;
    uint32_t unused[3];
};

static struct xl_pair_lock xl_pair_locks[XL_PAIR_LOCKS] __attribute__((aligned(32)));

uint32_t rellume_aarch64_stxp(volatile uint64_t *address, uint32_t armed, uint64_t seen_low, uint64_t seen_high, uint64_t low, uint64_t high)
{
    if (!armed)
        return 1;
    uintptr_t at = (uintptr_t)address;
    struct xl_pair_lock *lock = &xl_pair_locks[(at >> 4 ^ at >> 10) & (XL_PAIR_LOCKS - 1)];
    uint32_t spins = 0, yields = 0;
    while (lock->held || __sync_lock_test_and_set(&lock->held, 1)) {
        if (++spins % XL_PAIR_SPINS == 0) {
            thread_switch(MACH_PORT_NULL, SWITCH_OPTION_DEPRESS, 1);
            yields++;
        }
    }
    uint32_t changed = address[0] != seen_low || address[1] != seen_high;
    if (changed) {
        lock->failed++;
    } else {
        address[0] = low;
        address[1] = high;
        lock->stored++;
    }
    if (spins) {
        lock->waited++;
        lock->yielded += yields;
    }
    __sync_lock_release(&lock->held);
    return changed;
}

void xl_pair_read(struct xl_pair_count *count)
{
    count->stored = count->failed = count->waited = count->yielded = count->held = 0;
    for (unsigned index = 0; index < XL_PAIR_LOCKS; index++) {
        const struct xl_pair_lock *lock = &xl_pair_locks[index];
        count->stored += lock->stored;
        count->failed += lock->failed;
        count->waited += lock->waited;
        count->yielded += lock->yielded;
        count->held += lock->held != 0;
    }
}
