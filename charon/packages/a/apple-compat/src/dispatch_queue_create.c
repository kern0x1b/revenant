#include "dispatch_queue_width.h"

/* Records how wide each queue this image makes is, so that a barrier source's event handler can
   answer as Darwin does on a serial target queue: there a barrier means nothing, every block is
   alone, and the release runs the handler in its place in the queue rather than after the blocks
   queued since (measured against Darwin's own calls on the host, tests/compat_test.py,
   DISPATCH_BARRIERS: Darwin's serial case answers "H A B" and the barrier answer "A B H").

   The width is one pointer comparison of the attribute against DISPATCH_QUEUE_SERIAL (NULL) and
   DISPATCH_QUEUE_CONCURRENT (the exported _dispatch_queue_attr_concurrent), so nothing is read out
   of a queue and no field of libdispatch's own is touched. A queue made with no attribute is serial
   and one made with DISPATCH_QUEUE_CONCURRENT is concurrent; an attribute made from one of them is
   this release's own structure and no call names its width, so it is recorded as undecided and
   every shim that asks keeps the answer it had.

   This is the "header route" the crutches entry names, and the part of it that goes stale on a
   later dispatch_set_target_queue is gone: what a source's event handler asks is the width of the
   queue it is running on, which is the source's target whatever that target has since become. */

__attribute__((visibility("hidden")))
dispatch_queue_t charon_dispatch_queue_create(const char *label, dispatch_queue_attr_t attr)
{
    dispatch_queue_t queue = dispatch_queue_create(label, attr);
    charon_queue_record_width(queue, charon_width_of_attribute(attr));
    return queue;
}
