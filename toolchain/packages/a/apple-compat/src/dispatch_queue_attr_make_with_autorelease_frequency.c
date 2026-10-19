#include "system_function.h"
#include "dispatch_queue_current.h"

static _Atomic(uintptr_t) revenant_system_queue_attr_make_with_autorelease_frequency;

__attribute__((constructor))
static void revenant_resolve_queue_attr_make_with_autorelease_frequency(void)
{
    revenant_system_function(&revenant_system_queue_attr_make_with_autorelease_frequency, REVENANT_LIBDISPATCH, "dispatch_queue_attr_make_with_autorelease_frequency");
}

__attribute__((visibility("hidden")))
dispatch_queue_attr_t revenant_queue_attr_make_with_autorelease_frequency(dispatch_queue_attr_t attr, dispatch_autorelease_frequency_t frequency) __asm("_dispatch_queue_attr_make_with_autorelease_frequency");

dispatch_queue_attr_t revenant_queue_attr_make_with_autorelease_frequency(dispatch_queue_attr_t attr, dispatch_autorelease_frequency_t frequency)
{
    dispatch_queue_attr_t (*system)(dispatch_queue_attr_t, dispatch_autorelease_frequency_t) = revenant_system_function(&revenant_system_queue_attr_make_with_autorelease_frequency, REVENANT_LIBDISPATCH, "dispatch_queue_attr_make_with_autorelease_frequency");
    if (system)
        return system(attr, frequency);
    return attr;
}
