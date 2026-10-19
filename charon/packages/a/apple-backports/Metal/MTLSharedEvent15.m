#import "CharonMetal.h"


// The timed wait of a shared event: a wait on the condition the event's state broadcasts when its
// value is set, with the timeout the caller gives, and an answer of whether the value was reached
// inside it. A value another thread signals later does end it.

@interface CharonMetalSharedEvent (Wait)
@end

@implementation CharonMetalSharedEvent (Wait)

- (BOOL)waitUntilSignaledValue:(uint64_t)value timeoutMS:(uint64_t)milliseconds
{
    return [self charonWaitForValue:value timeout:(double)milliseconds / 1000.0];
}

@end
