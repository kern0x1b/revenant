#include <dispatch/dispatch.h>
#include <pthread.h>
#include "system_function.h"

static _Atomic(uintptr_t) charon_system_qos_class_self;

__attribute__((constructor))
static void charon_resolve_qos_class_self(void)
{
    charon_system_function(&charon_system_qos_class_self, CHARON_LIBSYSTEM_PTHREAD, "qos_class_self");
}

enum {
    CHARON_QOS_USER_INTERACTIVE = 0x21,
    CHARON_QOS_USER_INITIATED = 0x19,
    CHARON_QOS_DEFAULT = 0x15,
    CHARON_QOS_UTILITY = 0x11,
    CHARON_QOS_BACKGROUND = 0x09,
    CHARON_QUEUE_OVERCOMMIT = 0x2,
};

static int charon_runs_on_root(dispatch_queue_t current, long priority)
{
    return current == dispatch_get_global_queue(priority, 0) ||
           current == dispatch_get_global_queue(priority, CHARON_QUEUE_OVERCOMMIT);
}

__attribute__((visibility("hidden")))
unsigned int qos_class_self(void)
{
    unsigned int (*system)(void) = charon_system_function(&charon_system_qos_class_self, CHARON_LIBSYSTEM_PTHREAD, "qos_class_self");
    if (system)
        return system();
    if (pthread_main_np())
        return CHARON_QOS_USER_INTERACTIVE;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    dispatch_queue_t current = dispatch_get_current_queue();
#pragma clang diagnostic pop
    if (charon_runs_on_root(current, DISPATCH_QUEUE_PRIORITY_HIGH))
        return CHARON_QOS_USER_INITIATED;
    if (charon_runs_on_root(current, DISPATCH_QUEUE_PRIORITY_LOW))
        return CHARON_QOS_UTILITY;
    if (charon_runs_on_root(current, DISPATCH_QUEUE_PRIORITY_BACKGROUND))
        return CHARON_QOS_BACKGROUND;
    return CHARON_QOS_DEFAULT;
}
