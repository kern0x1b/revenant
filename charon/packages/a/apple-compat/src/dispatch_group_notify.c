#include "dispatch_block.h"

/* dispatch_group_notify submits a barrier block as a barrier once the group is empty from iOS 10 (libdispatch-703); the
   release's runs it on the queue as an ordinary block. */
__attribute__((visibility("hidden")))
void charon_dispatch_group_notify(dispatch_group_t group, dispatch_queue_t queue, dispatch_block_t block)
{
    if (charon_system_has_block_create())
        dispatch_group_notify(group, queue, block);
    else
        charon_block_group_notify(group, queue, block);
}
