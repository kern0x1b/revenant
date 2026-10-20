#import <Foundation/Foundation.h>
#include <Block.h>

static const void *revenant_retain_block(const void *block)
{
    return Block_copy(block);
}

static void revenant_release_block(const void *block)
{
    Block_release(block);
}

static void revenant_call_block(CFRunLoopObserverRef observer, CFRunLoopActivity activity, void *info)
{
    ((__bridge void (^)(CFRunLoopObserverRef, CFRunLoopActivity))info)(observer, activity);
}

CFRunLoopObserverRef CFRunLoopObserverCreateWithHandler(CFAllocatorRef allocator, CFOptionFlags activities, Boolean repeats, CFIndex order,
                                                        void (^block)(CFRunLoopObserverRef observer, CFRunLoopActivity activity))
{
    CFRunLoopObserverContext context = {0, (__bridge void *)block, revenant_retain_block, revenant_release_block, NULL};
    return CFRunLoopObserverCreate(allocator, activities, repeats, order, revenant_call_block, &context);
}
