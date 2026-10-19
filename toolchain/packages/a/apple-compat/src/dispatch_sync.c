#include "dispatch_block.h"

__attribute__((visibility("hidden")))
void charon_dispatch_sync(dispatch_queue_t queue, dispatch_block_t block)
{
    if (charon_block_unseen_barrier(block))
        dispatch_barrier_sync(queue, block);
    else
        dispatch_sync(queue, block);
}
