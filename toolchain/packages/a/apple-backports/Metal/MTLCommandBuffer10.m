#import "RevenantMetal.h"

@implementation RevenantMetalCommandBuffer (Timing10)

- (CFTimeInterval)GPUStartTime
{
    return [self revenantStartTime];
}

- (CFTimeInterval)GPUEndTime
{
    return [self revenantEndTime];
}

- (CFTimeInterval)kernelStartTime
{
    return [self revenantStartTime];
}

- (CFTimeInterval)kernelEndTime
{
    return [self revenantEndTime];
}

@end
