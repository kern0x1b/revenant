#include "dispatch_block.h"

static _Atomic(uintptr_t) charon_system_dispatch_block_notify;

__attribute__((constructor))
static void charon_resolve_dispatch_block_notify(void)
{
    charon_system_function(&charon_system_dispatch_block_notify, CHARON_LIBDISPATCH, "dispatch_block_notify");
}

__attribute__((visibility("hidden")))
void charon_dispatch_block_notify(dispatch_block_t block, dispatch_queue_t queue, dispatch_block_t notification) __asm("_dispatch_block_notify");

void charon_dispatch_block_notify(dispatch_block_t block, dispatch_queue_t queue, dispatch_block_t notification)
{
    void (*system)(dispatch_block_t, dispatch_queue_t, dispatch_block_t) = charon_system_function(&charon_system_dispatch_block_notify, CHARON_LIBDISPATCH, "dispatch_block_notify");
    if (system) {
        system(block, queue, notification);
        return;
    }
    struct charon_block_data *data = charon_block_data(block);
    if (!data)
        charon_block_crash("Invalid block object passed to dispatch_block_notify()", (unsigned long)block);
    int performed = data->performed;
    if (performed > 1)
        charon_block_crash("A block object may not be both run more than once and observed", performed);
    charon_block_group_notify(data->group, queue, notification);
}
