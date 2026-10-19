#import "CharonMetal.h"


@implementation CharonMetalBlitEncoder (Fence)

- (void)updateFence:(id<MTLFence>)fence
{
    if (![fence isKindOfClass:[CharonMetalSharedEvent class]]) {
        NSLog(@"Metal: a fence of class %@ is not one of this port's events, so there is no value of it to capture",
              NSStringFromClass([fence class]));
        return;
    }
    ((CharonMetalSharedEvent *)fence).signaledValue = [self charonEncodedCount];
}

- (void)waitForFence:(id<MTLFence>)fence
{
    if (![fence isKindOfClass:[CharonMetalSharedEvent class]]) {
        NSLog(@"Metal: a fence of class %@ is not one of this port's events, so there is no value of it to wait for",
              NSStringFromClass([fence class]));
        return;
    }
    CharonMetalSharedEvent *event = (CharonMetalSharedEvent *)fence;
    [event charonWaitForValue:event.signaledValue];
}

@end
