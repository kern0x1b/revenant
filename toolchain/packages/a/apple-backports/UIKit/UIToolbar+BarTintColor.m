#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static char revenant_bar_tint_key;

@implementation UIToolbar (RevenantBarTintColor)

- (UIColor *)barTintColor
{
    return objc_getAssociatedObject(self, &revenant_bar_tint_key);
}

- (void)setBarTintColor:(UIColor *)barTintColor
{
    objc_setAssociatedObject(self, &revenant_bar_tint_key, barTintColor, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    self.tintColor = barTintColor;
}

@end
