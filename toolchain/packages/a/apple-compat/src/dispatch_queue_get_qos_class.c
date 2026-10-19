#include "system_function.h"
#include "dispatch_queue_current.h"

static _Atomic(uintptr_t) revenant_system_queue_get_qos_class;

__attribute__((constructor))
static void revenant_resolve_queue_get_qos_class(void)
{
    revenant_system_function(&revenant_system_queue_get_qos_class, REVENANT_LIBDISPATCH, "dispatch_queue_get_qos_class");
}

__attribute__((visibility("hidden")))
dispatch_qos_class_t revenant_queue_get_qos_class(dispatch_queue_t queue, int * relative_priority) __asm("_dispatch_queue_get_qos_class");

dispatch_qos_class_t revenant_queue_get_qos_class(dispatch_queue_t queue, int * relative_priority)
{
    dispatch_qos_class_t (*system)(dispatch_queue_t, int *) = revenant_system_function(&revenant_system_queue_get_qos_class, REVENANT_LIBDISPATCH, "dispatch_queue_get_qos_class");
    if (system)
        return system(queue, relative_priority);
    if (relative_priority)
        *relative_priority = 0;
    if (queue == dispatch_get_main_queue())
        return 0x21;
    long priority;
    if (revenant_global_priority(queue, &priority))
        return priority == DISPATCH_QUEUE_PRIORITY_HIGH ? 0x19 : priority == DISPATCH_QUEUE_PRIORITY_DEFAULT ? 0 :
               priority == DISPATCH_QUEUE_PRIORITY_LOW ? 0x11 : 0x09;
    return 0;
}
