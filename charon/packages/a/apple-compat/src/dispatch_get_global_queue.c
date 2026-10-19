#include <dispatch/dispatch.h>
#include "system_function.h"

static _Atomic(uintptr_t) charon_system_qos;

__attribute__((constructor))
static void charon_resolve_qos(void)
{
    charon_system_function(&charon_system_qos, CHARON_LIBSYSTEM_PTHREAD, "qos_class_self");
}

/* dispatch_get_global_queue took a class of service in place of a priority from iOS 8, the release qos_class_self arrived in;
   before, a class answers NULL. The priority each class stands in for is the one queue.h documents
   (DISPATCH_QUEUE_PRIORITY_HIGH is QOS_CLASS_USER_INITIATED, and so on); iOS 6 has no queue above HIGH for user-interactive
   work. A priority, and anything else, reaches the system unchanged. */
__attribute__((visibility("hidden")))
dispatch_queue_t charon_dispatch_get_global_queue(long identifier, unsigned long flags)
{
    if (!charon_system_function(&charon_system_qos, CHARON_LIBSYSTEM_PTHREAD, "qos_class_self")) {
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
