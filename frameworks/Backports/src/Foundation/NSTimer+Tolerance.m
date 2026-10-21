#import <Foundation/Foundation.h>

@implementation NSTimer (RevenantTolerance)

- (NSTimeInterval)tolerance
{
    return CFRunLoopTimerGetTolerance((__bridge CFRunLoopTimerRef)self);
}

- (void)setTolerance:(NSTimeInterval)tolerance
{
    CFRunLoopTimerSetTolerance((__bridge CFRunLoopTimerRef)self, tolerance);
}

@end
