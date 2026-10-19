#include "dispatch_block.h"

static _Atomic(uintptr_t) revenant_system_dispatch_block_wait;

__attribute__((constructor))
static void revenant_resolve_dispatch_block_wait(void)
{
    revenant_system_function(&revenant_system_dispatch_block_wait, REVENANT_LIBDISPATCH, "dispatch_block_wait");
}

__attribute__((visibility("hidden")))
intptr_t revenant_dispatch_block_wait(dispatch_block_t block, dispatch_time_t timeout) __asm("_dispatch_block_wait");

intptr_t revenant_dispatch_block_wait(dispatch_block_t block, dispatch_time_t timeout)
{
    intptr_t (*system)(dispatch_block_t, dispatch_time_t) = revenant_system_function(&revenant_system_dispatch_block_wait, REVENANT_LIBDISPATCH, "dispatch_block_wait");
    if (system)
        return system(block, timeout);
    struct revenant_block_data *data = revenant_block_data(block);
    if (!data)
        revenant_block_crash("Invalid block object passed to dispatch_block_wait()", 0);
    unsigned int flags = revenant_block_or(&data->atomic_flags, REVENANT_DBF_WAITING);
    if (flags & (REVENANT_DBF_WAITED | REVENANT_DBF_WAITING))
        revenant_block_crash("A block object may not be waited for more than once", flags);
    int performed = data->performed;
    if (performed > 1)
        revenant_block_crash("A block object may not be both run more than once and waited for", performed);
    long timed_out = dispatch_group_wait(data->group, timeout);
    if (timed_out)
        __atomic_fetch_and(&data->atomic_flags, ~REVENANT_DBF_WAITING, __ATOMIC_RELAXED);
    else
        revenant_block_or(&data->atomic_flags, REVENANT_DBF_WAITED);
    return timed_out;
}
