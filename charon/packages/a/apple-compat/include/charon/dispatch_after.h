#ifndef CHARON_DISPATCH_AFTER_H
#define CHARON_DISPATCH_AFTER_H

#include <dispatch/dispatch.h>

#ifdef __cplusplus
extern "C" {
#endif

void charon_dispatch_after(dispatch_time_t when, dispatch_queue_t queue, dispatch_block_t block);

#ifdef __cplusplus
}
#endif

#define dispatch_after charon_dispatch_after

#endif
