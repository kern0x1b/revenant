#import "CharonMetal.h"

@implementation CharonMetalCommandBuffer (Errors14)

- (MTLCommandBufferErrorOption)errorOptions
{
    return [self charonErrorOptions];
}

- (id<MTLLogContainer>)logs
{
    return (id<MTLLogContainer>)[[CharonMetalLogContainer alloc] init];
}

@end

@implementation CharonMetalCommandBuffer (Blit14)

- (id<MTLBlitCommandEncoder>)blitCommandEncoderWithDescriptor:(MTLBlitPassDescriptor *)blitPassDescriptor
{
    if (!blitPassDescriptor) {
        NSLog(@"Metal: blitCommandEncoderWithDescriptor: was given no descriptor, and no blit encoder is made without one");
        return nil;
    }
    return [self blitCommandEncoder];
}

@end

@implementation CharonMetalCommandBuffer (Compute14)

- (id<MTLComputeCommandEncoder>)computeCommandEncoderWithDescriptor:(MTLComputePassDescriptor *)computePassDescriptor
{
    if (!computePassDescriptor) {
        NSLog(@"Metal: computeCommandEncoderWithDescriptor: was given no descriptor, and no compute encoder is made without one");
        return nil;
    }
    return [self computeCommandEncoderWithDispatchType:computePassDescriptor.dispatchType];
}

@end

@implementation CharonMetalCommandBuffer (AccelerationStructure14)

- (id<MTLAccelerationStructureCommandEncoder>)accelerationStructureCommandEncoder
{
    NSLog(@"Metal: acceleration-structure encoders need ray-tracing hardware, which this device does not have: none is made");
    return nil;
}

@end

@implementation CharonMetalCommandBuffer (ResourceState14)

- (id<MTLResourceStateCommandEncoder>)resourceStateCommandEncoderWithDescriptor:(MTLResourceStatePassDescriptor *)descriptor
{
    NSLog(@"Metal: the resource-state encoder needs sparse texture mapping, which this device does not have: none is made");
    return nil;
}

@end
