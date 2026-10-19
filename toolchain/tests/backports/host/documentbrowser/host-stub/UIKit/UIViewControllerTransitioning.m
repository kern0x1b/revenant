#import "UIKit/UIViewControllerTransitioning.h"

static NSTimeInterval gLastDuration = 0;

void CharonAnimate(NSTimeInterval duration, void (^animations)(void), void (^completion)(BOOL))
{
    gLastDuration = duration;
    if (animations)
        animations();
    if (completion)
        completion(YES);
}

NSTimeInterval CharonLastAnimationDuration(void)
{
    return gLastDuration;
}
