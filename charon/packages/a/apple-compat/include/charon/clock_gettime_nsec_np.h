#ifndef CHARON_CLOCK_GETTIME_NSEC_NP_H
#define CHARON_CLOCK_GETTIME_NSEC_NP_H

#include <time.h>

#ifdef __cplusplus
extern "C" {
#endif

__uint64_t charon_clock_gettime_nsec_np(clockid_t which);

#ifdef __cplusplus
}
#endif

#define clock_gettime_nsec_np charon_clock_gettime_nsec_np

#endif
