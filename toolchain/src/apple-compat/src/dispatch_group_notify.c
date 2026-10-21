#include "dispatch_block.h"

__attribute__((visibility("hidden")))
void revenant_dispatch_group_notify(dispatch_group_t group, dispatch_queue_t queue, dispatch_block_t block)
{
    if (revenant_system_has_block_create())
        dispatch_group_notify(group, queue, block);
    else
        revenant_block_group_notify(group, queue, block);
}
