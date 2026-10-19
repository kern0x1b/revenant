#ifndef REVENANT_DISPATCH_SOURCE_SET_EVENT_HANDLER_H
#define REVENANT_DISPATCH_SOURCE_SET_EVENT_HANDLER_H

#include <dispatch/dispatch.h>

#ifdef __cplusplus
extern "C" {
#endif

void revenant_dispatch_source_set_event_handler(dispatch_source_t source, dispatch_block_t handler);

#ifdef __cplusplus
}
#endif

#define dispatch_source_set_event_handler revenant_dispatch_source_set_event_handler

#endif
