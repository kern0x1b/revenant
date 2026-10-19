#include "dispatch_block.h"

/* dispatch_sync reads a block's flags from iOS 8 and runs a barrier block as dispatch_barrier_sync does; before, the
   release's runs it beside the queue's other blocks. */
__attribute__((visibility("hidden")))
void charon_dispatch_sync(dispatch_queue_t queue, dispatch_block_t block)
{
    if (charon_block_unseen_barrier(block))
        dispatch_barrier_sync(queue, block);
    else
        dispatch_sync(queue, block);
}
