#import <UIKit/UIKit.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

const CGFloat UIFontWidthCompressed = -0.3f;

@implementation UIFont (CharonWidths)

+ (UIFont *)systemFontOfSize:(CGFloat)fontSize weight:(UIFontWeight)weight width:(CGFloat)width
{
    return [UIFont systemFontOfSize:fontSize weight:weight];
}

@end
