#include "../revenant_impl.h"
#include <revenant/clock_getres.h>

__attribute__((visibility("default"))) int BACKPORT_IMPL(clock_getres)(clockid_t identifier, struct timespec *resolution)
{
    return revenant_clock_getres(identifier, resolution);
}
