#include "dispatch_block.h"

static _Atomic(uintptr_t) charon_system_dispatch_block_wait;

__attribute__((constructor))
static void charon_resolve_dispatch_block_wait(void)
{
    charon_system_function(&charon_system_dispatch_block_wait, CHARON_LIBDISPATCH, "dispatch_block_wait");
}

__attribute__((visibility("hidden")))
intptr_t charon_dispatch_block_wait(dispatch_block_t block, dispatch_time_t timeout) __asm("_dispatch_block_wait");

intptr_t charon_dispatch_block_wait(dispatch_block_t block, dispatch_time_t timeout)
{
    intptr_t (*system)(dispatch_block_t, dispatch_time_t) = charon_system_function(&charon_system_dispatch_block_wait, CHARON_LIBDISPATCH, "dispatch_block_wait");
    if (system)
        return system(block, timeout);
    struct charon_block_data *data = charon_block_data(block);
    if (!data)
        charon_block_crash("Invalid block object passed to dispatch_block_wait()", 0);
    unsigned int flags = charon_block_or(&data->atomic_flags, CHARON_DBF_WAITING);
    if (flags & (CHARON_DBF_WAITED | CHARON_DBF_WAITING))
        charon_block_crash("A block object may not be waited for more than once", flags);
    int performed = data->performed;
    if (performed > 1)
        charon_block_crash("A block object may not be both run more than once and waited for", performed);
    long timed_out = dispatch_group_wait(data->group, timeout);
    if (timed_out)
        __atomic_fetch_and(&data->atomic_flags, ~CHARON_DBF_WAITING, __ATOMIC_RELAXED);
    else
        charon_block_or(&data->atomic_flags, CHARON_DBF_WAITED);
    return timed_out;
}
