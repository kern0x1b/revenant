#include <stdint.h>
#include <time.h>

uint64_t clock_uptime_probe(void)
{
    return clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
}
