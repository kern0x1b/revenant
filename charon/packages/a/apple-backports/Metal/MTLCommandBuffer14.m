#import "CharonMetal.h"

// The 14.0 members of a command buffer.
//
// The error options its descriptor set are kept and answered, not acted on: the port reports no error
// that an option would select, facts/Metal/CommandBuffer.md.
//
// The log container holds the function logs a command buffer collected from its shaders. The port's
// shaders are translated kernels that write no function log, and no code of the port creates one, so
// the container is empty for every buffer and enumerates nothing. It is still a container of the
// protocol, so a caller can enumerate it the way it enumerates Metal's. The class is CharonMetalLogContainer
// in MTLReflection14.m, which the port already had; this file only hands one out.
//
// The blit and compute encoders that take a pass descriptor are the encoders of their kind, with the
// descriptor's counter attachments left out because this device has no counter sample buffer to attach
// (the pass-descriptor comment above the factories says why).
//
// The acceleration-structure and resource-state encoders are the hardware answer, as in MTLCommandBuffer13.m.

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

// The 14.0 pass-descriptor factories. A pass descriptor names counter sample buffers for its pass, and
// a counter sample buffer is made by the device; this device makes none (its counter-sample member is
// still owed, registry/Metal/absent_Metal.json), so no attachment of a descriptor can hold one, and a pass
// is encoded as the plain encoder of its kind. The attachments are not read: there is nothing in them.
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
