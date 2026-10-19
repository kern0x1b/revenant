#include <errno.h>
#include <mach/mach_time.h>
#include <time.h>

__attribute__((visibility("hidden")))
int charon_clock_getres(clockid_t which, struct timespec *resolution)
{
    long nanoseconds;
    if (which == CLOCK_REALTIME || which == CLOCK_MONOTONIC || which == CLOCK_MONOTONIC_RAW ||
        which == CLOCK_MONOTONIC_RAW_APPROX || which == CLOCK_PROCESS_CPUTIME_ID || which == CLOCK_THREAD_CPUTIME_ID) {
        nanoseconds = 1000;
    } else if (which == CLOCK_UPTIME_RAW || which == CLOCK_UPTIME_RAW_APPROX) {
        mach_timebase_info_data_t timebase;
        if (mach_timebase_info(&timebase) != KERN_SUCCESS || timebase.denom == 0) {
            errno = EINVAL;
            return -1;
        }
        nanoseconds = (long)((timebase.numer + timebase.denom - 1) / timebase.denom);
    } else {
        errno = EINVAL;
        return -1;
    }
    if (resolution) {
        resolution->tv_sec = 0;
        resolution->tv_nsec = nanoseconds;
    }
    return 0;
}
