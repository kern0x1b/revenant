#import <UIKit/UIKit.h>

@implementation UIFont (RevenantMonospacedDigit)

+ (UIFont *)monospacedDigitSystemFontOfSize:(CGFloat)fontSize weight:(UIFontWeight)weight
{
    return [UIFont systemFontOfSize:fontSize weight:weight];
}

@end
