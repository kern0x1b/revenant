#import "RevenantMetal.h"


@interface RevenantMetalSharedEvent (Wait)
@end

@implementation RevenantMetalSharedEvent (Wait)

- (BOOL)waitUntilSignaledValue:(uint64_t)value timeoutMS:(uint64_t)milliseconds
{
    return [self revenantWaitForValue:value timeout:(double)milliseconds / 1000.0];
}

@end
