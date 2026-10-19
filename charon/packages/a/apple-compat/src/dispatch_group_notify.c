#include "dispatch_block.h"

__attribute__((visibility("hidden")))
void charon_dispatch_group_notify(dispatch_group_t group, dispatch_queue_t queue, dispatch_block_t block)
{
    if (charon_system_has_block_create())
        dispatch_group_notify(group, queue, block);
    else
        charon_block_group_notify(group, queue, block);
}
