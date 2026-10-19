#import "UIKit/UIViewControllerTransitioning.h"

static NSTimeInterval gLastDuration = 0;

void RevenantAnimate(NSTimeInterval duration, void (^animations)(void), void (^completion)(BOOL))
{
    gLastDuration = duration;
    if (animations)
        animations();
    if (completion)
        completion(YES);
}

NSTimeInterval RevenantLastAnimationDuration(void)
{
    return gLastDuration;
}
