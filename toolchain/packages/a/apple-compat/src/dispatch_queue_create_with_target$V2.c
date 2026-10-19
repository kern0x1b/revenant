#include "system_function.h"
#include "dispatch_queue_current.h"
#include "dispatch_queue_width.h"

static _Atomic(uintptr_t) revenant_system_queue_create_with_target;

__attribute__((constructor))
static void revenant_resolve_queue_create_with_target(void)
{
    revenant_system_function(&revenant_system_queue_create_with_target, REVENANT_LIBDISPATCH, "dispatch_queue_create_with_target$V2");
}

__attribute__((visibility("hidden")))
dispatch_queue_t revenant_queue_create_with_target(const char * label, dispatch_queue_attr_t attr, dispatch_queue_t target) __asm("_dispatch_queue_create_with_target$V2");

dispatch_queue_t revenant_queue_create_with_target(const char * label, dispatch_queue_attr_t attr, dispatch_queue_t target)
{
    dispatch_queue_t (*system)(const char *, dispatch_queue_attr_t, dispatch_queue_t) = revenant_system_function(&revenant_system_queue_create_with_target, REVENANT_LIBDISPATCH, "dispatch_queue_create_with_target$V2");
    if (system)
        return system(label, attr, target);
    dispatch_queue_t queue = dispatch_queue_create(label, attr);
    if (queue && target)
        dispatch_set_target_queue(queue, target);
    revenant_queue_record_width(queue, revenant_width_of_attribute(attr));
    return queue;
}
