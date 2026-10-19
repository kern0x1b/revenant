#include <errno.h>
#include <mach/mach_time.h>
#include <time.h>

/* The resolution of the clocks charon_clock_gettime answers, which is not always Darwin's: CLOCK_MONOTONIC_RAW counts from the
   boot time in microseconds and CLOCK_THREAD_CPUTIME_ID from thread_info's microseconds, where Darwin reads the Mach clock; the
   uptime clocks read mach_absolute_time, whose tick is the timebase, rounded up to a nanosecond as Darwin does. */
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
