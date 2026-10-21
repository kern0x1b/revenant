#import <UIKit/UIKit.h>

@implementation UIViewPropertyAnimator (RevenantGetter10)

- (BOOL)interruptible
{
    return [self isInterruptible];
}

- (BOOL)manualHitTestingEnabled
{
    return [self isManualHitTestingEnabled];
}

- (BOOL)userInteractionEnabled
{
    return [self isUserInteractionEnabled];
}

@end
