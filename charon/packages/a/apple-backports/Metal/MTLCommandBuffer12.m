#import "CharonMetal.h"

// The 12.0 compute encoder with a dispatch type. A serial encoder runs its dispatches in the order they
// were encoded, and a concurrent one may run them in any order its caller is prepared for; the port's
// compute encoder runs each dispatch to completion before the next call returns, so every dispatch runs
// in the order it was encoded, which is a legal schedule for either type. The type is accepted and the
// encoder is the one -computeCommandEncoder vends: the only difference between the two types is an order
// the port never reorders.
@implementation CharonMetalCommandBuffer (Dispatch12)

- (id<MTLComputeCommandEncoder>)computeCommandEncoderWithDispatchType:(MTLDispatchType)dispatchType
{
    return [self computeCommandEncoder];
}

@end
