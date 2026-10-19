#include "dispatch_queue_width.h"

__attribute__((visibility("hidden")))
dispatch_queue_t charon_dispatch_queue_create(const char *label, dispatch_queue_attr_t attr)
{
    dispatch_queue_t queue = dispatch_queue_create(label, attr);
    charon_queue_record_width(queue, charon_width_of_attribute(attr));
    return queue;
}
