#import "RevenantMetal.h"

@implementation RevenantMetalQueue (Descriptor14)

- (id<MTLCommandBuffer>)commandBufferWithDescriptor:(MTLCommandBufferDescriptor *)descriptor
{
    if (!descriptor) {
        NSLog(@"Metal: commandBufferWithDescriptor: was given no descriptor, and no command buffer is made without one");
        return nil;
    }
    return [self revenantCommandBufferRetainingReferences:descriptor.retainedReferences errorOptions:descriptor.errorOptions];
}

@end
