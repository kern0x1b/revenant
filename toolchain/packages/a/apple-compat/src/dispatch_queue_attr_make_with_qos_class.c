#include "system_function.h"
#include "dispatch_queue_current.h"

static _Atomic(uintptr_t) revenant_system_queue_attr_make_with_qos_class;

__attribute__((constructor))
static void revenant_resolve_queue_attr_make_with_qos_class(void)
{
    revenant_system_function(&revenant_system_queue_attr_make_with_qos_class, REVENANT_LIBDISPATCH, "dispatch_queue_attr_make_with_qos_class");
}

__attribute__((visibility("hidden")))
dispatch_queue_attr_t revenant_queue_attr_make_with_qos_class(dispatch_queue_attr_t attr, dispatch_qos_class_t qos_class, int relative_priority) __asm("_dispatch_queue_attr_make_with_qos_class");

dispatch_queue_attr_t revenant_queue_attr_make_with_qos_class(dispatch_queue_attr_t attr, dispatch_qos_class_t qos_class, int relative_priority)
{
    dispatch_queue_attr_t (*system)(dispatch_queue_attr_t, dispatch_qos_class_t, int) = revenant_system_function(&revenant_system_queue_attr_make_with_qos_class, REVENANT_LIBDISPATCH, "dispatch_queue_attr_make_with_qos_class");
    if (system)
        return system(attr, qos_class, relative_priority);
    return attr;
}
