#ifndef CHARON_CLOCK_GETTIME_H
#define CHARON_CLOCK_GETTIME_H

#include <time.h>

#ifdef __cplusplus
extern "C" {
#endif

int charon_clock_gettime(clockid_t which, struct timespec *now);

#ifdef __cplusplus
}
#endif

#define clock_gettime charon_clock_gettime

#endif
