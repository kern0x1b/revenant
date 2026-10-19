#include <stdint.h>
#include <time.h>

int charon_clock_gettime(clockid_t which, struct timespec *now);

/* charon_clock_gettime's answer as one count of nanoseconds, as Darwin's is its clock_gettime's; a clock it refuses answers 0,
   with the errno charon_clock_gettime set, as Darwin's does. */
__attribute__((visibility("hidden")))
uint64_t charon_clock_gettime_nsec_np(clockid_t which)
{
    struct timespec now;
    if (charon_clock_gettime(which, &now) != 0)
        return 0;
    return (uint64_t)now.tv_sec * 1000000000u + (uint64_t)now.tv_nsec;
}
