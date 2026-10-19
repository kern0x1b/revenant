#include "dispatch_block.h"

static _Atomic(uintptr_t) revenant_system_dispatch_block_notify;

__attribute__((constructor))
static void revenant_resolve_dispatch_block_notify(void)
{
    revenant_system_function(&revenant_system_dispatch_block_notify, REVENANT_LIBDISPATCH, "dispatch_block_notify");
}

__attribute__((visibility("hidden")))
void revenant_dispatch_block_notify(dispatch_block_t block, dispatch_queue_t queue, dispatch_block_t notification) __asm("_dispatch_block_notify");

void revenant_dispatch_block_notify(dispatch_block_t block, dispatch_queue_t queue, dispatch_block_t notification)
{
    void (*system)(dispatch_block_t, dispatch_queue_t, dispatch_block_t) = revenant_system_function(&revenant_system_dispatch_block_notify, REVENANT_LIBDISPATCH, "dispatch_block_notify");
    if (system) {
        system(block, queue, notification);
        return;
    }
    struct revenant_block_data *data = revenant_block_data(block);
    if (!data)
        revenant_block_crash("Invalid block object passed to dispatch_block_notify()", (unsigned long)block);
    int performed = data->performed;
    if (performed > 1)
        revenant_block_crash("A block object may not be both run more than once and observed", performed);
    revenant_block_group_notify(data->group, queue, notification);
}
