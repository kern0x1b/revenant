#include <stdint.h>

#include "../../src/runtime/xl_budget_lines.h"

uint32_t rellume_aarch64_stxp(volatile uint64_t *address, uint32_t armed, uint64_t seen_low, uint64_t seen_high, uint64_t low, uint64_t high)
{
    if (!armed)
        return 1;
#if CONTROL == 1
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
