#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const char revenant_tint_key;

static UIImage *revenant_segment_fill(UIColor *color)
{
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(9, 9), NO, 0);
    [color setFill];
    [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, 9, 9) cornerRadius:4.5] fill];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [image resizableImageWithCapInsets:UIEdgeInsetsMake(4, 4, 4, 4)];
}

@implementation UISegmentedControl (RevenantSelectedTint13)

- (UIColor *)selectedSegmentTintColor
{
    return objc_getAssociatedObject(self, &revenant_tint_key);
}

- (void)setSelectedSegmentTintColor:(UIColor *)selectedSegmentTintColor
{
    objc_setAssociatedObject(self, &revenant_tint_key, selectedSegmentTintColor, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (selectedSegmentTintColor) {
        [self setBackgroundImage:revenant_segment_fill(selectedSegmentTintColor) forState:UIControlStateSelected barMetrics:UIBarMetricsDefault];
        [self setTitleTextAttributes:@{UITextAttributeTextColor: [UIColor whiteColor]} forState:UIControlStateSelected];
    } else {
        [self setBackgroundImage:nil forState:UIControlStateSelected barMetrics:UIBarMetricsDefault];
        [self setTitleTextAttributes:nil forState:UIControlStateSelected];
    }
}

@end
