#import <Foundation/Foundation.h>
#include <Block.h>

// iOS 5.0's block form of CFRunLoopObserverCreate: the observer keeps a copy of the block for its life and calls it
// with itself and the activity; its context holds the block, copied when the observer takes it and released with the
// observer. Held against the host's own function in tests/backports/host/uikit2 (group runloopobserver).

static const void *charon_retain_block(const void *block)
{
    return Block_copy(block);
}

static void charon_release_block(const void *block)
{
    Block_release(block);
}

static void charon_call_block(CFRunLoopObserverRef observer, CFRunLoopActivity activity, void *info)
{
    ((__bridge void (^)(CFRunLoopObserverRef, CFRunLoopActivity))info)(observer, activity);
}

CFRunLoopObserverRef CFRunLoopObserverCreateWithHandler(CFAllocatorRef allocator, CFOptionFlags activities, Boolean repeats, CFIndex order,
                                                        void (^block)(CFRunLoopObserverRef observer, CFRunLoopActivity activity))
{
    CFRunLoopObserverContext context = {0, (__bridge void *)block, charon_retain_block, charon_release_block, NULL};
    return CFRunLoopObserverCreate(allocator, activities, repeats, order, charon_call_block, &context);
}
