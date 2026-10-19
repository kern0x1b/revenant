#import "CharonMetal.h"

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

// The 11.0 members of a heap and of the encoders that are told what a heap holds.
//
// `currentAllocatedSize` is the sum of what the heap has handed out and `usedSize` is the offset the
// next allocation starts at, so the two differ by the padding each allocation was aligned up to,
// which is what Apple's headers say they are: the bytes a heap has allocated, and the bytes its
// allocations reach.
//
// The two compute encoder methods of the same release name heaps to a compute encoder, and there is
// one: -[MTLCommandBuffer computeCommandEncoder] answers a real encoder, which records them and checks
// a bound resource against them, as the render encoder does. They are implemented, and
// registry/Metal/ios8compute.json says what they answer.

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
