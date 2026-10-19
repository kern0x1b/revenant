#import "CharonMetal.h"

@implementation CharonMetalCommandBuffer (Dispatch12)

- (id<MTLComputeCommandEncoder>)computeCommandEncoderWithDispatchType:(MTLDispatchType)dispatchType
{
    return [self computeCommandEncoder];
}

@end
