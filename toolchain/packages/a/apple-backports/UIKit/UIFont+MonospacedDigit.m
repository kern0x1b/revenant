#import <UIKit/UIKit.h>

@implementation UIFont (CharonMonospacedDigit)

+ (UIFont *)monospacedDigitSystemFontOfSize:(CGFloat)fontSize weight:(UIFontWeight)weight
{
    return [UIFont systemFontOfSize:fontSize weight:weight];
}

@end
