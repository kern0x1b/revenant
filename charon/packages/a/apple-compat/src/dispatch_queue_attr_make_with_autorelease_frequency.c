#include "system_function.h"
#include "dispatch_queue_current.h"

static _Atomic(uintptr_t) charon_system_queue_attr_make_with_autorelease_frequency;

__attribute__((constructor))
static void charon_resolve_queue_attr_make_with_autorelease_frequency(void)
{
    charon_system_function(&charon_system_queue_attr_make_with_autorelease_frequency, CHARON_LIBDISPATCH, "dispatch_queue_attr_make_with_autorelease_frequency");
}

/* The release drains its autorelease pool around each block a queue runs, as iOS 10 does for DISPATCH_AUTORELEASE_FREQUENCY_WORK_ITEM,
   and has no other frequency to choose: the attribute comes back as it was given. */

__attribute__((visibility("hidden")))
dispatch_queue_attr_t charon_queue_attr_make_with_autorelease_frequency(dispatch_queue_attr_t attr, dispatch_autorelease_frequency_t frequency) __asm("_dispatch_queue_attr_make_with_autorelease_frequency");

dispatch_queue_attr_t charon_queue_attr_make_with_autorelease_frequency(dispatch_queue_attr_t attr, dispatch_autorelease_frequency_t frequency)
{
    dispatch_queue_attr_t (*system)(dispatch_queue_attr_t, dispatch_autorelease_frequency_t) = charon_system_function(&charon_system_queue_attr_make_with_autorelease_frequency, CHARON_LIBDISPATCH, "dispatch_queue_attr_make_with_autorelease_frequency");
    if (system)
        return system(attr, frequency);
    return attr;
}
