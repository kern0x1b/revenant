#include <dispatch/dispatch.h>
#include "system_function.h"

static _Atomic(uintptr_t) revenant_system_qos;

__attribute__((constructor))
static void revenant_resolve_qos(void)
{
    revenant_system_function(&revenant_system_qos, REVENANT_LIBSYSTEM_PTHREAD, "qos_class_self");
}

__attribute__((visibility("hidden")))
dispatch_queue_t revenant_dispatch_get_global_queue(long identifier, unsigned long flags)
{
    if (!revenant_system_function(&revenant_system_qos, REVENANT_LIBSYSTEM_PTHREAD, "qos_class_self")) {
        switch (identifier) {
        case 0x21:
        case 0x19:
            identifier = DISPATCH_QUEUE_PRIORITY_HIGH;
            break;
        case 0x15:
            identifier = DISPATCH_QUEUE_PRIORITY_DEFAULT;
            break;
        case 0x11:
            identifier = DISPATCH_QUEUE_PRIORITY_LOW;
            break;
        case 0x09:
            identifier = DISPATCH_QUEUE_PRIORITY_BACKGROUND;
            break;
        }
    }
    return dispatch_get_global_queue(identifier, flags);
}
