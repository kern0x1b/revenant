#ifndef CHARON_DISPATCH_QUEUE_CREATE_H
#define CHARON_DISPATCH_QUEUE_CREATE_H

#include <dispatch/dispatch.h>

#ifdef __cplusplus
extern "C" {
#endif

dispatch_queue_t charon_dispatch_queue_create(const char *label, dispatch_queue_attr_t attr);

#ifdef __cplusplus
}
#endif

#define dispatch_queue_create charon_dispatch_queue_create

#endif
