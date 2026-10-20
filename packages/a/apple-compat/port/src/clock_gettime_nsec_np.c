#include <stdint.h>
#include <time.h>

int revenant_clock_gettime(clockid_t which, struct timespec *now);

__attribute__((visibility("hidden")))
uint64_t revenant_clock_gettime_nsec_np(clockid_t which)
{
    struct timespec now;
    if (revenant_clock_gettime(which, &now) != 0)
        return 0;
    return (uint64_t)now.tv_sec * 1000000000u + (uint64_t)now.tv_nsec;
}
