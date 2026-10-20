#import "RevenantMetal.h"

@implementation RevenantMetalCommandBuffer (AccelerationStructure16)

- (id<MTLAccelerationStructureCommandEncoder>)accelerationStructureCommandEncoderWithDescriptor:(MTLAccelerationStructurePassDescriptor *)descriptor
{
    NSLog(@"Metal: acceleration-structure encoders need ray-tracing hardware, which this device does not have: none is made");
    return nil;
}

@end
