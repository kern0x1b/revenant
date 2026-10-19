#include <dispatch/dispatch.h>
#include <pthread.h>
#include "system_function.h"

static _Atomic(uintptr_t) revenant_system_qos_class_self;

__attribute__((constructor))
static void revenant_resolve_qos_class_self(void)
{
    revenant_system_function(&revenant_system_qos_class_self, REVENANT_LIBSYSTEM_PTHREAD, "qos_class_self");
}

enum {
    REVENANT_QOS_USER_INTERACTIVE = 0x21,
    REVENANT_QOS_USER_INITIATED = 0x19,
    REVENANT_QOS_DEFAULT = 0x15,
    REVENANT_QOS_UTILITY = 0x11,
    REVENANT_QOS_BACKGROUND = 0x09,
    REVENANT_QUEUE_OVERCOMMIT = 0x2,
};

static int revenant_runs_on_root(dispatch_queue_t current, long priority)
{
    return current == dispatch_get_global_queue(priority, 0) ||
           current == dispatch_get_global_queue(priority, REVENANT_QUEUE_OVERCOMMIT);
}

__attribute__((visibility("hidden")))
unsigned int qos_class_self(void)
{
    unsigned int (*system)(void) = revenant_system_function(&revenant_system_qos_class_self, REVENANT_LIBSYSTEM_PTHREAD, "qos_class_self");
    if (system)
        return system();
    if (pthread_main_np())
        return REVENANT_QOS_USER_INTERACTIVE;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    dispatch_queue_t current = dispatch_get_current_queue();
#pragma clang diagnostic pop
    if (revenant_runs_on_root(current, DISPATCH_QUEUE_PRIORITY_HIGH))
        return REVENANT_QOS_USER_INITIATED;
    if (revenant_runs_on_root(current, DISPATCH_QUEUE_PRIORITY_LOW))
        return REVENANT_QOS_UTILITY;
    if (revenant_runs_on_root(current, DISPATCH_QUEUE_PRIORITY_BACKGROUND))
        return REVENANT_QOS_BACKGROUND;
    return REVENANT_QOS_DEFAULT;
}
