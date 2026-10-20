#import "RevenantMetal.h"

@implementation RevenantMetalCommandBuffer (Dispatch12)

- (id<MTLComputeCommandEncoder>)computeCommandEncoderWithDispatchType:(MTLDispatchType)dispatchType
{
    return [self computeCommandEncoder];
}

@end
