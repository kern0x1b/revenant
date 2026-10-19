#import "RevenantMetal.h"


@implementation RevenantMetalBlitEncoder (Fence)

- (void)updateFence:(id<MTLFence>)fence
{
    if (![fence isKindOfClass:[RevenantMetalSharedEvent class]]) {
        NSLog(@"Metal: a fence of class %@ is not one of this port's events, so there is no value of it to capture",
              NSStringFromClass([fence class]));
        return;
    }
    ((RevenantMetalSharedEvent *)fence).signaledValue = [self revenantEncodedCount];
}

- (void)waitForFence:(id<MTLFence>)fence
{
    if (![fence isKindOfClass:[RevenantMetalSharedEvent class]]) {
        NSLog(@"Metal: a fence of class %@ is not one of this port's events, so there is no value of it to wait for",
              NSStringFromClass([fence class]));
        return;
    }
    RevenantMetalSharedEvent *event = (RevenantMetalSharedEvent *)fence;
    [event revenantWaitForValue:event.signaledValue];
}

@end
