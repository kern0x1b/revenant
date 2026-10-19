#import "CharonMetal.h"

// -commandBufferWithDescriptor: is the 14.0 factory: the descriptor names the two settings a buffer is
// made with, retainedReferences and errorOptions, and the buffer answers them as the descriptor gave
// them. A nil descriptor is refused with a log and a nil answer, because the factory has nothing to make
// the buffer from, and an API must not crash its caller.
@implementation CharonMetalQueue (Descriptor14)

- (id<MTLCommandBuffer>)commandBufferWithDescriptor:(MTLCommandBufferDescriptor *)descriptor
{
    if (!descriptor) {
        NSLog(@"Metal: commandBufferWithDescriptor: was given no descriptor, and no command buffer is made without one");
        return nil;
    }
    return [self charonCommandBufferRetainingReferences:descriptor.retainedReferences errorOptions:descriptor.errorOptions];
}

@end
