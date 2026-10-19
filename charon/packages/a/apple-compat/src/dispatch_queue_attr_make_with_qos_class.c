#include "system_function.h"
#include "dispatch_queue_current.h"

static _Atomic(uintptr_t) charon_system_queue_attr_make_with_qos_class;

__attribute__((constructor))
static void charon_resolve_queue_attr_make_with_qos_class(void)
{
    charon_system_function(&charon_system_queue_attr_make_with_qos_class, CHARON_LIBDISPATCH, "dispatch_queue_attr_make_with_qos_class");
}

/* iOS 8 answers an attribute that carries the class and the relative priority, which dispatch_queue_create reads. The release
   has neither, and dispatch_queue_create reads nothing from an attribute but whether it is the concurrent one, so the
   attribute comes back as it was given: the queue is the serial or concurrent one it would have been, and a program that asks it
   for its class (dispatch_queue_get_qos_class) is told it has none. For a class or priority iOS 8 refuses it does the same. */

__attribute__((visibility("hidden")))
dispatch_queue_attr_t charon_queue_attr_make_with_qos_class(dispatch_queue_attr_t attr, dispatch_qos_class_t qos_class, int relative_priority) __asm("_dispatch_queue_attr_make_with_qos_class");

dispatch_queue_attr_t charon_queue_attr_make_with_qos_class(dispatch_queue_attr_t attr, dispatch_qos_class_t qos_class, int relative_priority)
{
    dispatch_queue_attr_t (*system)(dispatch_queue_attr_t, dispatch_qos_class_t, int) = charon_system_function(&charon_system_queue_attr_make_with_qos_class, CHARON_LIBDISPATCH, "dispatch_queue_attr_make_with_qos_class");
    if (system)
        return system(attr, qos_class, relative_priority);
    return attr;
}
