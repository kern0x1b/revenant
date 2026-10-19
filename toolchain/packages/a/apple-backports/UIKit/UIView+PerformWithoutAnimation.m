#import <UIKit/UIKit.h>

@implementation UIView (CharonPerformWithoutAnimation)

+ (void)performWithoutAnimation:(void (^)(void))actionsWithoutAnimation
{
    BOOL enabled = [UIView areAnimationsEnabled];
    [UIView setAnimationsEnabled:NO];
    actionsWithoutAnimation();
    [UIView setAnimationsEnabled:enabled];
}

@end
