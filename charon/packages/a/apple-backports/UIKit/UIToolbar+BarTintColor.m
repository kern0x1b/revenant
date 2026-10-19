#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static char charon_bar_tint_key;

@implementation UIToolbar (CharonBarTintColor)

- (UIColor *)barTintColor
{
    return objc_getAssociatedObject(self, &charon_bar_tint_key);
}

- (void)setBarTintColor:(UIColor *)barTintColor
{
    objc_setAssociatedObject(self, &charon_bar_tint_key, barTintColor, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    self.tintColor = barTintColor;
}

@end
