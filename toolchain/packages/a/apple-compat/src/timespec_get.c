#include <time.h>
#include "system_function.h"

#ifndef TIME_UTC
#define TIME_UTC 1
#endif

static _Atomic(uintptr_t) charon_system_timespec_get;

__attribute__((constructor))
static void charon_resolve_timespec_get(void)
{
    charon_system_function(&charon_system_timespec_get, CHARON_LIBSYSTEM, "timespec_get");
}

__attribute__((visibility("default")))
int timespec_get(struct timespec *ts, int base)
{
    int (*system)(struct timespec *, int) = charon_system_function(&charon_system_timespec_get, CHARON_LIBSYSTEM, "timespec_get");
    if (system)
        return system(ts, base);
    if (base != TIME_UTC)
        return 0;
    if (clock_gettime(CLOCK_REALTIME, ts) != 0)
        return 0;
    return base;
}
