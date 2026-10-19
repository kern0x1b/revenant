#ifndef REVENANT_DISPATCH_GROUP_NOTIFY_H
#define REVENANT_DISPATCH_GROUP_NOTIFY_H

#include <dispatch/dispatch.h>

#ifdef __cplusplus
extern "C" {
#endif

void revenant_dispatch_group_notify(dispatch_group_t group, dispatch_queue_t queue, dispatch_block_t block);

#ifdef __cplusplus
}
#endif

#define dispatch_group_notify revenant_dispatch_group_notify

#endif
