#include "../revenant_impl.h"
#include <stdint.h>
#include <revenant/clock_gettime_nsec_np.h>

__attribute__((visibility("default"))) uint64_t BACKPORT_IMPL(clock_gettime_nsec_np)(clockid_t identifier)
{
    return revenant_clock_gettime_nsec_np(identifier);
}
