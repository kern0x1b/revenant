#ifndef REVENANT_DISPATCH_GET_GLOBAL_QUEUE_H
#define REVENANT_DISPATCH_GET_GLOBAL_QUEUE_H

#include <dispatch/dispatch.h>

#ifdef __cplusplus
extern "C" {
#endif

dispatch_queue_t revenant_dispatch_get_global_queue(long identifier, unsigned long flags);

#ifdef __cplusplus
}
#endif

#define dispatch_get_global_queue revenant_dispatch_get_global_queue

#endif
