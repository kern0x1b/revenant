#import "CharonMetal.h"

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@interface CharonMetalHeap (AllocatedSize)
@end

@implementation CharonMetalHeap (AllocatedSize)

- (NSUInteger)currentAllocatedSize
{
    return [self charonAllocated];
}

@end

@implementation CharonMetalEncoder (Heap)

- (void)useHeap:(id<MTLHeap>)heap
{
    [self charonUseHeaps:&heap count:1];
}

- (void)useHeaps:(const id<MTLHeap> __nonnull[])heaps count:(NSUInteger)count
{
    [self charonUseHeaps:heaps count:count];
}

@end
