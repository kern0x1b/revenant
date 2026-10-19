#import "CharonMetal.h"


// A fence on this device is a signal value the CPU holds, and the work a fence stands for was
// already issued as it was encoded: the port has no queue of commands in flight, because a command is
// a call into OpenGL ES 2.0 that has already been made. So -updateFence: records how many commands
// this encoder has encoded, which is how far the fence has been brought, and -waitForFence: waits
// for the value the fence carries.

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
