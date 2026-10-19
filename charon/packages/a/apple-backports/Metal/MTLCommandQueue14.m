#import "CharonMetal.h"

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
