#import "CharonMetal.h"

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
