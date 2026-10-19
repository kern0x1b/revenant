#include "system_function.h"
#include "dispatch_queue_current.h"

static _Atomic(uintptr_t) charon_system_queue_attr_make_initially_inactive;

__attribute__((constructor))
static void charon_resolve_queue_attr_make_initially_inactive(void)
{
    charon_system_function(&charon_system_queue_attr_make_initially_inactive, CHARON_LIBDISPATCH, "dispatch_queue_attr_make_initially_inactive");
}

__attribute__((visibility("hidden")))
dispatch_queue_attr_t charon_queue_attr_make_initially_inactive(dispatch_queue_attr_t attr) __asm("_dispatch_queue_attr_make_initially_inactive");

dispatch_queue_attr_t charon_queue_attr_make_initially_inactive(dispatch_queue_attr_t attr)
{
    dispatch_queue_attr_t (*system)(dispatch_queue_attr_t) = charon_system_function(&charon_system_queue_attr_make_initially_inactive, CHARON_LIBDISPATCH, "dispatch_queue_attr_make_initially_inactive");
    if (system)
        return system(attr);
    return attr;
}
