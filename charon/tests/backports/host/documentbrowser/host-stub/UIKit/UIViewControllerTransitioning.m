#import "UIKit/UIViewControllerTransitioning.h"

// The stand-in for UIView's animation, so a transition can be run through on the host: the block
// runs, the completion runs, and the duration asked for is the one remembered, so a check can say
// how long a transition claims to take without a run loop.
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
