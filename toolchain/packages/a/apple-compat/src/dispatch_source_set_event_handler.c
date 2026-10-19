#include "dispatch_block.h"
#include "dispatch_queue_width.h"
#include "dispatch_source_state.h"

__asm__(".linker_option \"-lobjc\"");

__attribute__((visibility("hidden")))
void charon_dispatch_source_set_event_handler(dispatch_source_t source, dispatch_block_t handler)
{
    if (!handler || !charon_block_unseen_barrier(handler) || charon_source_activated(source)) {
        dispatch_source_set_event_handler(source, handler);
        return;
    }
    dispatch_source_set_event_handler(source, ^{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        dispatch_queue_t target = dispatch_get_current_queue();
#pragma clang diagnostic pop
        if (charon_queue_width_here() == CHARON_WIDTH_SERIAL) {
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
