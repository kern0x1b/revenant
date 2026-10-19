#import <UIKit/UIKit.h>

@implementation UIView (CharonBaselineLayout)

- (UIView *)viewForFirstBaselineLayout
{
    return [self viewForLastBaselineLayout];
}

- (UIView *)viewForLastBaselineLayout
{
    return [self viewForBaselineLayout];
}

@end
