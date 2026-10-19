#include "dispatch_block.h"

static _Atomic(uintptr_t) revenant_system_dispatch_block_perform;

__attribute__((constructor))
static void revenant_resolve_dispatch_block_perform(void)
{
    revenant_system_function(&revenant_system_dispatch_block_perform, REVENANT_LIBDISPATCH, "dispatch_block_perform");
}

__attribute__((visibility("hidden")))
void revenant_dispatch_block_perform(dispatch_block_flags_t flags, dispatch_block_t block) __asm("_dispatch_block_perform");

void revenant_dispatch_block_perform(dispatch_block_flags_t flags, dispatch_block_t block)
{
    void (*system)(dispatch_block_flags_t, dispatch_block_t) = revenant_system_function(&revenant_system_dispatch_block_perform, REVENANT_LIBDISPATCH, "dispatch_block_perform");
    if (system) {
        system(flags, block);
        return;
    }
    if (flags & ~(unsigned long)REVENANT_BLOCK_API_MASK)
        revenant_block_crash("Invalid flags passed to dispatch_block_perform()", flags);
    struct revenant_block_data data;
    memset(&data, 0, sizeof(data));
    data.magic = REVENANT_BLOCK_MAGIC;
    data.flags = flags;
    data.atomic_flags = REVENANT_DBF_PERFORM;
    data.block = block;
    revenant_block_invoke_direct(&data);
}
