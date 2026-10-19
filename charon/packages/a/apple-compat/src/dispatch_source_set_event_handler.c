#include "dispatch_block.h"
#include "dispatch_queue_width.h"
#include "dispatch_source_state.h"

/* What a source's activation record is written with, so this object calls the Objective-C runtime; the
   runtime is not part of libSystem, and the image that pulls this shim in links it. */
__asm__(".linker_option \"-lobjc\"");

/* A source whose event handler is a barrier block runs the handler as a barrier on its target queue from iOS 10
   (libdispatch-703 marks the source DQF_BARRIER_BIT); the release's runs it beside the queue's other blocks. So the release
   is given a handler that holds the source and submits the block as a barrier to the queue the handler runs on, which
   dispatch_get_current_queue answers there (libdispatch-228's _dispatch_source_invoke calls the handler only on the
   source's target queue, and no other call names that queue); the source goes on once the block has run. It delivers
   nothing while it is held, so dispatch_source_get_data in the block answers the event it was called for, and events that
   come meanwhile are merged into the next one, as they are while a handler runs.

   It answers as Darwin does on a concurrent target queue, for a handler set before the source's first resume. Two of
   the three configurations it used to differ in are decided here, and both are measured against Darwin's own calls on the
   host (tests/compat_test.py, DISPATCH_BARRIERS):
   - a serial target queue: on a serial queue every block is alone, so a barrier means nothing there and libdispatch-703
     runs the handler in its place in the queue - the event, then the blocks A and B queued since, "H A B". The barrier
     submission this shim made instead put the handler after them, "A B H". So the width of the queue the handler runs
     on is asked here, and on a serial one the handler is called in its place, which is what the release's own handler
     does. The width is the queue's own specific, written by dispatch_queue_create, so it is the width of the queue the
     source runs on now and not of the one it was made with: a later dispatch_set_target_queue needs no record to be
     corrected;
   - a handler set after the source's first resume: libdispatch-703 reads the barrier bit once, in
     _dispatch_source_finalize_activation, and _dispatch_source_set_handler never sets it again, so such a handler runs
     beside the queue's blocks. dispatch_resume records the activation, so such a handler is handed to the release as it
     is and runs as an ordinary block, which is Darwin's answer and the weaker of the two guarantees.
   What is left, and is not decided here: the source's cancellation and registration handlers, which on iOS 10 and later
   run alone as well because the barrier bit belongs to the source. They are called by the release from inside
   dispatch_source_cancel and dispatch_resume respectively, that is, from a block already running on the target queue, and
   a barrier submitted from such a block cannot start until that block returns: measured on the host, a barrier_async made
   from inside a block of a concurrent queue runs only after the block that made it returns, so a handler that submitted
   one and waited for it would wait for itself. Giving the two the same answer needs the calls that reach them to be
   renamed too (dispatch_source_cancel, to take the cancellation handler off before cancelling and run it as a barrier
   afterwards; dispatch_resume, which this file already renames, to run the registration handler inside a barrier of its
   own), and the handler each one runs has to be kept where those two can reach it. coordination/crutches.md, "apple-compat:
   a barrier source handler below iOS 10 differs from Darwin's in three configurations". */
__attribute__((visibility("hidden")))
void charon_dispatch_source_set_event_handler(dispatch_source_t source, dispatch_block_t handler)
{
    if (!handler || !charon_block_unseen_barrier(handler) || charon_source_activated(source)) {
        dispatch_source_set_event_handler(source, handler);
        return;
    }
    dispatch_source_set_event_handler(source, ^{
        /* dispatch_get_current_queue is deprecated since iOS 6 in the SDK and exported by every libdispatch of the
           releases these shims run on (libdispatch-228 has it); it is the documented call that names the queue a block runs on. */
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        dispatch_queue_t target = dispatch_get_current_queue();
#pragma clang diagnostic pop
        if (charon_queue_width_here() == CHARON_WIDTH_SERIAL) {
            /* Every block of a serial queue is alone, so the handler runs in its place and the source is never held:
               the release's own handler would do exactly this, and there is nothing to defer. */
            handler();
            return;
        }
        dispatch_suspend(source);
        dispatch_retain(source);
        dispatch_barrier_async(target, ^{
            handler();
            dispatch_resume(source);
            dispatch_release(source);
        });
    });
}
