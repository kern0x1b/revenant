#import "CharonMetal.h"


@interface CharonMetalSharedEvent (Wait)
@end

@implementation CharonMetalSharedEvent (Wait)

- (BOOL)waitUntilSignaledValue:(uint64_t)value timeoutMS:(uint64_t)milliseconds
{
    return [self charonWaitForValue:value timeout:(double)milliseconds / 1000.0];
}

@end
