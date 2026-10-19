#ifndef REVENANT_CLOCK_GETRES_H
#define REVENANT_CLOCK_GETRES_H

#include <time.h>

#ifdef __cplusplus
extern "C" {
#endif

int revenant_clock_getres(clockid_t which, struct timespec *resolution);

#ifdef __cplusplus
}
#endif

#define clock_getres revenant_clock_getres

#endif
