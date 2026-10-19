#include <errno.h>
#include <mach/mach.h>
#include <mach/mach_time.h>
#include <sys/resource.h>
#include <sys/sysctl.h>
#include <sys/time.h>
#include <time.h>

static int charon_since_boot(struct timespec *now)
{
    int name[] = { CTL_KERN, KERN_BOOTTIME };
    struct timeval before, after, calendar;
    size_t size = sizeof before;
    do {
        if (sysctl(name, 2, &before, &size, NULL, 0) != 0 || gettimeofday(&calendar, NULL) != 0 ||
            sysctl(name, 2, &after, &size, NULL, 0) != 0)
            return -1;
    } while (before.tv_sec != after.tv_sec || before.tv_usec != after.tv_usec);
    long long microseconds = ((long long)calendar.tv_sec - before.tv_sec) * 1000000LL + calendar.tv_usec -
                             before.tv_usec;
    now->tv_sec = (time_t)(microseconds / 1000000LL);
    now->tv_nsec = (long)(microseconds % 1000000LL) * 1000;
    return 0;
}

static int charon_uptime(struct timespec *now)
{
    static mach_timebase_info_data_t timebase;
    if (timebase.denom == 0 && mach_timebase_info(&timebase) != KERN_SUCCESS)
        return -1;
    uint64_t ticks = mach_absolute_time();
    uint64_t nanoseconds = ticks / timebase.denom * timebase.numer + ticks % timebase.denom * timebase.numer / timebase.denom;
    now->tv_sec = (time_t)(nanoseconds / 1000000000u);
    now->tv_nsec = (long)(nanoseconds % 1000000000u);
    return 0;
}

static int charon_process_time(struct timespec *now)
{
    struct rusage usage;
    if (getrusage(RUSAGE_SELF, &usage) != 0)
        return -1;
    long long microseconds = ((long long)usage.ru_utime.tv_sec + usage.ru_stime.tv_sec) * 1000000LL +
                             usage.ru_utime.tv_usec + usage.ru_stime.tv_usec;
    now->tv_sec = (time_t)(microseconds / 1000000LL);
    now->tv_nsec = (long)(microseconds % 1000000LL) * 1000;
    return 0;
}

static int charon_thread_time(struct timespec *now)
{
    thread_basic_info_data_t info;
    mach_msg_type_number_t count = THREAD_BASIC_INFO_COUNT;
    mach_port_t thread = mach_thread_self();
    kern_return_t got = thread_info(thread, THREAD_BASIC_INFO, (thread_info_t)&info, &count);
    mach_port_deallocate(mach_task_self(), thread);
    if (got != KERN_SUCCESS)
        return -1;
    long long microseconds = ((long long)info.user_time.seconds + info.system_time.seconds) * 1000000LL +
                             info.user_time.microseconds + info.system_time.microseconds;
    now->tv_sec = (time_t)(microseconds / 1000000LL);
    now->tv_nsec = (long)(microseconds % 1000000LL) * 1000;
    return 0;
}

__attribute__((visibility("hidden")))
int charon_clock_gettime(clockid_t which, struct timespec *now)
{
    int answered;
    if (which == CLOCK_REALTIME) {
        struct timeval calendar;
        answered = gettimeofday(&calendar, NULL);
        now->tv_sec = calendar.tv_sec;
        now->tv_nsec = calendar.tv_usec * 1000;
    } else if (which == CLOCK_MONOTONIC || which == CLOCK_MONOTONIC_RAW || which == CLOCK_MONOTONIC_RAW_APPROX) {
        answered = charon_since_boot(now);
    } else if (which == CLOCK_UPTIME_RAW || which == CLOCK_UPTIME_RAW_APPROX) {
        answered = charon_uptime(now);
    } else if (which == CLOCK_PROCESS_CPUTIME_ID) {
        answered = charon_process_time(now);
    } else if (which == CLOCK_THREAD_CPUTIME_ID) {
        answered = charon_thread_time(now);
    } else {
        errno = EINVAL;
        return -1;
    }
    if (answered != 0) {
        errno = EINVAL;
        return -1;
    }
    return 0;
}
