#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static char charon_tolerance_key;

CFTimeInterval CFRunLoopTimerGetTolerance(CFRunLoopTimerRef timer)
{
    NSNumber *tolerance = objc_getAssociatedObject((__bridge id)timer, &charon_tolerance_key);
    return tolerance.doubleValue;
}

void CFRunLoopTimerSetTolerance(CFRunLoopTimerRef timer, CFTimeInterval tolerance)
{
    if (CFRunLoopTimerDoesRepeat(timer)) {
        CFTimeInterval half = CFRunLoopTimerGetInterval(timer) / 2;
        if (!(tolerance <= half))
            tolerance = half;
    } else if (tolerance < 0) {
        tolerance = 0;
    }
    objc_setAssociatedObject((__bridge id)timer, &charon_tolerance_key, @(tolerance), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@implementation NSTimer (CharonTolerance)

- (NSTimeInterval)tolerance
{
    return CFRunLoopTimerGetTolerance((__bridge CFRunLoopTimerRef)self);
}

- (void)setTolerance:(NSTimeInterval)tolerance
{
    CFRunLoopTimerSetTolerance((__bridge CFRunLoopTimerRef)self, tolerance);
}

@end
