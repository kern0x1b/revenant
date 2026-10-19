#ifndef REVENANT_DISPATCH_QUEUE_CREATE_H
#define REVENANT_DISPATCH_QUEUE_CREATE_H

#include <dispatch/dispatch.h>

#ifdef __cplusplus
extern "C" {
#endif

dispatch_queue_t revenant_dispatch_queue_create(const char *label, dispatch_queue_attr_t attr);

#ifdef __cplusplus
}
#endif

#define dispatch_queue_create revenant_dispatch_queue_create

#endif
