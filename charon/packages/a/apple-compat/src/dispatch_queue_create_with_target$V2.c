#include "system_function.h"
#include "dispatch_queue_current.h"
#include "dispatch_queue_width.h"

static _Atomic(uintptr_t) charon_system_queue_create_with_target;

__attribute__((constructor))
static void charon_resolve_queue_create_with_target(void)
{
    charon_system_function(&charon_system_queue_create_with_target, CHARON_LIBDISPATCH, "dispatch_queue_create_with_target$V2");
}

/* iOS 10 makes the queue with its target in place, before the queue can run a block; here the queue is made and then given the
   target, which is all dispatch_set_target_queue of iOS 5 asks, and nothing runs on the queue in between. */

__attribute__((visibility("hidden")))
dispatch_queue_t charon_queue_create_with_target(const char * label, dispatch_queue_attr_t attr, dispatch_queue_t target) __asm("_dispatch_queue_create_with_target$V2");

dispatch_queue_t charon_queue_create_with_target(const char * label, dispatch_queue_attr_t attr, dispatch_queue_t target)
{
    dispatch_queue_t (*system)(const char *, dispatch_queue_attr_t, dispatch_queue_t) = charon_system_function(&charon_system_queue_create_with_target, CHARON_LIBDISPATCH, "dispatch_queue_create_with_target$V2");
    if (system)
        return system(label, attr, target);
    dispatch_queue_t queue = dispatch_queue_create(label, attr);
    if (queue && target)
        dispatch_set_target_queue(queue, target);
    /* The width the attribute names, so that a queue made through this call is as knowable as one made
       through dispatch_queue_create: a barrier source's handler asks the width of the queue it runs on. */
    charon_queue_record_width(queue, charon_width_of_attribute(attr));
    return queue;
}
