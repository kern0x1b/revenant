#include "../revenant_impl.h"
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static char revenant_tolerance_key;

CFTimeInterval BACKPORT_IMPL(CFRunLoopTimerGetTolerance)(CFRunLoopTimerRef timer)
{
    NSNumber *tolerance = objc_getAssociatedObject((__bridge id)timer, &revenant_tolerance_key);
    return tolerance.doubleValue;
}

void BACKPORT_IMPL(CFRunLoopTimerSetTolerance)(CFRunLoopTimerRef timer, CFTimeInterval tolerance)
{
    if (CFRunLoopTimerDoesRepeat(timer)) {
        CFTimeInterval half = CFRunLoopTimerGetInterval(timer) / 2;
        if (!(tolerance <= half))
            tolerance = half;
    } else if (tolerance < 0) {
        tolerance = 0;
    }
    objc_setAssociatedObject((__bridge id)timer, &revenant_tolerance_key, @(tolerance), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
