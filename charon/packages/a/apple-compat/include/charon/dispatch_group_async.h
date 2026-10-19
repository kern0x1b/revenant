#ifndef CHARON_DISPATCH_GROUP_ASYNC_H
#define CHARON_DISPATCH_GROUP_ASYNC_H

#include <dispatch/dispatch.h>

#ifdef __cplusplus
extern "C" {
#endif

void charon_dispatch_group_async(dispatch_group_t group, dispatch_queue_t queue, dispatch_block_t block);

#ifdef __cplusplus
}
#endif

#define dispatch_group_async charon_dispatch_group_async

#endif
