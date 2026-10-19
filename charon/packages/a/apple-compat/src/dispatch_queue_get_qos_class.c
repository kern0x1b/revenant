#include "system_function.h"
#include "dispatch_queue_current.h"

static _Atomic(uintptr_t) charon_system_queue_get_qos_class;

__attribute__((constructor))
static void charon_resolve_queue_get_qos_class(void)
{
    charon_system_function(&charon_system_queue_get_qos_class, CHARON_LIBDISPATCH, "dispatch_queue_get_qos_class");
}

/* The main queue is user-interactive and a global queue has the class its priority became in iOS 8, but the default one: its
   root queue holds the default class only as a fallback for work that names none (libdispatch's init.c), and answers none,
   as Darwin's does when the test asks it. A queue made with dispatch_queue_create has no class of its own until iOS 8 gives
   it one, and the release never does. */

__attribute__((visibility("hidden")))
dispatch_qos_class_t charon_queue_get_qos_class(dispatch_queue_t queue, int * relative_priority) __asm("_dispatch_queue_get_qos_class");

dispatch_qos_class_t charon_queue_get_qos_class(dispatch_queue_t queue, int * relative_priority)
{
    dispatch_qos_class_t (*system)(dispatch_queue_t, int *) = charon_system_function(&charon_system_queue_get_qos_class, CHARON_LIBDISPATCH, "dispatch_queue_get_qos_class");
    if (system)
        return system(queue, relative_priority);
    if (relative_priority)
        *relative_priority = 0;
    if (queue == dispatch_get_main_queue())
        return 0x21;
    long priority;
    if (charon_global_priority(queue, &priority))
        return priority == DISPATCH_QUEUE_PRIORITY_HIGH ? 0x19 : priority == DISPATCH_QUEUE_PRIORITY_DEFAULT ? 0 :
               priority == DISPATCH_QUEUE_PRIORITY_LOW ? 0x11 : 0x09;
    return 0;
}
