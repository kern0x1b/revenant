#ifndef REVENANT_DISPATCH_ASYNC_H
#define REVENANT_DISPATCH_ASYNC_H

#include <dispatch/dispatch.h>

#ifdef __cplusplus
extern "C" {
#endif

void revenant_dispatch_async(dispatch_queue_t queue, dispatch_block_t block);

#ifdef __cplusplus
}
#endif

#define dispatch_async revenant_dispatch_async

#endif
