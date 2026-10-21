#ifndef REVENANT_DISPATCH_SYNC_H
#define REVENANT_DISPATCH_SYNC_H

#include <dispatch/dispatch.h>

#ifdef __cplusplus
extern "C" {
#endif

void revenant_dispatch_sync(dispatch_queue_t queue, dispatch_block_t block);

#ifdef __cplusplus
}
#endif

#define dispatch_sync revenant_dispatch_sync

#endif
