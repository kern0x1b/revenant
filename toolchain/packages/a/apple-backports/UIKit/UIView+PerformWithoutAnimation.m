#import <UIKit/UIKit.h>

@implementation UIView (RevenantPerformWithoutAnimation)

+ (void)performWithoutAnimation:(void (^)(void))actionsWithoutAnimation
{
    BOOL enabled = [UIView areAnimationsEnabled];
    [UIView setAnimationsEnabled:NO];
    actionsWithoutAnimation();
    [UIView setAnimationsEnabled:enabled];
}

@end
