#import "CharonMetal.h"

// The 16.0 acceleration-structure encoder that takes a descriptor. Acceleration structures are the
// ray-tracing hardware's data, and the SGX 543 of the iPhone 4S has no ray-tracing unit, so no encoder
// for them is made on this device. The answer is nil, as it is for the factory without a descriptor in
// MTLCommandBuffer14.m. facts/Metal/CommandBuffer.md records which part of that is measured and which is reasoned.
@implementation CharonMetalCommandBuffer (AccelerationStructure16)

- (id<MTLAccelerationStructureCommandEncoder>)accelerationStructureCommandEncoderWithDescriptor:(MTLAccelerationStructurePassDescriptor *)descriptor
{
    NSLog(@"Metal: acceleration-structure encoders need ray-tracing hardware, which this device does not have: none is made");
    return nil;
}

@end
