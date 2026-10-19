#include "dispatch_block.h"

/* dispatch_async reads a block's flags from iOS 8 and submits a barrier block as dispatch_barrier_async does; before, the
   release's runs it as an ordinary one. */
__attribute__((visibility("hidden")))
void charon_dispatch_async(dispatch_queue_t queue, dispatch_block_t block)
{
    if (charon_block_unseen_barrier(block))
        dispatch_barrier_async(queue, block);
    else
        dispatch_async(queue, block);
}
