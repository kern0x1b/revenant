#import "RevenantMetal.h"

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@interface RevenantMetalHeap (AllocatedSize)
@end

@implementation RevenantMetalHeap (AllocatedSize)

- (NSUInteger)currentAllocatedSize
{
    return [self revenantAllocated];
}

@end

@implementation RevenantMetalEncoder (Heap)

- (void)useHeap:(id<MTLHeap>)heap
{
    [self revenantUseHeaps:&heap count:1];
}

- (void)useHeaps:(const id<MTLHeap> __nonnull[])heaps count:(NSUInteger)count
{
    [self revenantUseHeaps:heaps count:count];
}

@end
