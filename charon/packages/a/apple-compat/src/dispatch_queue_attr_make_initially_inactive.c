#include "system_function.h"
#include "dispatch_queue_current.h"

static _Atomic(uintptr_t) charon_system_queue_attr_make_initially_inactive;

__attribute__((constructor))
static void charon_resolve_queue_attr_make_initially_inactive(void)
{
    charon_system_function(&charon_system_queue_attr_make_initially_inactive, CHARON_LIBDISPATCH, "dispatch_queue_attr_make_initially_inactive");
}

/* A queue of iOS 10 made from this attribute starts inactive and runs nothing until dispatch_activate. The release has no
   inactive queue, so the queue starts active, and dispatch_activate of a queue is the no-op it is on an active one: a block
   submitted before the activation may run before it. A port that sets the target of the queue before it activates it (which
   iOS 10 allows only while inactive) still gets the target, since dispatch_set_target_queue of the release takes it. */

__attribute__((visibility("hidden")))
dispatch_queue_attr_t charon_queue_attr_make_initially_inactive(dispatch_queue_attr_t attr) __asm("_dispatch_queue_attr_make_initially_inactive");

dispatch_queue_attr_t charon_queue_attr_make_initially_inactive(dispatch_queue_attr_t attr)
{
    dispatch_queue_attr_t (*system)(dispatch_queue_attr_t) = charon_system_function(&charon_system_queue_attr_make_initially_inactive, CHARON_LIBDISPATCH, "dispatch_queue_attr_make_initially_inactive");
    if (system)
        return system(attr);
    return attr;
}
