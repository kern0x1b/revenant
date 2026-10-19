#ifndef CHARON_CLOCK_GETRES_H
#define CHARON_CLOCK_GETRES_H

#include <time.h>

#ifdef __cplusplus
extern "C" {
#endif

int charon_clock_getres(clockid_t which, struct timespec *resolution);

#ifdef __cplusplus
}
#endif

#define clock_getres charon_clock_getres

#endif
