#ifndef CHARON_DISPATCH_GET_GLOBAL_QUEUE_H
#define CHARON_DISPATCH_GET_GLOBAL_QUEUE_H

#include <dispatch/dispatch.h>

#ifdef __cplusplus
extern "C" {
#endif

dispatch_queue_t charon_dispatch_get_global_queue(long identifier, unsigned long flags);

#ifdef __cplusplus
}
#endif

#define dispatch_get_global_queue charon_dispatch_get_global_queue

#endif
