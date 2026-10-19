#ifndef REVENANT_CLOCK_GETTIME_NSEC_NP_H
#define REVENANT_CLOCK_GETTIME_NSEC_NP_H

#include <time.h>

#ifdef __cplusplus
extern "C" {
#endif

__uint64_t revenant_clock_gettime_nsec_np(clockid_t which);

#ifdef __cplusplus
}
#endif

#define clock_gettime_nsec_np revenant_clock_gettime_nsec_np

#endif
