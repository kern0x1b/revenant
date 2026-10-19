#import "CharonMetal.h"

// The 13.0 resource-state encoder records which pages of a sparse texture are mapped. A sparse texture
// is backed by pages that the memory system maps in and out, and the SGX 543 of the iPhone 4S has no
// mapping of that kind, so no sparse texture exists on the device and there is no mapping to record.
// The factory answers nil, the answer a device without the part gives: nothing is encoded and nothing is
// logged to the caller's work. facts/Metal/CommandBuffer.md marks which part of this answer is measured
// and which is reasoned.
@implementation CharonMetalCommandBuffer (ResourceState13)

- (id<MTLResourceStateCommandEncoder>)resourceStateCommandEncoder
{
    NSLog(@"Metal: the resource-state encoder needs sparse texture mapping, which this device does not have: none is made");
    return nil;
}

@end
