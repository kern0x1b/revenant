#include "system_function.h"
#include "dispatch_queue_current.h"

static _Atomic(uintptr_t) revenant_system_queue_attr_make_initially_inactive;

__attribute__((constructor))
static void revenant_resolve_queue_attr_make_initially_inactive(void)
{
    revenant_system_function(&revenant_system_queue_attr_make_initially_inactive, REVENANT_LIBDISPATCH, "dispatch_queue_attr_make_initially_inactive");
}

__attribute__((visibility("hidden")))
dispatch_queue_attr_t revenant_queue_attr_make_initially_inactive(dispatch_queue_attr_t attr) __asm("_dispatch_queue_attr_make_initially_inactive");

dispatch_queue_attr_t revenant_queue_attr_make_initially_inactive(dispatch_queue_attr_t attr)
{
    dispatch_queue_attr_t (*system)(dispatch_queue_attr_t) = revenant_system_function(&revenant_system_queue_attr_make_initially_inactive, REVENANT_LIBDISPATCH, "dispatch_queue_attr_make_initially_inactive");
    if (system)
        return system(attr);
    return attr;
}
