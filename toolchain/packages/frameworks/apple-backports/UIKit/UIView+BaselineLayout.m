#import <UIKit/UIKit.h>

@implementation UIView (RevenantBaselineLayout)

- (UIView *)viewForFirstBaselineLayout
{
    return [self viewForLastBaselineLayout];
}

- (UIView *)viewForLastBaselineLayout
{
    return [self viewForBaselineLayout];
}

@end
