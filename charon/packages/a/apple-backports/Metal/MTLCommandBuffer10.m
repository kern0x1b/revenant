#import "CharonMetal.h"

// The 10.3 timing properties of a command buffer. This port has one processor, so the GPU and the
// kernel are the same clock and the same span: the span from the first command the buffer encoded to
// the end of its commit. Each property answers 0 until the buffer has completed, as Metal's do.
@implementation CharonMetalCommandBuffer (Timing10)

- (CFTimeInterval)GPUStartTime
{
    return [self charonStartTime];
}

- (CFTimeInterval)GPUEndTime
{
    return [self charonEndTime];
}

- (CFTimeInterval)kernelStartTime
{
    return [self charonStartTime];
}

- (CFTimeInterval)kernelEndTime
{
    return [self charonEndTime];
}

@end
